import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../domain/free_grid_view.dart';
import '../../../../domain/warp_control_grid.dart';
import '../../../../domain/warp_session_state.dart';
import '../../common/dialog_parts.dart';
import '../../custom_tooltip.dart';
import 'free_grid_painter.dart';
import 'free_grid_parts.dart';

/// The Free grid canvas: the loaded memory drawn in panel px, with the zoom
/// cluster in its corner. Zooming and panning only; selecting and dragging
/// points come later.
///
/// Ctrl (Cmd on a Mac) and the wheel zoom at the pointer, a pinch on a
/// trackpad too; the wheel scrolls, with Shift sideways; the middle button,
/// or Space and the primary button, pan. A drag on empty space is left for
/// the rubber band.
class FreeGridCanvas extends StatefulWidget {
  const FreeGridCanvas({
    super.key,
    required this.session,
    required this.compact,
    required this.enabled,
    required this.focusNode,
    this.clusterTrailing,
    this.onRangeFrameVisible,
  });

  /// Told, after a frame, when the dashed movable range frame comes into or
  /// leaves the view (the legend lists it only while it shows).
  final ValueChanged<bool>? onRangeFrameVisible;

  /// A loaded memory: [WarpSessionState.table] and [WarpSessionState.caps]
  /// are set.
  final WarpSessionState session;
  final bool compact;

  /// False while a write runs: the view stays as it is.
  final bool enabled;
  final FocusNode focusNode;

  /// What follows a separator at the end of the zoom cluster (the help
  /// button in a compact canvas).
  final Widget? clusterTrailing;

  @override
  State<FreeGridCanvas> createState() => _FreeGridCanvasState();
}

class _FreeGridCanvasState extends State<FreeGridCanvas> {
  FreeGridView? _view;
  Size? _lastSize;

  /// Whether the user moved the view: a resized window keeps the fit until
  /// then.
  bool _touched = false;

  bool? _rangeReported;
  bool _spaceDown = false;
  int? _panPointer;
  double _lastScale = 1;

  WarpControlGrid? _foldedFor;
  List<int> _folded = const [];

  void _setView(FreeGridView view) {
    setState(() {
      _view = view;
      _touched = true;
    });
  }

  List<int> _foldedCells(WarpControlGrid? grid) {
    if (!identical(grid, _foldedFor)) {
      _foldedFor = grid;
      _folded = grid == null ? const [] : foldedControlCells(grid);
    }
    return _folded;
  }

  FreeGridFrame _frameFor(Size size) {
    final caps = widget.session.caps!;
    return FreeGridFrame(
      panelWidth: caps.panelWidth,
      panelHeight: caps.panelHeight,
      rangeX: caps.movableRangeX,
      rangeY: caps.movableRangeY,
      canvas: size,
    );
  }

  bool get _modifierDown => freeGridIsMac
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  // ---------------------------------------------------------------- input

