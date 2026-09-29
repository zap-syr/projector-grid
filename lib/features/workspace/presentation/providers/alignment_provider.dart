import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/panasonic_protocol_service.dart';
import '../../domain/alignment.dart';
import '../../domain/card_layout.dart';
import '../../domain/log_event.dart';
import '../../domain/projector_node.dart';
import '../../domain/test_patterns.dart';
import 'app_settings_provider.dart';
import 'event_log_provider.dart';
import 'protocol_service_provider.dart';
import 'selection_provider.dart';
import 'workspace_provider.dart';

part 'alignment_provider.g.dart';

class AlignmentState {
  final bool active;

  /// Entry (reading every projector's state) or exit (restoring it) is in
  /// progress.
  final bool busy;

  /// Projectors the mode manages: those in scope that answered on entry.
  final Set<String> scope;

  final String? focusedId;
  final AlignmentPreset preset;
  final String focusedPattern;

  /// Null = same as focused.
  final String? othersPattern;
  final bool showNeighbours;
  final bool includeDiagonals;
  final bool showAll;
  final Set<String> manualNeighbours;
  final Map<String, AlignmentRole> roles;

  const AlignmentState({
    this.active = false,
    this.busy = false,
    this.scope = const {},
    this.focusedId,
    required this.preset,
    required this.focusedPattern,
    required this.othersPattern,
    required this.showNeighbours,
    required this.includeDiagonals,
    this.showAll = false,
    this.manualNeighbours = const {},
    this.roles = const {},
  });

  AlignmentState copyWith({
    bool? active,
    bool? busy,
    Set<String>? scope,
    String? focusedId,
    AlignmentPreset? preset,
    String? focusedPattern,
    String? othersPattern,
    bool clearOthersPattern = false,
    bool? showNeighbours,
    bool? includeDiagonals,
    bool? showAll,
    Set<String>? manualNeighbours,
    Map<String, AlignmentRole>? roles,
  }) => AlignmentState(
    active: active ?? this.active,
    busy: busy ?? this.busy,
    scope: scope ?? this.scope,
    focusedId: focusedId ?? this.focusedId,
    preset: preset ?? this.preset,
    focusedPattern: focusedPattern ?? this.focusedPattern,
    othersPattern: clearOthersPattern
        ? null
        : (othersPattern ?? this.othersPattern),
    showNeighbours: showNeighbours ?? this.showNeighbours,
    includeDiagonals: includeDiagonals ?? this.includeDiagonals,
    showAll: showAll ?? this.showAll,
    manualNeighbours: manualNeighbours ?? this.manualNeighbours,
    roles: roles ?? this.roles,
  );
}

/// What entry captured for one projector, so exit can put it back. The
/// connection details are copied too: a card deleted (or a project closed)
/// mid-mode must still be restorable.
class _Managed {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String login;
  final String password;
  final bool wasOpen;
  final String? pattern;

  /// Non-zero fade times that were zeroed for the mode; null if untouched.
  final ShutterFade? fade;

  const _Managed({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.login,
    required this.password,
    required this.wasOpen,
    required this.pattern,
    required this.fade,
  });
}

/// Alignment mode (ROADMAP_PLAN.md §3.2): one focused projector open with
/// its pattern, neighbours or everyone optionally open with the Others
/// pattern, the rest of the scope closed. Holds no widget state so the web
/// API (§5) can drive the same methods.
@Riverpod(keepAlive: true)
class AlignmentNotifier extends _$AlignmentNotifier {
  // Entry reads 4 registers per projector; 8 projectors at a time keeps the
  // burst well inside the batch cap from the panasonic-ntcontrol skill.
  static const _captureConcurrency = 8;

  late PanasonicProtocolService _protocol;
  final Map<String, _Managed> _managed = {};

  /// What was last sent to each managed projector.
  final Map<String, ProjectorOutput> _applied = {};

  /// IPs whose fade restore belongs to the running session, or is in
  /// flight — the pending-restore sweep leaves them alone.
  final Set<String> _sessionIps = {};
  final Set<String> _restoringIps = {};

  /// Projectors whose command loop is running (see [_reconcile]), and the
  /// loops themselves so exit can wait for them.
  final Set<String> _syncing = {};
  final Map<String, Future<void>> _syncs = {};

  @override
  AlignmentState build() {
    _protocol = ref.read(protocolServiceProvider);
    ref.listen(workspaceProvider, (_, nodes) => _onNodesChanged(nodes));
    ref.listen(
      selectionProvider,
      (_, selected) => _keepFocusSelected(selected),
    );
    final settings = ref.read(appSettingsProvider);
    return AlignmentState(
      preset: settings.alignmentPreset,
      focusedPattern: settings.alignmentFocusedPattern,
      othersPattern: settings.alignmentOthersPattern,
      showNeighbours: settings.alignmentShowNeighbours,
      includeDiagonals: settings.alignmentDiagonals,
    );
  }

