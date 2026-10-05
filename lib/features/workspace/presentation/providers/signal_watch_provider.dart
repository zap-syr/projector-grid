import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/panasonic_protocol_service.dart';
import '../../domain/alert_rule.dart';
import '../../domain/projector_node.dart';
import '../../domain/signal_watch.dart';
import '../../domain/telemetry_parsing.dart';
import 'app_settings_provider.dart';
import 'protocol_service_provider.dart';
import 'workspace_provider.dart';

part 'signal_watch_provider.g.dart';

/// Queries `QVX:NSGS1` on every powered-on projector every [period] while
/// the Signal lost rule is on, and keeps each projector's latest dropout.
/// The regular poll (30 s at best) misses dropouts between polls; a cable
/// pulled for ~1 s still leaves ~3.5 s without signal while the projector
/// re-locks, so 2 s catches every one (measured, ROADMAP §4 spike).
///
/// Sized for 150 projectors: each gets a fixed slot in the period, so the
/// queries go out evenly (one per ~13 ms) instead of in a burst; at most
/// [maxInFlight] are open at once; a projector whose query hasn't come back,
/// or that the app is already talking to ([WorkspaceNotifier.isNodeBusy]),
/// is skipped for that round. Time is counted in ticks of the scheduler's
/// own timer, so a busy event loop stretches the period rather than piling
/// queries up.
@Riverpod(keepAlive: true)
class SignalWatchNotifier extends _$SignalWatchNotifier {
  static const period = Duration(seconds: 2);
  static const tick = Duration(milliseconds: 50);
  static const maxInFlight = 16;
  static final int _periodTicks = period.inMilliseconds ~/ tick.inMilliseconds;

  late PanasonicProtocolService _protocol;
  Timer? _timer;
  StreamSubscription<({String nodeId, String cmd})>? _commands;
  int _ticks = 0;

  /// Watched projectors and the tick their next query is due at.
  final Map<String, int> _due = {};
  final Set<String> _armed = {};
  final Set<String> _inFlight = {};
  final Set<String> _confirming = {};

  /// Input switches the app made, per projector. A reading taken across one
  /// belongs to the old input (a query sent before `IIS` can come back with
  /// the new input's `ER401`), so it is dropped.
  final Map<String, int> _switches = {};

  /// The signal last seen in each watched node's telemetry, so readings
  /// that arrive another way (the regular poll, Remote Preview) are fed in
  /// once, as they change.
  final Map<String, String> _seen = {};

  /// Watched projectors queried at least once: their first reading is
  /// compared with a value that may be stale, so it isn't a change.
  final Set<String> _read = {};

