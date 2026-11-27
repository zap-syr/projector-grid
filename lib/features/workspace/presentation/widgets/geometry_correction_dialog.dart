import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/geometry_corners.dart';
import '../../domain/geometry_modes.dart';
import '../../domain/geometry_preview.dart';
import '../../domain/geometry_values.dart';
import '../../domain/projector_node.dart';
import '../../domain/warp_model_caps.dart';
import '../../domain/warp_session_state.dart';
import '../providers/protocol_service_provider.dart';
import '../providers/warp_edit_session_provider.dart';
import 'command_failure_notice.dart';
import 'common/dialog_parts.dart';
import 'common/projector_settings_client.dart';
import 'dialog_title_bar.dart';
import 'geometry/corner_canvas_card.dart';
import 'geometry/corner_controls.dart';
import 'geometry/curved_controls.dart';
import 'geometry/free_grid/free_grid_editor.dart';
import 'geometry/free_grid/free_grid_footer.dart';
import 'geometry/free_grid/free_grid_parts.dart';
import 'geometry/geometry_loading.dart';
import 'geometry/geometry_mode_tiles.dart';
import 'geometry/geometry_off_state.dart';
import 'geometry/geometry_preview_card.dart';
import 'geometry/geometry_settings.dart';
import 'geometry/geometry_split.dart';
import 'geometry/keystone_controls.dart';

/// Geometry Correction (DIALOG_REDESIGN_PLAN §7): mode tiles, then the
/// preview or corner canvas card beside the controls card, and an info
/// footer. Every change is sent at once; the dialog closes with ✕.
class GeometryCorrectionDialog extends ConsumerStatefulWidget {
  final ProjectorNode node;

  const GeometryCorrectionDialog({super.key, required this.node});

  /// The size cap; the dialog takes all of it (or all a smaller window
  /// leaves), so it never changes size between modes.
  static const double maxWidth = 920;
  static const double maxHeight = 720;

  @override
  ConsumerState<GeometryCorrectionDialog> createState() =>
      _GeometryCorrectionDialogState();
}

