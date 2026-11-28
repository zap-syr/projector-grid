import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/panasonic_protocol_service.dart';
import '../../../../core/services/warp_backup_store.dart';
import '../../../../core/services/warp_transfer.dart';
import '../../domain/geometry_modes.dart';
import '../../domain/log_event.dart';
import '../../domain/projector_node.dart';
import '../../domain/warp_codec.dart';
import '../../domain/warp_control_grid.dart';
import '../../domain/warp_model_caps.dart';
import '../../domain/warp_session_state.dart';
import '../../domain/warp_table.dart';
import 'event_log_provider.dart';
import 'protocol_service_provider.dart';
import 'warp_backup_store_provider.dart';
import 'warp_window_close_guard_provider.dart';
import 'workspace_provider.dart';

part 'warp_edit_session_provider.g.dart';

/// How long a transfer waits for the regular poll to let go of the projector.
const Duration _claimTimeout = Duration(seconds: 3);

/// Overlays are cosmetic: they give up sooner.
const Duration _overlayClaimTimeout = Duration(seconds: 1);

/// Taking the overlay off waits longer than anything cosmetic: leaving it on
/// the projector is the one thing worse than a slow close.
const Duration _switchOffClaimTimeout = Duration(seconds: 5);

const Duration _claimStep = Duration(milliseconds: 100);

/// The least time between two live preview sends to one projector.
const Duration _previewGap = Duration(milliseconds: 120);

const String _busyMessage = 'Projector busy, try again';

enum _WriteKind {
  store('Storing', 'stored', 'store'),
  restore('Restoring', 'restored from backup', 'restore'),
  reset('Resetting', 'reset to neutral', 'reset');

  const _WriteKind(this.progressive, this.done, this.noun);

  /// "Storing PC-1 failed at step 3 of 12".
  final String progressive;

  /// "Free grid PC-1 stored".
  final String done;

  /// "Free grid PC-1 store failed".
  final String noun;
}

