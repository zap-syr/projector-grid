import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/projector_node.dart';
import '../../../../domain/warp_codec.dart';
import '../../../../domain/warp_session_state.dart';
import '../../../providers/warp_edit_session_provider.dart';
import '../../dialog_title_bar.dart';
import 'free_grid_canvas_card.dart';
import 'free_grid_controls_card.dart';
import 'free_grid_memory_menu.dart';
import 'free_grid_parts.dart';

/// The body of the Geometry Correction dialog in the Free grid: the canvas
/// card, the controls card, and what they do with the session of one
/// projector ([warpEditSessionProvider]).
///
/// What this widget put on the projector (the grid overlay, the cursor) is
/// taken off again when it goes: when the mode changes through
/// [turnOffProjectorOverlays] and, as a last resort, when it is disposed
/// with the dialog.
class FreeGridEditor extends ConsumerStatefulWidget {
  const FreeGridEditor({super.key, required this.node, this.locked = false});

  final ProjectorNode node;

  /// The dialog is leaving the Free grid and waits for the projector to
  /// take the overlay off: nothing here may start a read or a write until
  /// the mode change is done. The layout does not change.
  final bool locked;

  @override
  ConsumerState<FreeGridEditor> createState() => FreeGridEditorState();
}

class FreeGridEditorState extends ConsumerState<FreeGridEditor> {
  // Captured while mounted: `ref` cannot be used in [dispose], and the
  // off-commands of a closing dialog must still go out. The subscription
  // keeps the (auto-dispose) session alive until they have.
  late final ProviderContainer _container;
  late final ProviderSubscription<WarpSessionState> _subscription;
  late final WarpEditSession _session;

  FreeGridProjectorSettings _settings = const FreeGridProjectorSettings();

  String get _id => widget.node.id;

  WarpSessionState get _state => _container.read(warpEditSessionProvider(_id));

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _subscription = _container.listen(warpEditSessionProvider(_id), (_, _) {});
    _session = _container.read(warpEditSessionProvider(_id).notifier);
  }

  @override
  void dispose() {
    final subscription = _subscription;
    unawaited(turnOffProjectorOverlays().whenComplete(subscription.close));
    super.dispose();
  }

  // ----------------------------------------------------------- projector

  /// Sends the grid overlay and the cursor off, when the session put them on
  /// and has not taken them off yet, whatever it is doing: after a read that
  /// failed, behind a poll that holds the projector (it waits for up to 5
  /// s), behind a transfer. The session keeps them marked as on while an off
  /// could not be sent, so the next leave or close tries again, and logs it
  /// when the overlay may still be on.
  Future<void> turnOffProjectorOverlays() async {
    if (!_session.overlayMayBeOn()) return;
    await _session.switchOffTracked();
  }

  /// The grid size the overlay was last sent with.
  int _overlayColumns = 0;
  int _overlayRows = 0;

  Future<void> _sendOverlay({required bool on, required int rgb}) {
    final s = _state;
    _overlayColumns = s.controlGrid?.columns ?? s.gridCounts.columns;
    _overlayRows = s.controlGrid?.rows ?? s.gridCounts.rows;
    return _session.showGridOverlay(
      on: on,
      columns: _overlayColumns,
      rows: _overlayRows,
      rgb: rgb,
    );
  }

  Future<void> _setOverlay(bool on) async {
    if (widget.locked) return;
    setState(() => _settings = _settings.copyWith(gridOverlayOn: on));
    if (on) {
      await _sendOverlay(on: true, rgb: _settings.overlayRgb);
      return;
    }
    // The off waits for the projector as long as a close would (5 s). When it
    // cannot be sent the overlay is still on the projector: the switch goes
    // back on, the footer says so, and leaving the mode tries again.
    final ok = await _session.switchOffOverlay(
      overlay: true,
      cursor: false,
      columns: _overlayColumns,
      rows: _overlayRows,
      rgb: _settings.overlayRgb,
    );
    if (!ok && mounted) {
      setState(() => _settings = _settings.copyWith(gridOverlayOn: true));
    }
  }

  Future<void> _setOverlayColor(int rgb) async {
    if (widget.locked) return;
    setState(() => _settings = _settings.copyWith(overlayRgb: rgb));
    if (_settings.gridOverlayOn) await _sendOverlay(on: true, rgb: rgb);
  }

  // -------------------------------------------------------------- memory

  /// The overlay belongs to the memory on screen: after another memory (or
  /// the same one again) is read it is sent again, so the projector and the
  /// switch agree.
  Future<void> _resendOverlay() async {
    if (!mounted || !_settings.gridOverlayOn) return;
    await _sendOverlay(on: true, rgb: _settings.overlayRgb);
  }

  Future<void> _selectMemory(WarpSlot slot) async {
    if (widget.locked) return;
    await _session.selectMemory(slot);
    await _resendOverlay();
  }

  Future<void> _reload() async {
    if (widget.locked) return;
    await _session.reload();
    await _resendOverlay();
  }

  String get _projectorLabel =>
      projectorLabel(widget.node.name, widget.node.ipAddress);

  Future<void> _restoreBackup() async {
    if (widget.locked) return;
    final s = _state;
    final taken = s.backupTakenAt;
    if (taken == null) return;
    final confirmed = await confirmFreeGridRestore(
      context,
      slotLabel: freeGridSlotLabel(s.slot),
      projector: _projectorLabel,
      backupTakenAt: taken,
      backupOfUnstored: s.backupOfUnstored,
    );
    if (!confirmed || !mounted) return;
    try {
      await _session.restoreBackup();
    } on StateError {
      // The memory went away while the confirm was open: nothing to restore.
    }
  }

  Future<void> _reset() async {
    if (widget.locked) return;
    final s = _state;
    final confirmed = await confirmFreeGridReset(
      context,
      slotLabel: freeGridSlotLabel(s.slot),
      projector: _projectorLabel,
      backupDue: _session.takesBackupOnNextWrite(),
      backupTakenAt: s.backupTakenAt,
    );
    if (!confirmed || !mounted) return;
    try {
      await _session.resetToNeutral(
        gridColumns: s.gridCounts.columns,
        gridRows: s.gridCounts.rows,
      );
    } on StateError {
      // The memory went away while the confirm was open: nothing to reset.
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(warpEditSessionProvider(_id));
    return FreeGridSplit(
      // One focus group per card: Tab goes through the canvas card, then the
      // controls card, each top to bottom, then on to the footer.
      builder: (compact) => (
        FocusTraversalGroup(
          child: FreeGridCanvasCard(
            session: session,
            compact: compact,
            onRetry: _reload,
            locked: widget.locked,
          ),
        ),
        FocusTraversalGroup(
          child: FreeGridControlsCard(
            session: session,
            locked: widget.locked,
            settings: _settings,
            onSelectMemory: _selectMemory,
            onReload: _reload,
            onRestoreBackup: _restoreBackup,
            // There are no edits to discard until editing exists.
            onDiscardChanges: null,
            onReset: _reset,
            onCursor: (on) =>
                setState(() => _settings = _settings.copyWith(cursorOn: on)),
            onGridOverlay: _setOverlay,
            onOverlayColor: _setOverlayColor,
            onLivePreview: (on) =>
                setState(() => _settings = _settings.copyWith(livePreview: on)),
          ),
        ),
      ),
    );
  }
}