class _GeometryCorrectionDialogState
    extends ConsumerState<GeometryCorrectionDialog> {
  late final _client = ProjectorSettingsClient(
    service: ref.read(protocolServiceProvider),
    node: widget.node,
    onFailure: (cmd) {
      if (mounted) notifyCommandFailure(context, cmd);
    },
  );

  /// Reading the current mode and the model (GMMI0, QID).
  bool _loading = true;
  GeometryMode _mode = GeometryMode.off;

  /// Modes whose values have been read; Off has none to read.
  final Set<GeometryMode> _loadedModes = {GeometryMode.off};
  final Set<GeometryMode> _readingModes = {};

  // Geometry modes need Quad Pixel Drive on, on models that have it: the
  // projector refuses Keystone / Curved / Corner while it is off. QPDI1
  // can't be read to tell (it answers only while the mode is Off and ER401
  // otherwise, on any model), so the tier comes from the model name.
  QuadPixelTier _tier = QuadPixelTier.none;

  final _keystone = KeystoneSettings();
  final _curved = CurvedSettings();
  final _corners = CornerModel();
  final _canvasFocus = FocusNode();

  /// Whether the model has the Free grid (memories PC-1 to PC-3 that this
  /// app can read and write): it gets a tile.
  bool _freeGridAvailable = false;

  // The Free grid's session outlives the editor widget, so leaving the mode
  // and coming back keeps the memory it was on. Held from the first need
  // until the dialog closes.
  final _editorKey = GlobalKey<FreeGridEditorState>();
  ProviderSubscription<WarpSessionState>? _sessionSubscription;
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  bool _leavingFreeGrid = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    _corners.dispose();
    _canvasFocus.dispose();
    super.dispose();
  }

  /// Derived rather than a flag, so a load finishing for a mode the user
  /// already left doesn't end the loading state of the current one.
  bool get _modeLoading => !_loadedModes.contains(_mode);

  WarpEditSession _ensureSession() {
    final provider = warpEditSessionProvider(widget.node.id);
    _sessionSubscription ??= _container.listen(provider, (_, _) {});
    return _container.read(provider.notifier);
  }

  // ─── Loading ─────────────────────────────────────────────────────────────
  Future<void> _loadInitial() async {
    final (modeRaw, model, mids) = await (
      _client.readValue('GMMI0'),
      _client.query('QID'),
      _client.query('QVX:MIDS1'),
    ).wait;
    if (!mounted) return;

    _tier = quadPixelTierFor(model ?? '');
    _corners.extended = _tier == QuadPixelTier.a;
    final caps = mids == null ? null : warpModelCapsFromMids(mids);
    _freeGridAvailable = caps != null && warpModelSupported(caps);
    setState(() {
      if (modeRaw != null) {
        final read = GeometryMode.fromProtocol(modeRaw);
        // A model without the Free grid shows a projector in PC-1 to PC-3
        // like Off: there is nothing else to show.
        _mode = read.isFreeGrid && !_freeGridAvailable
            ? GeometryMode.off
            : read;
      }
      _loading = false;
    });
    // The projector is in a memory already: read it, change nothing.
    if (_mode.isFreeGrid) {
      await _ensureSession().open();
      _leaveIfNoMemories(GeometryMode.off);
    }
    if (!mounted) return;
    await _ensureModeLoaded(_mode);
  }

  Future<void> _ensureModeLoaded(GeometryMode mode) async {
    if (_loadedModes.contains(mode) || !_readingModes.add(mode)) return;
    switch (mode) {
      case GeometryMode.corner:
        await _loadCorner();
      case GeometryMode.keystone:
        await _loadKeystone();
      case GeometryMode.curved:
        await _loadCurved();
      case GeometryMode.off ||
          GeometryMode.pc1 ||
          GeometryMode.pc2 ||
          GeometryMode.pc3:
        break;
    }
    if (!mounted) return;
    setState(() {
      _readingModes.remove(mode);
      _loadedModes.add(mode);
    });
  }

  Future<void> _loadCorner() async {
    final keys = [
      for (final c in GeometryCorner.values) c.vKey,
      for (final c in GeometryCorner.values) c.hKey,
      ...CornerModel.shapeKeys,
      'GMFIF',
    ];
    // A 15-wide burst stalls ~5% of the queries ~1s on a flagship; batches
    // of 8 keep the load well under 200ms.
    final results = await _client.queryAll([for (final k in keys) 'QVX:$k']);
    if (!mounted) return;
    _corners.load({
      for (final (i, k) in keys.indexed) k: parseKeyedInt(results[i], k) ?? 0,
    });
  }

  Future<void> _loadKeystone() async {
    final (gmks0, gmki4, gmki7, gmks8, gmks9) = await (
      _client.readDouble('GMKS0'),
      _client.readInt('GMKI4'),
      _client.readInt('GMKI7'),
      _client.readDouble('GMKS8'),
      _client.readDouble('GMKS9'),
    ).wait;
    if (!mounted) return;
    _keystone
      ..throwRatio = gmks0 ?? 1.5
      ..verticalBalance = gmki4 ?? 0
      ..horizontalBalance = gmki7 ?? 0
      ..vertical = gmks8 ?? 0.0
      ..horizontal = gmks9 ?? 0.0;
  }

  Future<void> _loadCurved() async {
    final (gmcs0, gmci2, gmci3, gmci6, gmci7, gmcs8, gmcs9, gmcia) = await (
      _client.readDouble('GMCS0'),
      _client.readInt('GMCI2'),
      _client.readInt('GMCI3'),
      _client.readInt('GMCI6'),
      _client.readInt('GMCI7'),
      _client.readDouble('GMCS8'),
      _client.readDouble('GMCS9'),
      _client.readInt('GMCIA'),
    ).wait;
    if (!mounted) return;
    _curved
      ..throwRatio = gmcs0 ?? 1.5
      ..verticalBalance = gmci2 ?? 0
      ..verticalArc = gmci3 ?? 0
      ..horizontalBalance = gmci6 ?? 0
      ..horizontalArc = gmci7 ?? 0
      ..vertical = gmcs8 ?? 0.0
      ..horizontal = gmcs9 ?? 0.0
      ..keepAspect = (gmcia ?? 0) == 1;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────
  Future<void> _selectMode(GeometryMode m) async {
    if (m.isFreeGrid) return _selectFreeGrid();
    if (m == _mode || _leavingFreeGrid) return;
    if (_mode.isFreeGrid) {
      // Not while the session reads or writes: its own GMMI0 could land
      // after this one and leave the projector in a memory.
      if (_container.read(warpEditSessionProvider(widget.node.id)).busy) {
        return;
      }
      // The grid overlay and the cursor go off before the mode changes, so
      // the projector is not left showing them over another correction.
      _leavingFreeGrid = true;
      try {
        await _editorKey.currentState?.turnOffProjectorOverlays();
      } finally {
        _leavingFreeGrid = false;
      }
      if (!mounted) return;
    }
    final wasOff = _mode == GeometryMode.off;
    // The selection and the layout switch at once; the round trips below
    // (each its own TCP connection) run under the loading layout instead
    // of holding the tiles.
    setState(() => _mode = m);
    // VXX:QPDI1=ON is idempotent, so its current state needn't be known.
    if (_tier != QuadPixelTier.none && wasOff) {
      await _client.writeBool('QPDI1', true);
    }
    await _client.writeRaw('VXX:GMMI0=${m.protocolValue}');
    if (!mounted) return;
    await _ensureModeLoaded(m);
  }

  /// The Free grid tile: the same Quad Pixel Drive step as the other modes,
  /// then the session puts the projector in a memory (the one it showed
  /// before in this dialog, else PC-1) and reads it, with the one `GMMI0`
  /// write that is.
  Future<void> _selectFreeGrid() async {
    if (_mode.isFreeGrid) return;
    final previous = _mode;
    final wasOff = previous == GeometryMode.off;
    final session = _ensureSession();
    final slot = _container.read(warpEditSessionProvider(widget.node.id)).slot;
    setState(() => _mode = GeometryModeTiles.freeGridTile);
    await session.open(
      switchTo: slot,
      // After the session has found the memory there, and before it switches
      // the projector: a model without memories is never written to.
      beforeSwitch: () async {
        if (_tier != QuadPixelTier.none && wasOff) {
          await _client.writeBool('QPDI1', true);
        }
      },
    );
    _leaveIfNoMemories(previous);
  }

  /// A model whose first read says it has no memories: the projector was not
  /// switched, so the dialog goes back to the mode it was in and the tile is
  /// gone for the rest of the dialog.
  void _leaveIfNoMemories(GeometryMode previous) {
    if (!mounted) return;
    final s = _container.read(warpEditSessionProvider(widget.node.id));
    if (s.phase != WarpSessionPhase.unsupported) return;
    setState(() {
      _mode = previous;
      _freeGridAvailable = false;
    });
  }

  Future<void> _writeResets(List<(String, bool)> registers) async {
    for (final (key, degrees) in registers) {
      if (degrees) {
        await _client.writeDeg(key, 0);
      } else {
        await _client.writeInt(key, 0);
      }
    }
  }

  void _resetKeystone() {
    setState(_keystone.resetCorrection);
    _writeResets(keystoneResetRegisters);
  }

  void _resetCurved() {
    setState(_curved.resetCorrection);
    _writeResets(curvedResetRegisters);
  }

  Future<void> _resetAllCorners() async {
    _corners.resetAllCorners();
    for (final c in GeometryCorner.values) {
      await _client.writeInt(c.vKey, 0);
    }
    for (final c in GeometryCorner.values) {
      await _client.writeInt(c.hKey, 0);
    }
  }

  Future<void> _commitCorners(List<(String, int)> commands) async {
    for (final (key, value) in commands) {
      await _client.writeInt(key, value);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final freeGrid = !_loading && _mode.isFreeGrid;
    // Only while the Free grid shows: the dialog needs the session's state
    // for the footer and to dim the other tiles while a write runs.
    final session = freeGrid
        ? ref.watch(warpEditSessionProvider(widget.node.id))
        : null;
    // A Store, Restore or Reset that is running is not left unseen: the
    // dialog stays (Esc, a click outside and the close button all ask the
    // route to pop, which is refused) until the write has ended.
    final writing = session?.phase == WarpSessionPhase.storing;
    return PopScope(
      canPop: !writing,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        // A cap the dialog fills: one size in every mode and while loading;
        // the smallest window (800×600) leaves about 720×550 inside the
        // insets.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: GeometryCorrectionDialog.maxWidth,
            maxHeight: GeometryCorrectionDialog.maxHeight,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DialogTitleBar(
                    icon: Icons.crop_free,
                    title: 'Geometry Correction',
                    projectorId: widget.node.id,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GeometryModeTiles(
                            mode: _loading ? null : _mode,
                            onSelected: _selectMode,
                            showFreeGrid: _freeGridAvailable,
                            // While the session reads or writes, the other
                            // modes wait: a GMMI0 of this dialog must not
                            // race the session's.
                            othersEnabled: !(session?.busy ?? false),
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildBody()),
                        ],
                      ),
                    ),
                  ),
                  if (session != null)
                    FreeGridFooter(
                      session: session,
                      compact: FreeGridSplit.isCompact(constraints.maxWidth),
                    )
                  else
                    DialogFooter(
                      message: SentRightAwayNote(
                        loading: _loading || _modeLoading,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_loading && _mode.isFreeGrid) {
      return FreeGridEditor(key: _editorKey, node: widget.node);
    }
    if (!_loading && _mode == GeometryMode.off) {
      return LayoutBuilder(
        builder: (context, constraints) => GeometryOffState(
          tier: _tier,
          compact:
              GeometrySplit.leftWidth(constraints.maxWidth) <
              GeometrySplit.compactBelow,
        ),
      );
    }
    return GeometrySplit(
      builder: (compact) => switch (_mode) {
        _ when _loading => (
          GeometryPreviewCard(
            preview: null,
            compact: compact,
            onReset: null,
            loading: const GeometryLoadingView(
              title: 'Reading geometry correction from the projector',
              detail: 'The controls appear once the current mode is read.',
            ),
          ),
          const GeometryControlsSkeleton(groups: [2, 2, 1]),
        ),
        GeometryMode.corner => _cornerCards(compact),
        GeometryMode.keystone => (
          GeometryPreviewCard(
            preview: keystonePreview(
              throwRatio: _keystone.throwRatio,
              vertical: _keystone.vertical,
              horizontal: _keystone.horizontal,
              verticalBalance: _keystone.verticalBalance,
              horizontalBalance: _keystone.horizontalBalance,
            ),
            compact: compact,
            onReset: _modeLoading ? null : _resetKeystone,
            loading: _modeLoading ? _modeLoadingView() : null,
          ),
          _modeLoading
              ? const GeometryControlsSkeleton(groups: [2, 2, 1])
              : KeystoneControls(
                  values: _keystone,
                  client: _client,
                  onChanged: () => setState(() {}),
                ),
        ),
        GeometryMode.curved ||
        GeometryMode.off ||
        GeometryMode.pc1 ||
        GeometryMode.pc2 ||
        GeometryMode.pc3 => (
          GeometryPreviewCard(
            preview: curvedPreview(
              throwRatio: _curved.throwRatio,
              verticalArc: _curved.verticalArc,
              horizontalArc: _curved.horizontalArc,
              vertical: _curved.vertical,
              horizontal: _curved.horizontal,
              verticalBalance: _curved.verticalBalance,
              horizontalBalance: _curved.horizontalBalance,
              keepAspect: _curved.keepAspect,
            ),
            compact: compact,
            onReset: _modeLoading ? null : _resetCurved,
            loading: _modeLoading ? _modeLoadingView() : null,
          ),
          _modeLoading
              ? const GeometryControlsSkeleton(groups: [2, 2, 2, 2])
              : CurvedControls(
                  values: _curved,
                  client: _client,
                  onChanged: () => setState(() {}),
                ),
        ),
      },
    );
  }

  (Widget, Widget) _cornerCards(bool compact) => (
    CornerCanvasCard(
      model: _corners,
      focusNode: _canvasFocus,
      compact: compact,
      onCommit: _commitCorners,
      onResetAll: _modeLoading ? null : _resetAllCorners,
      loading: _modeLoading ? _modeLoadingView() : null,
    ),
    _modeLoading
        ? const GeometryControlsSkeleton(groups: [4, 6])
        : CornerControls(
            model: _corners,
            client: _client,
            compact: compact,
            onCommit: _commitCorners,
            onCornerTap: _canvasFocus.requestFocus,
          ),
  );

  Widget _modeLoadingView() => GeometryLoadingView(
    title: 'Reading ${_mode.label} from the projector',
    detail:
        'Mode is already switched. The controls appear once the '
        '${_mode.valueCount} values are read.',
  );
}