/// The free grid editor's session with one projector: the memory PC-1 to
/// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
/// while the editor is open, and nothing else talks to the projector's warp
/// memories.
///
/// Every transfer claims the projector from the regular poll and the signal
/// watch first (`claimNodeForExternalPoll`), so one projector never sees
/// more than one of the app's transfers at a time.
@riverpod
class WarpEditSession extends _$WarpEditSession
    implements WarpCloseParticipant {
  late PanasonicProtocolService _service;
  late WorkspaceNotifier _workspace;
  late WarpBackupStore _backups;
  late EventLogNotifier _eventLog;

  // One of open, reload, selectMemory, store, restoreBackup, resetToNeutral
  // is running. They are not meant to overlap; the editor disables its
  // actions while [WarpSessionState.busy].
  bool _working = false;

  // Whether a memory was read in this session: only the first read can tell
  // that a model has no stored memories at all.
  bool _firstReadDone = false;

  // Memories whose backup this session took already. The backup is the
  // memory as it was before the app first wrote to it, so a later write, or
  // a write after a Reload, must not replace it.
  final Set<WarpSlot> _backedUp = {};

  WarpTable? _pendingPreview;
  bool _previewInFlight = false;
  DateTime? _lastPreviewAt;
  Timer? _previewTimer;
  Future<void> _overlayTail = Future<void>.value();

  // The switch the editor asked for with [open]: a retry before the model is
  // known repeats it, so a memory is only shown once the projector is in it.
  WarpSlot? _requestedSwitch;
  Future<void> Function()? _requestedBeforeSwitch;

  // The write that runs now, for the window close to wait for.
  Future<void>? _activeWrite;

  // What this session left on the projector. It stays set until an off was
  // sent, so a failed off is tried again when the mode or the window goes.
  bool _overlayOn = false;
  bool _cursorOn = false;
  ({int columns, int rows, int rgb}) _overlayArgs = (
    columns: 3,
    rows: 3,
    rgb: 0x00FF00,
  );

  @override
  WarpSessionState build(String nodeId) {
    _service = ref.read(protocolServiceProvider);
    _workspace = ref.read(workspaceProvider.notifier);
    _backups = ref.read(warpBackupStoreProvider);
    _eventLog = ref.read(eventLogProvider.notifier);
    final guard = ref.read(warpWindowCloseGuardProvider);
    guard.register(this);
    ref.onDispose(() {
      _previewTimer?.cancel();
      guard.unregister(this);
    });
    return const WarpSessionState();
  }

  @override
  bool needsCloseSettle() => _activeWrite != null || _overlayOn || _cursorOn;

  @override
  Future<void> settleForClose() async {
    final write = _activeWrite;
    if (write != null) await write;
    await switchOffTracked();
  }

  ProjectorNode get _node =>
      ref.read(workspaceProvider).firstWhere((n) => n.id == nodeId);

  WarpLink _linkFor(ProjectorNode n) => ProtocolWarpLink(
    _service,
    ip: n.ipAddress,
    port: n.port,
    login: n.login,
    password: n.password,
  );

  String _backupKey(ProjectorNode n, WarpModelCaps caps) =>
      '${n.ipAddress}|${caps.id}';

  // ---------------------------------------------------------------- claim

  /// Waits up to [timeout] for the projector. False when it stays busy, and
  /// when this session ended meanwhile (the claim is given back then).
  Future<bool> _claim(Duration timeout) async {
    var claimed = _workspace.claimNodeForExternalPoll(nodeId);
    // Counts its own waits rather than reading the clock, so a test with a
    // fake clock can run it.
    for (var waited = Duration.zero; !claimed && waited < timeout;) {
      await Future<void>.delayed(_claimStep);
      waited += _claimStep;
      claimed = _workspace.claimNodeForExternalPoll(nodeId);
    }
    if (claimed && !ref.mounted) {
      _release();
      return false;
    }
    return claimed;
  }

  void _release() => _workspace.releaseNodeFromExternalPoll(nodeId);

  // ----------------------------------------------------------------- open

  /// Whether the next write to the current memory first saves a backup of
  /// it: true until this session has written to that memory once.
  bool takesBackupOnNextWrite() => !_backedUp.contains(state.slot);

  /// Finds out the model and loads a memory: the one the projector is in when
  /// that is PC-1 to PC-3, else PC-1. Reading does not change the mode.
  ///
  /// With [switchTo] the memory is read first, and only when it is there the
  /// projector is put in it with one `GMMI0` write (the data read is kept,
  /// there is no second read): the editor opens it from another geometry
  /// mode. A model the session cannot use is never written to, and neither
  /// is one whose first read says it has no memories.
  ///
  /// [beforeSwitch] runs after the memory was found and before the `GMMI0`
  /// write (the dialog's Quad Pixel Drive step).
  Future<void> open({
    WarpSlot? switchTo,
    Future<void> Function()? beforeSwitch,
  }) async {
    if (_working) return;
    _working = true;
    if (switchTo != null) {
      _requestedSwitch = switchTo;
      _requestedBeforeSwitch = beforeSwitch;
    }
    try {
      // A session opened again (the tile clicked after leaving the mode)
      // must not show the memory it held before.
      _beginLoad(state.slot);
      state = state.copyWith(
        phase: WarpSessionPhase.detecting,
        unsupportedReason: null,
        failureMessage: null,
        failureDetail: null,
      );
      final node = _node;
      if (!await _claim(_claimTimeout)) {
        if (ref.mounted) _fail(_busyMessage);
        return;
      }
      WarpModelCaps? caps;
      String? modeReply;
      Object? error;
      try {
        final mids = await _service.sendRawCommand(
          node.ipAddress,
          node.port,
          node.login,
          node.password,
          'QVX:MIDS1',
        );
        caps = mids == null ? null : warpModelCapsFromMids(mids);
        if (caps != null && warpModelSupported(caps) && switchTo == null) {
          modeReply = await _service.sendRawCommand(
            node.ipAddress,
            node.port,
            node.login,
            node.password,
            'QVX:GMMI0',
          );
        }
      } catch (e) {
        error = e;
      } finally {
        _release();
      }
      if (!ref.mounted) return;
      if (error != null) {
        _failRead(
          GeometryMode.forWarpSlot(switchTo ?? state.slot).label,
          error,
        );
        return;
      }
      if (caps == null) {
        state = state.copyWith(
          phase: WarpSessionPhase.unsupported,
          unsupportedReason: WarpUnsupportedReason.noModel,
        );
        return;
      }
      if (!warpModelSupported(caps)) {
        state = state.copyWith(
          caps: caps,
          phase: WarpSessionPhase.unsupported,
          unsupportedReason: WarpUnsupportedReason.format,
        );
        return;
      }
      state = state.copyWith(caps: caps);
      if (switchTo != null) {
        await _openInto(switchTo, beforeSwitch);
        return;
      }
      // A failed mode read is not handled here: the load reads it again and
      // reports the failure.
      final mode = modeReply == null
          ? null
          : GeometryMode.fromProtocol(modeReply.split('=').last);
      // Whichever memory it opens on, the projector must be in it: a
      // projector in Off or another mode ends in `failed`, not in a memory
      // shown while the projector is somewhere else.
      await _load(mode?.warpSlot ?? WarpSlot.pc1);
    } finally {
      _working = false;
    }
  }

  /// The [open] of a memory the projector is not in yet: read it, check that
  /// the model has it, then switch the projector and show what was read.
  Future<void> _openInto(
    WarpSlot slot,
    Future<void> Function()? beforeSwitch,
  ) async {
    _beginLoad(slot);
    final result = await _fetch(slot);
    if (result == null || !ref.mounted) return;
    if (_hasNoMemories(result)) {
      _markNotAvailable();
      return;
    }
    try {
      await beforeSwitch?.call();
    } catch (_) {
      // The step is the caller's to report (it did, to its own client): the
      // switch is still tried.
    }
    if (!ref.mounted) return;
    final node = _node;
    final mode = GeometryMode.forWarpSlot(slot);
    if (!await _claim(_claimTimeout)) {
      if (ref.mounted) _fail(_busyMessage);
      return;
    }
    var switched = false;
    Object? error;
    try {
      switched = await _service.sendCommand(
        node.ipAddress,
        node.port,
        node.login,
        node.password,
        'VXX:GMMI0=${mode.protocolValue}',
      );
    } catch (e) {
      error = e;
    } finally {
      _release();
    }
    if (!ref.mounted) return;
    if (!switched) {
      _fail(
        'Could not switch the projector to ${mode.label}. Try again.',
        detail: error?.toString(),
      );
      return;
    }
    await _present(slot, result);
  }

  // ----------------------------------------------------------------- read

  /// Switches the projector to memory [slot] (`GMMI0`), then reads it. Without
  /// a loaded model, while another call runs, or when the model has no
  /// memories this does nothing.
  Future<void> selectMemory(WarpSlot slot) async {
    final mode = GeometryMode.forWarpSlot(slot);
    if (!_canStartRead) return;
    _working = true;
    try {
      _beginLoad(slot);
      final node = _node;
      if (!await _claim(_claimTimeout)) {
        if (ref.mounted) _fail(_busyMessage);
        return;
      }
      var switched = false;
      Object? error;
      try {
        switched = await _service.sendCommand(
          node.ipAddress,
          node.port,
          node.login,
          node.password,
          'VXX:GMMI0=${mode.protocolValue}',
        );
      } catch (e) {
        error = e;
      } finally {
        _release();
      }
      if (!ref.mounted) return;
      if (!switched) {
        _fail(
          'Could not switch the projector to ${mode.label}. Try again.',
          detail: error?.toString(),
        );
        return;
      }
      await _load(slot);
    } finally {
      _working = false;
    }
  }

  /// Reads the current memory again. Opens the session instead while the
  /// model is not known yet. When the projector turns out not to be in the
  /// memory, nothing is shown and nothing is written: the operator selects
  /// the memory to switch it.
  Future<void> reload() async {
    // The model is not known yet (the first call was busy, or the worker
    // died): repeat what was asked, the switch included.
    if (state.caps == null) {
      return open(
        switchTo: _requestedSwitch,
        beforeSwitch: _requestedBeforeSwitch,
      );
    }
    if (!_canStartRead) return;
    _working = true;
    try {
      await _load(state.slot);
    } finally {
      _working = false;
    }
  }

  bool get _canStartRead =>
      !_working &&
      state.caps != null &&
      state.phase != WarpSessionPhase.unsupported;

  void _fail(String message, {String? detail}) {
    state = state.copyWith(
      phase: WarpSessionPhase.failed,
      failureMessage: message,
      failureDetail: detail,
      progressDone: 0,
      progressTotal: 0,
    );
  }

  /// A read that went wrong: the operator gets words and what to do; the
  /// reason goes to the event log and a tooltip.
  void _failRead(String label, Object error) {
    final reason = switch (error) {
      WarpProtocolException(:final message) => message,
      WarpTransportException(:final message) => message,
      _ => '$error',
    };
    // The mode is the read's first question: ER401 (not ready) and no reply
    // both say the projector gave none.
    final message = reason.contains('GMMI0')
        ? 'The projector did not report its geometry mode.'
        : 'The projector did not answer the read. Try again, or check that '
              'it is not busy.';
    final detail = 'Could not read $label: $reason';
    _fail(message, detail: detail);
    _logProblem('Free grid $label read failed: $reason');
  }

  void _logProblem(String message, {LogSeverity severity = LogSeverity.error}) {
    final n = _nodeOrNull;
    _eventLog.log(
      LogEvent(
        severity: severity,
        type: LogEventType.command,
        message: message,
        projectorIp: n?.ipAddress,
        projectorName: n?.name,
        nodeId: nodeId,
      ),
    );
  }

  ProjectorNode? get _nodeOrNull =>
      ref.read(workspaceProvider).where((n) => n.id == nodeId).firstOrNull;

  /// Forgets the data of the memory shown so far: nothing of it may be
  /// written into [slot] if the read fails.
  void _beginLoad(WarpSlot slot) {
    state = state.copyWith(
      phase: WarpSessionPhase.loading,
      slot: slot,
      failureMessage: null,
      failureDetail: null,
      lastStoreIncomplete: false,
      storedAt: null,
      table: null,
      readHeader: null,
      rawBlock: null,
      controlGrid: null,
      residual: null,
      readOnlyReason: null,
      undescribedDetail: false,
      backupTakenAt: null,
      backupOfUnstored: false,
    );
  }

  /// Reads memory [slot] under the claim. Null when it could not be read:
  /// the session is `failed` then, with the reason.
  Future<WarpReloadResult?> _fetch(WarpSlot slot) async {
    final caps = state.caps!;
    final node = _node;
    final label = GeometryMode.forWarpSlot(slot).label;
    if (!await _claim(_claimTimeout)) {
      if (ref.mounted) _fail(_busyMessage);
      return null;
    }
    WarpReloadResult? result;
    Object? error;
    try {
      result = await reloadWarpMemory(_linkFor(node), slot, caps);
    } catch (e) {
      // Whatever it was (a worker that died included), the session must not
      // stay in `loading`.
      error = e;
    } finally {
      _release();
    }
    if (!ref.mounted) return null;
    if (result == null) {
      _failRead(label, error ?? 'no answer');
      return null;
    }
    return result;
  }

  /// A first read that says the model has no memories at all.
  bool _hasNoMemories(WarpReloadResult result) =>
      result.read is WarpBlockNotAvailable &&
      !state.caps!.isNoInverse &&
      !_firstReadDone;

  void _markNotAvailable() {
    state = state.copyWith(
      phase: WarpSessionPhase.unsupported,
      unsupportedReason: WarpUnsupportedReason.notAvailable,
    );
  }

  /// Reads [slot] and shows it. With [checkMode] a projector that is not in
  /// the memory ends the read in `failed` (nothing is shown, so nothing can
  /// be written to a memory the projector is not showing).
  Future<void> _load(WarpSlot slot, {bool checkMode = true}) async {
    _beginLoad(slot);
    final result = await _fetch(slot);
    if (result == null || !ref.mounted) return;
    if (_hasNoMemories(result)) {
      _markNotAvailable();
      return;
    }
    final mode = GeometryMode.forWarpSlot(slot);
    if (checkMode &&
        '+${result.mode.toString().padLeft(5, '0')}' != mode.protocolValue) {
      _fail(
        'The projector is not in ${mode.label}. Select ${mode.label} to '
        'switch it.',
        detail: 'GMMI0 is ${result.mode}, not ${mode.protocolValue}',
      );
      return;
    }
    await _present(slot, result);
  }

  /// Shows what was read from [slot]. Whatever goes wrong while the table is
  /// turned into a grid ends in `failed`, never in a stuck `loading`.
  Future<void> _present(WarpSlot slot, WarpReloadResult result) async {
    try {
      await _presentUnguarded(slot, result);
    } catch (e) {
      if (ref.mounted) _failRead(GeometryMode.forWarpSlot(slot).label, e);
    }
  }

  Future<void> _presentUnguarded(WarpSlot slot, WarpReloadResult result) async {
    final caps = state.caps!;
    final node = _node;
    final label = GeometryMode.forWarpSlot(slot).label;
    final read = result.read;

    final WarpTable table;
    Uint8List? rawBlock;
    var method = warpMethodFull;
    switch (read) {
      case WarpBlockRead():
        try {
          table = decodeTable(read.block, WarpEncoding.triple, caps.bits);
        } on FormatException catch (e) {
          _fail(
            '$label holds a table this app cannot read. Try another memory.',
            detail: 'Could not read $label: ${e.message}',
          );
          _logProblem('Free grid $label read failed: ${e.message}');
          return;
        }
        rawBlock = read.block;
        method = read.method;
      case WarpBlockNotAvailable() || WarpBlockEmpty():
        table = identityWarpTable(caps.geometry);
    }
    _firstReadDone = true;

    final counts = result.gridCounts;
    WarpControlGrid? grid;
    double? residual;
    WarpReadOnlyReason? readOnlyReason;
    if (rawBlock == null) {
      grid = WarpControlGrid.identity(
        columns: counts.columns,
        rows: counts.rows,
        panelWidth: caps.panelWidth,
        panelHeight: caps.panelHeight,
      );
      residual = 0;
    } else if (table.planes.length != 1) {
      readOnlyReason = WarpReadOnlyReason.colourPlanes;
    } else {
      try {
        final fit = controlFromDense(
          table.planes.first,
          caps.geometry,
          columns: counts.columns,
          rows: counts.rows,
        );
        grid = fit.grid;
        residual = fit.residual;
      } on StateError {
        readOnlyReason = WarpReadOnlyReason.fit;
      }
    }

    WarpBackup? backup;
    try {
      backup = await _backups.load(_backupKey(node, caps), slot);
    } catch (_) {
      // A backup that cannot be read is no backup: the memory still shows.
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      backupOfUnstored: backup != null && backup.storedAt == null,
      phase: WarpSessionPhase.ready,
      storedAt: result.storedAt,
      gridCounts: counts,
      gridCountsDefaulted: result.gridCountsDefaulted,
      table: table,
      readHeader: rawBlock == null ? null : table.header,
      readMethod: method,
      rawBlock: rawBlock,
      controlGrid: grid,
      residual: residual,
      readOnlyReason: readOnlyReason,
      undescribedDetail: residual != null && hasUndescribedDetail(residual),
      backupTakenAt: backup?.takenAt,
    );
  }

  // ---------------------------------------------------------------- write

  /// Refuses what a write must not start from: no model, no memory loaded, a
  /// transfer running, or (for [allowReadOnly] false) a memory that cannot be
  /// edited.
  void _requireWritable({required bool allowReadOnly}) {
    if (_working) {
      throw StateError('a read or a transfer is already running');
    }
    if (state.phase == WarpSessionPhase.unsupported || state.caps == null) {
      throw StateError('this projector has no free grid memories');
    }
    if (state.table == null) throw StateError('no memory is loaded');
    if (!allowReadOnly && state.readOnly) {
      throw StateError('this memory is read-only');
    }
  }

  /// Stores [full], the table the editor built, into the current memory:
  /// the first write of the session backs the memory up first.
  Future<void> store(
    WarpTable full, {
    required int gridColumns,
    required int gridRows,
  }) async {
    _requireWritable(allowReadOnly: false);
    _working = true;
    try {
      await _write(
        _WriteKind.store,
        full,
        gridColumns: gridColumns,
        gridRows: gridRows,
        header: state.readHeader,
        now: DateTime.now().toUtc(),
        takeBackup: true,
      );
    } finally {
      _working = false;
    }
  }

  /// Writes a neutral table (no correction) into the current memory. Allowed
  /// for a memory the editor cannot open: it is the way back to something
  /// editable, and it is backed up like any first write.
  Future<void> resetToNeutral({
    required int gridColumns,
    required int gridRows,
  }) async {
    _requireWritable(allowReadOnly: true);
    _working = true;
    try {
      final current = state.table!;
      await _write(
        _WriteKind.reset,
        identityWarpTable(state.caps!.geometry, planes: current.planes.length),
        gridColumns: gridColumns,
        gridRows: gridRows,
        header: state.readHeader,
        now: DateTime.now().toUtc(),
        takeBackup: true,
      );
    } finally {
      _working = false;
    }
  }

  /// Puts the backup of the current memory back and reads the memory again.
  /// The table goes out through the normal store sequence, with the time and
  /// the numbers of control points the backup holds. The backup stays as it
  /// is. Throws a [StateError] when there is none.
  Future<void> restoreBackup() async {
    _requireWritable(allowReadOnly: true);
    _working = true;
    try {
      final caps = state.caps!;
      final slot = state.slot;
      final backup = await _backups.load(_backupKey(_node, caps), slot);
      if (backup == null) {
        throw StateError('there is no backup of this memory');
      }
      if (!ref.mounted) return;
      final WarpTable table;
      try {
        table = decodeTable(backup.block, WarpEncoding.triple, caps.bits);
      } on FormatException catch (e) {
        _fail('The backup is unusable: ${e.message}');
        return;
      }
      final counts = (
        columns: backup.gridColumns ?? warpDefaultGridCounts.columns,
        rows: backup.gridRows ?? warpDefaultGridCounts.rows,
      );
      final outcome = await _write(
        _WriteKind.restore,
        table,
        gridColumns: counts.columns,
        gridRows: counts.rows,
        header: table.header,
        now: backup.storedAt ?? DateTime.now().toUtc(),
        takeBackup: false,
      );
      if (!outcome.ok || !ref.mounted) return;
      // Read back what was written: the projector was in the memory for the
      // write, so the mode is not asked again.
      await _load(slot, checkMode: false);
      if (ref.mounted && outcome.incomplete) {
        state = state.copyWith(lastStoreIncomplete: true);
      }
    } finally {
      _working = false;
    }
  }

  /// Everything a Store, Restore and Reset share, known to the window close
  /// while it runs.
  Future<({bool ok, bool incomplete})> _write(
    _WriteKind kind,
    WarpTable table, {
    required int gridColumns,
    required int gridRows,
    required Uint8List? header,
    required DateTime now,
    required bool takeBackup,
  }) async {
    final run = _writeInner(
      kind,
      table,
      gridColumns: gridColumns,
      gridRows: gridRows,
      header: header,
      now: now,
      takeBackup: takeBackup,
    );
    _activeWrite = run.then<void>((_) {}, onError: (Object _) {});
    try {
      return await run;
    } finally {
      _activeWrite = null;
    }
  }

  /// Failures end in the `failed` phase and an event log row; the session
  /// stays usable.
  Future<({bool ok, bool incomplete})> _writeInner(
    _WriteKind kind,
    WarpTable table, {
    required int gridColumns,
    required int gridRows,
    required Uint8List? header,
    required DateTime now,
    required bool takeBackup,
  }) async {
    final caps = state.caps!;
    final slot = state.slot;
    final node = _node;
    final label = GeometryMode.forWarpSlot(slot).label;
    var done = 0;
    var total = 0;

    // A preview still waiting would land after the store and undo it.
    _previewTimer?.cancel();
    _previewTimer = null;
    _pendingPreview = null;
    state = state.copyWith(
      phase: WarpSessionPhase.storing,
      failureMessage: null,
      lastStoreIncomplete: false,
      progressDone: 0,
      progressTotal: 0,
    );

    WarpStoreResult? result;
    DateTime? backupTakenAt;
    // Set when this write takes the backup: whether the memory had ever been
    // stored then.
    bool? backupOfUnstored;
    // Why it failed, for the log; and for the editor, which also says what
    // state the projector may be in.
    String? reason;
    var nothingSent = true;

    if (!await _claim(_claimTimeout)) {
      if (!ref.mounted) return (ok: false, incomplete: false);
      reason = _busyMessage;
    } else {
      try {
        // Before the backup: a table that cannot be encoded must not replace
        // the backup of an earlier session.
        _checkEncodable(table, caps);
        if (takeBackup && !_backedUp.contains(slot)) {
          final neverStored = state.storedAt == null;
          backupTakenAt = await _saveBackup(node, caps, slot);
          backupOfUnstored = neverStored;
          _backedUp.add(slot);
        }
        nothingSent = false;
        result = await storeWarpMemory(
          _linkFor(node),
          slot: slot,
          caps: caps,
          full: table,
          readHeader: header,
          gridColumns: gridColumns,
          gridRows: gridRows,
          now: now,
          onProgress: (d, t) {
            done = d;
            total = t;
            if (ref.mounted) {
              state = state.copyWith(progressDone: d, progressTotal: t);
            }
          },
        );
      } on WarpNotEncodableException catch (e) {
        nothingSent = true;
        reason =
            'the shape does not fit the projector: ${e.check.badCount} '
            'table node(s) are out of range';
      } on WarpProtocolException catch (e) {
        reason = e.message;
      } on WarpTransportException catch (e) {
        reason = e.message;
      } on _BackupFailedException catch (e) {
        reason = 'the backup could not be saved (${e.cause})';
      } on ArgumentError catch (e) {
        // The encoders refuse before the first frame.
        nothingSent = true;
        reason = '${e.message}';
      } catch (e) {
        // Whatever it was, the phase must not stay `storing`.
        reason = '$e';
      } finally {
        _release();
      }
    }

    final warpResult = result;
    final String? failure;
    String? failureDetail;
    final String logMessage;
    var severity = LogSeverity.success;
    if (warpResult == null) {
      final step = 'step ${done + 1}${total > 0 ? ' of $total' : ''}';
      // One line that ends with what to do; the reason is the tooltip's.
      failure = nothingSent
          ? '${kind.progressive} $label failed, nothing was sent. Try again.'
          : '${kind.progressive} $label failed at $step, it may be partly '
                'written. Reload to check.';
      failureDetail = reason;
      logMessage = nothingSent
          ? 'Free grid $label ${kind.noun} failed, nothing was sent: $reason'
          : 'Free grid $label ${kind.noun} failed at $step: $reason';
      severity = LogSeverity.error;
    } else if (!warpResult.complete) {
      failure = null;
      logMessage =
          'Free grid $label ${kind.done}, but the stored time or the number '
          'of control points could not be saved';
      severity = LogSeverity.warning;
    } else {
      failure = null;
      logMessage = 'Free grid $label ${kind.done}';
    }
    _eventLog.log(
      LogEvent(
        severity: severity,
        type: LogEventType.command,
        message: logMessage,
        projectorIp: node.ipAddress,
        projectorName: node.name,
        nodeId: node.id,
      ),
    );
    if (!ref.mounted) {
      return (
        ok: warpResult != null,
        incomplete: warpResult?.complete == false,
      );
    }

    final takenAt = backupTakenAt ?? state.backupTakenAt;
    if (warpResult == null) {
      state = state.copyWith(
        phase: WarpSessionPhase.failed,
        failureMessage: failure,
        failureDetail: failureDetail,
        progressDone: 0,
        progressTotal: 0,
        backupTakenAt: takenAt,
        backupOfUnstored: backupOfUnstored ?? state.backupOfUnstored,
      );
      return (ok: false, incomplete: false);
    }
    state = state.copyWith(
      phase: WarpSessionPhase.ready,
      table: table,
      storedAt: warpResult.dateSaved ? now : state.storedAt,
      gridCounts: warpResult.gridCountsSaved
          ? (columns: gridColumns, rows: gridRows)
          : state.gridCounts,
      gridCountsDefaulted: warpResult.gridCountsSaved
          ? false
          : state.gridCountsDefaulted,
      lastStoreIncomplete: !warpResult.complete,
      progressDone: 0,
      progressTotal: 0,
      backupTakenAt: takenAt,
      backupOfUnstored: backupOfUnstored ?? state.backupOfUnstored,
    );
    return (ok: true, incomplete: !warpResult.complete);
  }

  /// The same two checks [storeWarpMemory] makes, to find out before the
  /// backup whether anything would be sent.
  void _checkEncodable(WarpTable full, WarpModelCaps caps) {
    final fullCheck = checkWarpEncodable(full, caps.bits);
    if (!fullCheck.ok) {
      throw WarpNotEncodableException(fullCheck, fpgaTable: false);
    }
    final fpga = fpgaTableFromFull(full, caps.geometry);
    final fpgaCheck = checkWarpEncodable(fpga, caps.bits);
    if (!fpgaCheck.ok) {
      throw WarpNotEncodableException(fpgaCheck, fpgaTable: true);
    }
  }

  /// Saves the memory as it was read, or the neutral table when it was empty,
  /// so Restore brings back what was there.
  Future<DateTime> _saveBackup(
    ProjectorNode node,
    WarpModelCaps caps,
    WarpSlot slot,
  ) async {
    final s = state;
    final Uint8List block;
    final int method;
    final raw = s.rawBlock;
    if (raw != null) {
      block = raw;
      method = s.readMethod;
    } else {
      final neutral = encodeTable(
        identityWarpTable(caps.geometry),
        WarpEncoding.triple,
        caps.bits,
      );
      block = Uint8List.fromList([...neutral.head, ...neutral.points]);
      method = warpMethodFull;
    }
    final takenAt = DateTime.now().toUtc();
    try {
      await _backups.save(
        WarpBackup(
          projectorKey: _backupKey(node, caps),
          modelId: caps.id,
          slot: slot,
          takenAt: takenAt,
          type: warpTypeCode(caps.fullBase, slot),
          method: method,
          gridColumns: s.gridCountsDefaulted ? null : s.gridCounts.columns,
          gridRows: s.gridCountsDefaulted ? null : s.gridCounts.rows,
          storedAt: s.storedAt,
          block: block,
        ),
      );
    } catch (e) {
      throw _BackupFailedException(e);
    }
    return takenAt;
  }

  // -------------------------------------------------------------- preview

  bool get _liveAllowed =>
      state.caps != null &&
      state.table != null &&
      state.phase != WarpSessionPhase.unsupported &&
      !state.busy;

  /// Shows [full] on the projector without storing it (the live RAM), while
  /// the editor is dragged. At most one send is in flight, two sends are at
  /// least 120 ms apart, and of the tables that arrive meanwhile only the
  /// latest goes out. Dropped while a read or a write runs. A failure goes to
  /// [WarpSessionState.previewError] and leaves the phase alone.
  void preview(WarpTable full) {
    if (!_liveAllowed) return;
    _pendingPreview = full;
    _pumpPreview();
  }

  void _pumpPreview() {
    if (!ref.mounted ||
        _previewInFlight ||
        _previewTimer != null ||
        _pendingPreview == null) {
      return;
    }
    final last = _lastPreviewAt;
    final wait = last == null
        ? Duration.zero
        : _previewGap - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(_sendPreview());
      return;
    }
    _previewTimer = Timer(wait, () {
      _previewTimer = null;
      _pumpPreview();
    });
  }

  Future<void> _sendPreview() async {
    final table = _pendingPreview!;
    _pendingPreview = null;
    _previewInFlight = true;
    _lastPreviewAt = DateTime.now();
    try {
      if (!_liveAllowed) return;
      final caps = state.caps!;
      final link = _linkFor(_node);
      // A poll holds the projector: keep the table for the next tick.
      if (!_workspace.claimNodeForExternalPoll(nodeId)) {
        _pendingPreview ??= table;
        return;
      }
      String? error;
      try {
        await writeWarpPreview(link, caps: caps, full: table);
      } on WarpNotEncodableException catch (e) {
        error =
            'Preview skipped: ${e.check.badCount} table node(s) are out of '
            'range';
      } on WarpProtocolException catch (e) {
        error = e.message;
      } on WarpTransportException catch (e) {
        error = e.message;
      } finally {
        _release();
      }
      _setPreviewError(error);
    } finally {
      _previewInFlight = false;
      _pumpPreview();
    }
  }

  void _setPreviewError(String? error) {
    if (!ref.mounted || state.previewError == error) return;
    state = state.copyWith(previewError: error);
  }

  // -------------------------------------------------------------- overlay

  /// Shows or hides the cursor on the control point at ([x], [y]).
  Future<void> showCursor({
    required bool on,
    required int x,
    required int y,
    int kind = 0,
  }) => _overlay((link) async {
    // Marked before the send: a command that failed half way may have shown
    // it. It is cleared when an off went out.
    if (on) _cursorOn = true;
    await sendWarpCursor(link, on: on, x: x, y: y, kind: kind);
    if (!on) _cursorOn = false;
  });

  /// Shows or hides the grid through the control points.
  Future<void> showGridOverlay({
    required bool on,
    required int columns,
    required int rows,
    required int rgb,
  }) => _overlay((link) async {
    if (on) {
      _overlayOn = true;
      _overlayArgs = (columns: columns, rows: rows, rgb: rgb);
    }
    await sendWarpGridOverlay(
      link,
      on: on,
      columns: columns,
      rows: rows,
      rgb: rgb,
    );
    if (!on) _overlayOn = false;
  });

  /// Highlights the control points whose mark is 1.
  Future<void> markPoints(List<int> marks) =>
      _overlay((link) => sendWarpPointMarks(link, marks));

  /// The cursor on the point at ([x], [y]) and the marks of the selection.
  Future<void> sendSelection({
    required int x,
    required int y,
    required List<int> marks,
  }) => _overlay((link) async {
    _cursorOn = true;
    await sendWarpSelection(link, x: x, y: y, marks: marks);
  });

  /// One overlay command at a time and in call order, each under the claim.
  /// Dropped while a read or a write runs. A projector that stays busy for a
  /// second is an error, as for the preview.
  Future<void> _overlay(Future<void> Function(WarpLink link) send) {
    if (!_liveAllowed) return Future<void>.value();
    return _enqueueOverlay(() => _overlayOnce(send));
  }

  /// Puts [job] after the overlay commands before it. A job never throws
  /// (they all catch), and the tail survives one that did anyway: a failed
  /// command must not stop every later one.
  Future<void> _enqueueOverlay(Future<void> Function() job) {
    final run = _overlayTail.then((_) => job()).catchError((Object _) {});
    _overlayTail = run;
    return run;
  }

  Future<void> _overlayOnce(Future<void> Function(WarpLink link) send) async {
    if (!ref.mounted || !_liveAllowed) return;
    final link = _linkFor(_node);
    if (!await _claim(_overlayClaimTimeout)) {
      _setPreviewError(_busyMessage);
      return;
    }
    String? error;
    try {
      await send(link);
    } on WarpProtocolException catch (e) {
      error = e.message;
    } on WarpTransportException catch (e) {
      error = e.message;
    } catch (e) {
      // A worker that died, anything else: the command failed, the queue
      // goes on.
      error = '$e';
    } finally {
      _release();
    }
    _setPreviewError(error);
  }

  /// Takes the grid overlay and the cursor off the projector, whatever the
  /// session is doing: a projector left showing them over another correction
  /// is worse than a command that waits. Unlike the other overlay commands
  /// this is sent while a read or a write runs (after it), while no memory is
  /// loaded (a read that failed), and it waits up to 5 s for the projector
  /// instead of 1 s. When it still cannot be sent an event log row says the
  /// overlay may still be on. True when everything asked for went out.
  Future<bool> switchOffOverlay({
    required bool overlay,
    required bool cursor,
    required int columns,
    required int rows,
    required int rgb,
  }) async {
    if (!overlay && !cursor) return true;
    var ok = false;
    await _enqueueOverlay(() async {
      if (!ref.mounted) return;
      final link = _linkFor(_node);
      String? reason;
      if (!await _claim(_switchOffClaimTimeout)) {
        reason = _busyMessage;
      } else {
        try {
          if (cursor) {
            await sendWarpCursor(link, on: false, x: 0, y: 0);
            _cursorOn = false;
          }
          if (overlay) {
            await sendWarpGridOverlay(
              link,
              on: false,
              columns: columns,
              rows: rows,
              rgb: rgb,
            );
            _overlayOn = false;
          }
          ok = true;
        } on WarpProtocolException catch (e) {
          reason = e.message;
        } on WarpTransportException catch (e) {
          reason = e.message;
        } catch (e) {
          reason = '$e';
        } finally {
          _release();
        }
      }
      if (ok) {
        _setPreviewError(null);
        return;
      }
      if (!ref.mounted) return;
      // Still marked as shown (see [_overlayOn]): the editor puts its switch
      // back on and the footer says so, and the next off is tried when the
      // mode or the window goes.
      _setPreviewError(
        overlay
            ? 'The grid overlay could not be turned off. Try again.'
            : 'The cursor could not be turned off. Try again.',
      );
      _logProblem(
        '${overlay ? 'Grid overlay' : 'Cursor'} may still be on: $reason',
      );
    });
    return ok;
  }

  /// Whether this session left the grid overlay or the cursor on the
  /// projector, as far as it knows.
  bool overlayMayBeOn() => _overlayOn || _cursorOn;

  /// Takes off what this session put on the projector and could not take off
  /// yet: the editor leaving the mode or the dialog, and the window close.
  /// True when nothing is left.
  Future<bool> switchOffTracked() => switchOffOverlay(
    overlay: _overlayOn,
    cursor: _cursorOn,
    columns: _overlayArgs.columns,
    rows: _overlayArgs.rows,
    rgb: _overlayArgs.rgb,
  );
}

/// The backup of a memory could not be saved, so nothing was sent.
class _BackupFailedException implements Exception {
  const _BackupFailedException(this.cause);

  final Object cause;
}