  // ── Enter / exit ─────────────────────────────────────────────────────────

  Future<void> toggle() => state.active ? exit() : enter();

  /// Scope is the selection when two or more cards are selected, otherwise
  /// every projector. The focused projector is the first selected one in
  /// layout order, or the first overall.
  Future<void> enter() async {
    if (state.active || state.busy) return;
    final nodes = ref.read(workspaceProvider);
    final selected = ref.read(selectionProvider);
    final scopeNodes = selected.length >= 2
        ? nodes.where((n) => selected.contains(n.id)).toList()
        : nodes;
    final reachable = scopeNodes.where(_isReachable).toList();
    if (reachable.isEmpty) {
      _log(LogSeverity.warning, 'Alignment mode: no online projectors');
      return;
    }

    state = state.copyWith(busy: true);
    final captured = await _captureAll(reachable);
    if (captured.isEmpty) {
      state = state.copyWith(busy: false);
      _log(LogSeverity.error, 'Alignment mode: no projector answered');
      return;
    }
    for (final m in captured) {
      _managed[m.id] = m;
      _applied[m.id] = (open: m.wasOpen, pattern: m.pattern);
      _sessionIps.add(m.ip);
    }
    await Future.wait(captured.where((m) => m.fade != null).map(_zeroFade));

    final order = layoutOrder(nodes.where((n) => _managed.containsKey(n.id)));
    final focusedId =
        order.where((n) => selected.contains(n.id)).firstOrNull?.id ??
        order.first.id;
    final scope = _managed.keys.toSet();
    state = state.copyWith(
      active: true,
      busy: false,
      scope: scope,
      focusedId: focusedId,
      showAll: false,
      manualNeighbours: const {},
    );
    ref.read(selectionProvider.notifier).selectOnly(focusedId);
    final skipped = scopeNodes.length - scope.length;
    _log(
      LogSeverity.info,
      'Alignment mode on — ${scope.length} projector(s)'
      '${skipped > 0 ? ', $skipped offline or not answering skipped' : ''}',
    );
    _updateRoles();
  }

  /// Puts every managed projector's shutter, pattern and shutter fade back
  /// to what entry captured.
  Future<void> exit() async {
    if (!state.active) return;
    state = state.copyWith(active: false, busy: true, roles: const {});
    await Future.wait(_syncs.values);
    _syncs.clear();
    final managed = _managed.values.toList();
    await Future.wait(managed.map(_restore));
    _managed.clear();
    _applied.clear();
    _sessionIps.clear();
    state = AlignmentState(
      preset: state.preset,
      focusedPattern: state.focusedPattern,
      othersPattern: state.othersPattern,
      showNeighbours: state.showNeighbours,
      includeDiagonals: state.includeDiagonals,
    );
    _log(LogSeverity.info, 'Alignment mode off — projectors restored');
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void focus(String id) {
    if (!state.active || !_managed.containsKey(id)) return;
    // Focus first: the selection guard (_keepFocusSelected) snaps any other
    // selection back to the focused projector.
    if (id != state.focusedId) {
      state = state.copyWith(focusedId: id);
      _updateRoles();
    }
    ref.read(selectionProvider.notifier).selectOnly(id);
  }

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    if (!state.active) return;
    final order = _order();
    if (order.isEmpty) return;
    final index = order.indexWhere((n) => n.id == state.focusedId);
    focus(order[(index + delta) % order.length].id);
  }

  List<ProjectorNode> _order() => layoutOrder(
    ref.read(workspaceProvider).where((n) => _managed.containsKey(n.id)),
  );

  // ── Toggles & patterns ───────────────────────────────────────────────────

  void toggleShowAll() {
    if (!state.active) return;
    state = state.copyWith(showAll: !state.showAll);
    _updateRoles();
  }

  void toggleNeighbours() {
    state = state.copyWith(showNeighbours: !state.showNeighbours);
    ref
        .read(appSettingsProvider.notifier)
        .setAlignmentShowNeighbours(state.showNeighbours);
    _updateRoles();
  }

  void toggleDiagonals() {
    state = state.copyWith(includeDiagonals: !state.includeDiagonals);
    ref
        .read(appSettingsProvider.notifier)
        .setAlignmentDiagonals(state.includeDiagonals);
    _updateRoles();
  }

  /// Ctrl+click: adds a card the geometry rule missed, or hides one it
  /// found. Kept until exit.
  void toggleManualNeighbour(String id) {
    if (!state.active || id == state.focusedId || !_managed.containsKey(id)) {
      return;
    }
    final next = Set<String>.of(state.manualNeighbours);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(manualNeighbours: next);
    _updateRoles();
  }