  @override
  Map<String, SignalLoss> build() {
    _protocol = ref.read(protocolServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _commands?.cancel();
    });
    ref.listen(workspaceProvider, (_, nodes) => _sync(nodes));
    ref.listen(
      appSettingsProvider.select(
        (s) => s.alerts.isEnabled(AlertRule.signalLost),
      ),
      (_, _) => _sync(ref.read(workspaceProvider)),
    );
    _commands = ref
        .read(workspaceProvider.notifier)
        .commandsSent
        .listen(_onCommand);
    // Another provider's state can't change during build.
    Future.microtask(() => _sync(ref.read(workspaceProvider)));
    return const {};
  }

  /// Forgets [nodeIds]' dropouts once their alerts have cleared
  /// (acknowledged and over). All in one change: the alerts reconcile on
  /// each one, and a dropout still here then would raise its alert anew.
  void dismiss(Iterable<String> nodeIds) {
    if (!nodeIds.any(state.containsKey)) return;
    state = {...state}..removeWhere((id, _) => nodeIds.contains(id));
  }

  static bool _watchable(ProjectorNode n) =>
      (n.connectionStatus == ConnectionStatus.connected ||
          n.connectionStatus == ConnectionStatus.unprotected) &&
      n.powerStatus == PowerStatus.on;

  void _sync(List<ProjectorNode> nodes) {
    final enabled = ref
        .read(appSettingsProvider)
        .alerts
        .isEnabled(AlertRule.signalLost);
    final watched = [
      if (enabled)
        for (final n in nodes)
          if (_watchable(n)) n,
    ];
    final watchedIds = {for (final n in watched) n.id};

    for (final id in _due.keys.toList()) {
      if (!watchedIds.contains(id)) _forget(id);
    }

    // Dropouts of projectors no longer watched end there; those of removed
    // projectors, or all of them with the rule off, go.
    final existing = {for (final n in nodes) n.id};
    var next = <String, SignalLoss>{
      if (enabled)
        for (final e in state.entries)
          if (existing.contains(e.key))
            e.key: watchedIds.contains(e.key) ? e.value : e.value.ended(),
    };

    for (final (i, n) in watched.indexed) {
      if (_due.containsKey(n.id)) {
        if (_seen[n.id] != n.signal) {
          _seen[n.id] = n.signal;
          next = _feed(n, signalReadingOf(n.signal), next);
        }
        continue;
      }
      // Its slot in the period. The reading it has now may be stale (from
      // before power-on), so it isn't fed; the first query is.
      _due[n.id] = _ticks + 1 + i * _periodTicks ~/ watched.length;
      _seen[n.id] = n.signal;
    }

    if (!mapEquals(next, state)) state = next;

    if (_due.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(tick, (_) => _onTick());
    }
  }

  void _forget(String id) {
    _due.remove(id);
    _armed.remove(id);
    _seen.remove(id);
    _read.remove(id);
    _switches.remove(id);
  }

  void _onCommand(({String nodeId, String cmd}) c) {
    // A new input has to show a signal before its loss counts, so switching
    // to one with nothing connected raises nothing. An open dropout stays
    // open: a signal on the new input ends it as recovered.
    if (!c.cmd.startsWith('IIS:') || !_due.containsKey(c.nodeId)) return;
    _armed.remove(c.nodeId);
    _switches[c.nodeId] = (_switches[c.nodeId] ?? 0) + 1;
  }

  /// False when [id]'s input was switched since [switches] was read, or a
  /// command is going to it right now (the switch may already be on the
  /// projector before the app hears it succeeded).
  bool _stillCurrent(String id, int switches) =>
      (_switches[id] ?? 0) == switches &&
      !ref.read(workspaceProvider.notifier).isNodeBusy(id);

  void _onTick() {
    _ticks++;
    final due = [
      for (final e in _due.entries)
        if (e.value <= _ticks) e.key,
    ];
    final workspace = ref.read(workspaceProvider.notifier);
    for (final id in due) {
      if (_inFlight.length >= maxInFlight) return;
      // Keeps its slot; a projector more than a period behind restarts from
      // now instead of firing several overdue rounds back to back.
      _due[id] = max(_due[id]! + _periodTicks, _ticks + 1);
      if (_inFlight.contains(id) || workspace.isNodeBusy(id)) continue;
      unawaited(_query(id));
    }
  }

  ProjectorNode? _node(String id) =>
      ref.read(workspaceProvider).where((n) => n.id == id).firstOrNull;

  Future<void> _query(String id) async {
    final node = _node(id);
    if (node == null) return;
    _inFlight.add(id);
    final switches = _switches[id] ?? 0;
    final String? raw;
    try {
      raw = await _protocol.sendQuickQuery(
        node.ipAddress,
        node.port,
        node.login,
        node.password,
        'QVX:NSGS1',
      );
    } finally {
      _inFlight.remove(id);
    }
    final current = _node(id);
    if (raw == null || current == null || !_due.containsKey(id)) return;
    if (!_stillCurrent(id, switches)) return;
    final display = signalDisplayOf(raw);
    final changed = !_read.add(id) && _seen[id] != display;
    _seen[id] = display;
    final next = _feed(current, signalReadingOf(display), state);
    if (!mapEquals(next, state)) state = next;
    ref.read(workspaceProvider.notifier).applyPolledSignal(id, display);
    if (changed) unawaited(_readInput(current));
  }

  /// A changed signal often means a changed input, switched on the projector
  /// itself (remote, its web page), which the app doesn't hear about. One
  /// `QIN` keeps the Input column in step without a full poll.
  Future<void> _readInput(ProjectorNode node) async {
    final raw = await _protocol.sendQuickQuery(
      node.ipAddress,
      node.port,
      node.login,
      node.password,
      'QIN',
    );
    if (raw == null || raw.startsWith('ER') || !_due.containsKey(node.id)) {
      return;
    }
    ref
        .read(workspaceProvider.notifier)
        .applyPolledInput(node.id, mapInputCode(raw));
  }

  /// [losses] after [reading] for [node]. A suspected loss is confirmed
  /// asynchronously ([_confirmLoss]) and written to state from there.
  Map<String, SignalLoss> _feed(
    ProjectorNode node,
    SignalReading reading,
    Map<String, SignalLoss> losses,
  ) {
    final step = stepSignalWatch(
      armed: _armed.contains(node.id),
      loss: losses[node.id],
      reading: reading,
      now: DateTime.now(),
    );
    if (step.armed) _armed.add(node.id);
    if (step.lossCandidate) unawaited(_confirmLoss(node, DateTime.now()));
    final loss = step.loss;
    if (loss == null || loss == losses[node.id]) return losses;
    return {...losses, node.id: loss};
  }

  /// `ER401` is also what a projector answers in standby, which it may have
  /// gone to by itself; ask before raising, and let the regular poll catch
  /// up if it isn't on.
  Future<void> _confirmLoss(ProjectorNode node, DateTime since) async {
    if (!_confirming.add(node.id)) return;
    final switches = _switches[node.id] ?? 0;
    final String? raw;
    try {
      raw = await _protocol.sendQuickQuery(
        node.ipAddress,
        node.port,
        node.login,
        node.password,
        'QVX:POWI1',
      );
    } finally {
      _confirming.remove(node.id);
    }
    if (!_due.containsKey(node.id) || !_armed.contains(node.id)) return;
    if (!_stillCurrent(node.id, switches)) return;
    final power = parsePowerStatus(raw);
    if (power == PowerStatus.on) {
      if (state[node.id]?.open ?? false) return;
      final input = _node(node.id)?.input ?? node.input;
      state = {...state, node.id: SignalLoss(since: since, input: input)};
    } else if (power != null) {
      _armed.remove(node.id);
      unawaited(ref.read(workspaceProvider.notifier).refreshNode(node.id));
    }
    // No answer: still armed, the next reading asks again.
  }
}