  void _onSignal(PointerSignalEvent event, FreeGridFrame frame) {
    if (!widget.enabled || _view == null) return;
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        e as PointerScrollEvent;
        final view = _view;
        if (view == null) return;
        if (_modifierDown) {
          final factor = math.pow(
            FreeGridFrame.zoomStep,
            -e.scrollDelta.dy / 100,
          );
          _setView(frame.zoomAbout(view, e.localPosition, factor.toDouble()));
        } else if (HardwareKeyboard.instance.isShiftPressed) {
          // The wheel's turn goes sideways; a device that sends a sideways
          // turn itself keeps it.
          final dx = e.scrollDelta.dy != 0
              ? e.scrollDelta.dy
              : e.scrollDelta.dx;
          _setView(frame.panBy(view, Offset(-dx, 0)));
        } else {
          _setView(frame.panBy(view, -e.scrollDelta));
        }
      });
    } else if (event is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        e as PointerScaleEvent;
        final view = _view;
        if (view == null) return;
        _setView(frame.zoomAbout(view, e.localPosition, e.scale));
      });
    }
  }

  void _onDown(PointerDownEvent e) {
    if (!widget.enabled) return;
    if (e.buttons == kPrimaryButton) widget.focusNode.requestFocus();
    final middle = e.buttons == kMiddleMouseButton;
    if (middle || (e.buttons == kPrimaryButton && _spaceDown)) {
      setState(() => _panPointer = e.pointer);
    }
  }

  void _onMove(PointerMoveEvent e, FreeGridFrame frame) {
    if (e.pointer != _panPointer || _view == null) return;
    _setView(frame.panBy(_view!, e.delta));
  }

  void _onUp(PointerEvent e) {
    if (e.pointer == _panPointer) setState(() => _panPointer = null);
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) => _lastScale = 1;

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e, FreeGridFrame frame) {
    final view = _view;
    if (!widget.enabled || view == null) return;
    final factor = e.scale / _lastScale;
    _lastScale = e.scale;
    _setView(
      frame.panBy(frame.zoomAbout(view, e.localPosition, factor), e.panDelta),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    final down = event is! KeyUpEvent;
    if (down != _spaceDown) setState(() => _spaceDown = down);
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final s = widget.session;
    final caps = s.caps!;
    final grid = s.controlGrid;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final frame = _frameFor(size);
        if (_view == null || _lastSize != size) {
          _view = _view == null || !_touched
              ? frame.fitPanel()
              : frame.clampView(_view!);
          _lastSize = size;
        }
        final view = _view!;
        final rangeVisible = frame.rangeFrameVisible(view);
        if (rangeVisible != _rangeReported) {
          _rangeReported = rangeVisible;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onRangeFrameVisible?.call(rangeVisible);
          });
        }
        final columns = grid?.columns ?? s.gridCounts.columns;
        final painter = FreeGridPainter(
          view: view,
          frame: frame,
          colors: FreeGridPaintColors(
            frame: t.tertiary,
            line: cs.primary,
            pointFill: DialogSurfaces.of(context).card,
            warning: AppStatusColors.of(context).warning,
          ),
          geometry: caps.geometry,
          plane: s.table!.planes.isEmpty ? null : s.table!.planes.first,
          grid: grid,
          foldedCells: _foldedCells(grid),
          pointRadius: grid == null
              ? 0
              : freeGridPointRadius(columns, compact: widget.compact),
          showTableLines: columns < freeGridDenseLinesBelowColumns,
        );
        final cursor = _panPointer != null
            ? SystemMouseCursors.grabbing
            : _spaceDown
            ? SystemMouseCursors.grab
            : MouseCursor.defer;
        return Listener(
          onPointerSignal: (e) => _onSignal(e, frame),
          onPointerDown: _onDown,
          onPointerMove: (e) => _onMove(e, frame),
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: (e) => _onPanZoomUpdate(e, frame),
          child: Focus(
            focusNode: widget.focusNode,
            onKeyEvent: _onKey,
            onFocusChange: (focused) {
              if (!focused && _spaceDown) setState(() => _spaceDown = false);
            },
            child: MouseRegion(
              cursor: cursor,
              child: Semantics(
                label: 'Control point canvas',
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('free-grid-paint'),
                          painter: painter,
                        ),
                      ),
                      Positioned(
                        right: widget.compact ? 8 : 10,
                        bottom: widget.compact ? 6 : 8,
                        child: _ZoomCluster(
                          compact: widget.compact,
                          enabled: widget.enabled,
                          fit: frame.nextFit(view),
                          // The view as it is when the button is pressed, not as
                          // it was at the last build: two presses in a row add
                          // up.
                          onZoomOut: () => _setView(
                            frame.zoomAboutCentre(
                              _view!,
                              1 / FreeGridFrame.zoomStep,
                            ),
                          ),
                          onZoomIn: () => _setView(
                            frame.zoomAboutCentre(
                              _view!,
                              FreeGridFrame.zoomStep,
                            ),
                          ),
                          onFit: () =>
                              _setView(frame.applyFit(frame.nextFit(_view!))),
                          trailing: widget.clusterTrailing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The small raised card in the canvas' corner: zoom out, zoom in, Fit, and
/// in a compact canvas the help button after a separator.
class _ZoomCluster extends StatelessWidget {
  const _ZoomCluster({
    required this.compact,
    required this.enabled,
    required this.fit,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
    required this.trailing,
  });

  final bool compact;
  final bool enabled;

  /// What the Fit button would do now.
  final FreeGridFit fit;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = compact ? 26.0 : 28.0;
    final separator = Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
    return DecoratedBox(
      key: const ValueKey('free-grid-zoom-cluster'),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FreeGridIconButton(
              key: const ValueKey('free-grid-zoom-out'),
              icon: FreeGridIcons.zoomOut,
              tooltip: 'Zoom out',
              size: size,
              iconSize: 16,
              placement: TooltipPlacement.top,
              onPressed: enabled ? onZoomOut : null,
            ),
            FreeGridIconButton(
              key: const ValueKey('free-grid-zoom-in'),
              icon: FreeGridIcons.zoomIn,
              tooltip: 'Zoom in',
              size: size,
              iconSize: 16,
              placement: TooltipPlacement.top,
              onPressed: enabled ? onZoomIn : null,
            ),
            separator,
            FreeGridIconButton(
              key: const ValueKey('free-grid-fit'),
              icon: fit == FreeGridFit.panel
                  ? FreeGridIcons.fitPanel
                  : FreeGridIcons.fitRange,
              tooltip: fit == FreeGridFit.panel
                  ? 'Fit panel'
                  : 'Fit movable range',
              size: size,
              iconSize: 16,
              placement: TooltipPlacement.top,
              onPressed: enabled ? onFit : null,
            ),
            if (trailing != null) ...[separator, trailing!],
          ],
        ),
      ),
    );
  }
}