  /// Switches the task; its defaults replace the patterns, except Custom
  /// which keeps them.
  void setPreset(AlignmentPreset preset) {
    final focused = preset.defaultFocused ?? state.focusedPattern;
    final others = preset == AlignmentPreset.custom
        ? state.othersPattern
        : preset.defaultOthers;
    _setPatterns(preset, focused, others);
  }

  void setFocusedPattern(String code) =>
      _setPatterns(state.preset, code, state.othersPattern);

  /// [code] null = same as focused.
  void setOthersPattern(String? code) =>
      _setPatterns(state.preset, state.focusedPattern, code);

  void _setPatterns(AlignmentPreset preset, String focused, String? others) {
    state = state.copyWith(
      preset: preset,
      focusedPattern: focused,
      othersPattern: others,
      clearOthersPattern: others == null,
    );
    ref
        .read(appSettingsProvider.notifier)
        .setAlignmentPatterns(preset: preset, focused: focused, others: others);
    _reconcile();
  }

  // ── Roles & commands ─────────────────────────────────────────────────────

  void _onNodesChanged(List<ProjectorNode> nodes) {
    _restorePendingFades(nodes);
    if (!state.active) return;
    // A deleted focused card (or a closed project) moves the focus on, or
    // ends the mode when nothing managed is left.
    final present = nodes.where((n) => _managed.containsKey(n.id)).toList();
    if (present.isEmpty) {
      unawaited(exit());
      return;
    }
    if (!present.any((n) => n.id == state.focusedId)) {
      state = state.copyWith(focusedId: layoutOrder(present).first.id);
    }
    _updateRoles();
  }

  /// The control bar acts on the selection, so in the mode the focused
  /// projector stays the one selected card: a click on empty canvas,
  /// Ctrl+D, Ctrl+A or a marquee drag snaps back to it.
  void _keepFocusSelected(Set<String> selected) {
    final focusedId = state.focusedId;
    if (!state.active || focusedId == null) return;
    if (selected.length == 1 && selected.contains(focusedId)) return;
    ref.read(selectionProvider.notifier).selectOnly(focusedId);
  }

  void _updateRoles() {
    if (!state.active) return;
    final roles = alignmentRoles(
      nodes: ref.read(workspaceProvider),
      scope: state.scope,
      focusedId: state.focusedId!,
      showAll: state.showAll,
      showNeighbours: state.showNeighbours,
      includeDiagonals: state.includeDiagonals,
      manualNeighbours: state.manualNeighbours,
    );
    if (!_sameRoles(roles, state.roles)) {
      state = state.copyWith(roles: roles);
    }
    _reconcile();
  }

  static bool _sameRoles(
    Map<String, AlignmentRole> a,
    Map<String, AlignmentRole> b,
  ) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  /// Brings projectors in line with [AlignmentState.roles]. Each projector
  /// has its own loop, so one that stopped answering (a send can take ~9 s
  /// to time out) never holds up the others. A loop re-reads the target
  /// before every command: fast `<` / `>` presses only move the target, the
  /// loop sends at most the difference to wherever it ended up, and
  /// commands on one projector never interleave.
  void _reconcile() {
    for (final id in _managed.keys) {
      if (_syncing.add(id)) _syncs[id] = _syncLoop(id);
    }
  }

  Future<void> _syncLoop(String id) async {
    final m = _managed[id]!;
    // Every exit clears [_syncing] in the same synchronous step that decided
    // there's nothing more to send; any later change then starts a new loop.
    // Clearing it after an await instead would leave a gap where a change
    // finds the loop still marked running, is skipped, and never gets sent.
    void done() => _syncing.remove(id);
    while (true) {
      final role = state.active ? state.roles[id] : null;
      if (role == null) return done();
      final target = outputFor(
        role,
        focusedPattern: state.focusedPattern,
        othersPattern: state.othersPattern,
      );
      final commands = commandsFor(_applied[id]!, target);
      if (commands.isEmpty) return done();
      final cmd = commands.first;
      // A failure is logged by _send; stop rather than retry in a tight
      // loop — the next change to the mode tries again.
      if (!await _send(m, cmd)) return done();
      final current = _applied[id]!;
      _applied[id] = cmd.startsWith('OTS:')
          ? (open: current.open, pattern: cmd)
          : (open: cmd == 'OSH:0', pattern: current.pattern);
    }
  }

  Future<bool> _send(_Managed m, String cmd) async {
    final ok = await _protocol.sendCommand(
      m.ip,
      m.port,
      m.login,
      m.password,
      cmd,
    );
    if (ok) {
      ref.read(workspaceProvider.notifier).noteCommandSent(m.id, cmd);
    } else {
      _log(
        LogSeverity.error,
        'Failed: ${commandLabel(cmd)}',
        ip: m.ip,
        name: m.name,
      );
    }
    return ok;
  }

