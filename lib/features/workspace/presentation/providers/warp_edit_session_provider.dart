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
import 'workspace_provider.dart';

part 'warp_edit_session_provider.g.dart';

/// How long a transfer waits for the regular poll to let go of the projector.
const Duration _claimTimeout = Duration(seconds: 3);

/// Overlays are cosmetic: they give up sooner.
const Duration _overlayClaimTimeout = Duration(seconds: 1);

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
class WarpEditSession extends _$WarpEditSession {
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

  @override
  WarpSessionState build(String nodeId) {
    _service = ref.read(protocolServiceProvider);
    _workspace = ref.read(workspaceProvider.notifier);
    _backups = ref.read(warpBackupStoreProvider);
    _eventLog = ref.read(eventLogProvider.notifier);
    ref.onDispose(() => _previewTimer?.cancel());
    return const WarpSessionState();
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

  /// Finds out the model and loads a memory: the one the projector is in when
  /// that is PC-1 to PC-3, else PC-1. Reading does not change the mode.
  Future<void> open() async {
    if (_working) return;
    _working = true;
    try {
      state = state.copyWith(
        phase: WarpSessionPhase.detecting,
        unsupportedReason: null,
        failureMessage: null,
      );
      final node = _node;
      if (!await _claim(_claimTimeout)) {
        if (ref.mounted) _fail(_busyMessage);
        return;
      }
      WarpModelCaps? caps;
      String? modeReply;
      try {
        final mids = await _service.sendRawCommand(
          node.ipAddress,
          node.port,
          node.login,
          node.password,
          'QVX:MIDS1',
        );
        caps = mids == null ? null : warpModelCapsFromMids(mids);
        if (caps != null && warpModelSupported(caps)) {
          modeReply = await _service.sendRawCommand(
            node.ipAddress,
            node.port,
            node.login,
            node.password,
            'QVX:GMMI0',
          );
        }
      } finally {
        _release();
      }
      if (!ref.mounted) return;
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
      // A failed mode read is not handled here: the load reads it again and
      // reports the failure.
      final mode = modeReply == null
          ? null
          : GeometryMode.fromProtocol(modeReply.split('=').last);
      state = state.copyWith(caps: caps);
      await _load(mode?.warpSlot ?? WarpSlot.pc1);
    } finally {
      _working = false;
    }
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
      final bool switched;
      try {
        switched = await _service.sendCommand(
          node.ipAddress,
          node.port,
          node.login,
          node.password,
          'VXX:GMMI0=${mode.protocolValue}',
        );
      } finally {
        _release();
      }
      if (!ref.mounted) return;
      if (!switched) {
        _fail('Could not switch the projector to ${mode.label}.');
        return;
      }
      await _load(slot);
    } finally {
      _working = false;
    }
  }

  /// Reads the current memory again. Opens the session instead while the
  /// model is not known yet.
  Future<void> reload() async {
    if (state.caps == null) return open();
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

  void _fail(String message) {
    state = state.copyWith(
      phase: WarpSessionPhase.failed,
      failureMessage: message,
      progressDone: 0,
      progressTotal: 0,
    );
  }

  /// Forgets the data of the memory shown so far: nothing of it may be
  /// written into [slot] if the read fails.
  void _beginLoad(WarpSlot slot) {
    state = state.copyWith(
      phase: WarpSessionPhase.loading,
      slot: slot,
      failureMessage: null,
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
    );
  }

  Future<void> _load(WarpSlot slot) async {
    final caps = state.caps!;
    final node = _node;
    final label = GeometryMode.forWarpSlot(slot).label;
    _beginLoad(slot);

    if (!await _claim(_claimTimeout)) {
      if (ref.mounted) _fail(_busyMessage);
      return;
    }
    WarpReloadResult? result;
    String? error;
    try {
      result = await reloadWarpMemory(_linkFor(node), slot, caps);
    } on WarpProtocolException catch (e) {
      error = e.message;
    } on WarpTransportException catch (e) {
      error = e.message;
    } finally {
      _release();
    }
    if (!ref.mounted) return;
    if (result == null) {
      _fail('Could not read $label: $error');
      return;
    }

    final read = result.read;
    if (read is WarpBlockNotAvailable && !caps.isNoInverse && !_firstReadDone) {
      state = state.copyWith(
        phase: WarpSessionPhase.unsupported,
        unsupportedReason: WarpUnsupportedReason.notAvailable,
      );
      return;
    }

    final WarpTable table;
    Uint8List? rawBlock;
    var method = warpMethodFull;
    switch (read) {
      case WarpBlockRead():
        try {
          table = decodeTable(read.block, WarpEncoding.triple, caps.bits);
        } on FormatException catch (e) {
          _fail('$label holds a table this app cannot read: ${e.message}');
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

    final backup = await _backups.load(_backupKey(node, caps), slot);
    if (!ref.mounted) return;
    state = state.copyWith(
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
      await _load(slot);
      if (ref.mounted && outcome.incomplete) {
        state = state.copyWith(lastStoreIncomplete: true);
      }
    } finally {
      _working = false;
    }
  }

  /// Everything a Store, Restore and Reset share. Failures end in the
  /// `failed` phase and an event log row; the session stays usable.
  Future<({bool ok, bool incomplete})> _write(
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
          backupTakenAt = await _saveBackup(node, caps, slot);
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
    final String logMessage;
    var severity = LogSeverity.success;
    if (warpResult == null) {
      final step = 'step ${done + 1}${total > 0 ? ' of $total' : ''}';
      failure = nothingSent
          ? '${kind.progressive} $label failed: $reason. Nothing was sent.'
          : '${kind.progressive} $label failed at $step: $reason. The memory '
                'may be partly written: press Reload to see what the '
                'projector holds.';
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
        progressDone: 0,
        progressTotal: 0,
        backupTakenAt: takenAt,
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
  }) =>
      _overlay((link) => sendWarpCursor(link, on: on, x: x, y: y, kind: kind));

  /// Shows or hides the grid through the control points.
  Future<void> showGridOverlay({
    required bool on,
    required int columns,
    required int rows,
    required int rgb,
  }) => _overlay(
    (link) => sendWarpGridOverlay(
      link,
      on: on,
      columns: columns,
      rows: rows,
      rgb: rgb,
    ),
  );

  /// Highlights the control points whose mark is 1.
  Future<void> markPoints(List<int> marks) =>
      _overlay((link) => sendWarpPointMarks(link, marks));

  /// The cursor on the point at ([x], [y]) and the marks of the selection.
  Future<void> sendSelection({
    required int x,
    required int y,
    required List<int> marks,
  }) => _overlay((link) => sendWarpSelection(link, x: x, y: y, marks: marks));

  /// One overlay command at a time and in call order, each under the claim.
  /// Dropped while a read or a write runs. A projector that stays busy for a
  /// second is an error, as for the preview.
  Future<void> _overlay(Future<void> Function(WarpLink link) send) {
    if (!_liveAllowed) return Future<void>.value();
    final run = _overlayTail.then((_) => _overlayOnce(send));
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
    } finally {
      _release();
    }
    _setPreviewError(error);
  }
}

/// The backup of a memory could not be saved, so nothing was sent.
class _BackupFailedException implements Exception {
  const _BackupFailedException(this.cause);

  final Object cause;
}