  // ── Capture / restore ────────────────────────────────────────────────────

  static bool _isReachable(ProjectorNode n) =>
      n.connectionStatus == ConnectionStatus.connected ||
      n.connectionStatus == ConnectionStatus.unprotected;

  Future<List<_Managed>> _captureAll(List<ProjectorNode> nodes) async {
    final results = <_Managed>[];
    for (var i = 0; i < nodes.length; i += _captureConcurrency) {
      final batch = nodes.skip(i).take(_captureConcurrency);
      final captured = await Future.wait(batch.map(_capture));
      results.addAll(captured.nonNulls);
    }
    return results;
  }

  /// Null when the shutter can't be read — without it the projector can't
  /// be restored, so it stays out of the mode.
  Future<_Managed?> _capture(ProjectorNode n) async {
    Future<String?> query(String cmd) =>
        _protocol.sendRawCommand(n.ipAddress, n.port, n.login, n.password, cmd);
    final shutter = await query('QSH');
    if (shutter != '0' && shutter != '1') return null;
    final pattern = parseTestPattern(await query('QTS'));
    final fadeIn = parseShutterFade(await query('QVX:SEFS1'));
    final fadeOut = parseShutterFade(await query('QVX:SEFS2'));
    final zeroed =
        fadeIn != null &&
        fadeOut != null &&
        !(isZeroFade(fadeIn) && isZeroFade(fadeOut));
    return _Managed(
      id: n.id,
      name: n.name,
      ip: n.ipAddress,
      port: n.port,
      login: n.login,
      password: n.password,
      wasOpen: shutter == '0',
      pattern: pattern,
      fade: zeroed ? (fadeIn: fadeIn, fadeOut: fadeOut) : null,
    );
  }

  /// Saved to app settings *before* the write, so a crash right after
  /// still knows what to put back.
  Future<void> _zeroFade(_Managed m) async {
    final fade = m.fade!;
    ref.read(appSettingsProvider.notifier).setPendingFadeRestore(m.ip, fade);
    final ok =
        await _send(m, 'VXX:SEFS1=0.0') && await _send(m, 'VXX:SEFS2=0.0');
    if (ok) {
      _log(
        LogSeverity.info,
        'Shutter fade ${fade.fadeIn}/${fade.fadeOut} s → 0 for alignment',
        ip: m.ip,
        name: m.name,
      );
    }
  }

  Future<void> _restore(_Managed m) async {
    final applied = _applied[m.id]!;
    final commands = commandsFor(applied, (
      open: m.wasOpen,
      pattern: m.pattern,
    ));
    for (final cmd in commands) {
      if (!await _send(m, cmd)) break;
    }
    final fade = m.fade;
    if (fade != null) await _writeFade(m, fade);
  }

  Future<bool> _writeFade(_Managed m, ShutterFade fade) async {
    final ok =
        await _send(m, 'VXX:SEFS1=${fade.fadeIn}') &&
        await _send(m, 'VXX:SEFS2=${fade.fadeOut}');
    if (ok) {
      ref.read(appSettingsProvider.notifier).setPendingFadeRestore(m.ip, null);
      _log(
        LogSeverity.info,
        'Shutter fade restored to ${fade.fadeIn}/${fade.fadeOut} s',
        ip: m.ip,
        name: m.name,
      );
    }
    return ok;
  }

  /// Writes back fades left zeroed by a session that never exited (quit or
  /// crash) once their projector is online.
  void _restorePendingFades(List<ProjectorNode> nodes) {
    final pending = ref.read(appSettingsProvider).pendingFadeRestores;
    if (pending.isEmpty) return;
    for (final n in nodes) {
      final fade = pending[n.ipAddress];
      if (fade == null ||
          !_isReachable(n) ||
          _sessionIps.contains(n.ipAddress) ||
          !_restoringIps.add(n.ipAddress)) {
        continue;
      }
      final m = _Managed(
        id: n.id,
        name: n.name,
        ip: n.ipAddress,
        port: n.port,
        login: n.login,
        password: n.password,
        wasOpen: n.shutterStatus == ShutterStatus.open,
        pattern: n.testPattern,
        fade: fade,
      );
      unawaited(
        _writeFade(m, fade).whenComplete(() => _restoringIps.remove(m.ip)),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _log(LogSeverity severity, String message, {String? ip, String? name}) {
    ref
        .read(eventLogProvider.notifier)
        .log(
          LogEvent(
            severity: severity,
            type: LogEventType.command,
            message: message,
            projectorIp: ip,
            projectorName: name,
          ),
        );
  }
}
