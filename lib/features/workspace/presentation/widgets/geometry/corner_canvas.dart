import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/geometry_corners.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import '../common/key_hold_repeater.dart';
import 'geometry_settings.dart';

/// Ctrl, Cmd or Shift held: a click adds a corner instead of replacing the
/// selection (the canvas handles and the corner rows alike).
bool cornerMultiSelectHeld() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight) ||
      keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);
}

/// The Corner Correction canvas: drag a handle, move the selected corners
/// with the arrow keys (held keys repeat), Ctrl / Cmd / Shift click for
/// several, double click resets one, a click on empty space clears.
///
/// Drawn at the scale that fits the logical [cornerCanvasSize] into the
/// space it gets (never above 1); pointer deltas are divided by it, and the
/// handles keep their screen size so they stay easy to grab.
class CornerCanvas extends StatefulWidget {
  const CornerCanvas({
    super.key,
    required this.model,
    required this.focusNode,
    required this.onCommit,
  });

  final CornerModel model;
  final FocusNode focusNode;

  /// `(register, value)` pairs to send, once per drag, key release or reset.
  final Future<void> Function(List<(String, int)>) onCommit;

  /// Screen radius of a handle and the size of its hit box.
  static const double handleRadius = 8;
  static const double handleHitSize = 28;

  @override
  State<CornerCanvas> createState() => _CornerCanvasState();
}

class _CornerCanvasState extends State<CornerCanvas> {
  final Map<GeometryCorner, Offset> _dragStarts = {};
  Offset? _dragStartGlobal;
  double _scale = 1;

  // Manual double-tap tracking: GestureDetector's onDoubleTap would delay
  // every single tap by kDoubleTapTimeout.
  GeometryCorner? _lastTapped;
  DateTime? _lastTapTime;

  late final _keys = KeyHoldRepeater(
    onStep: (key) {
      final (dh, dv) = _keyRawDelta(key);
      if (dh != 0 || dv != 0) widget.model.step(dh, dv);
    },
    onRelease: () => widget.onCommit(widget.model.commandsForSelected()),
  );

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  };

  /// One raw protocol unit per press, not a canvas pixel: on Tier A a
  /// canvas pixel inward is 12 units.
  static (int, int) _keyRawDelta(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowLeft => (-1, 0),
    LogicalKeyboardKey.arrowRight => (1, 0),
    LogicalKeyboardKey.arrowUp => (0, -1),
    LogicalKeyboardKey.arrowDown => (0, 1),
    _ => (0, 0),
  };

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_arrowKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (widget.model.selected.isEmpty) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _keys.press(event.logicalKey);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _keys.release();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  void _onHandleTap(GeometryCorner c) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTapped == c &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= kDoubleTapTimeout;
    _lastTapped = c;
    _lastTapTime = now;

    if (isDoubleTap) {
      widget.model.resetCorner(c);
      widget.onCommit(widget.model.commandsFor(c));
      return;
    }
    widget.focusNode.requestFocus();
    widget.model.select(c, additive: cornerMultiSelectHeld());
  }

  void _onPanStart(GeometryCorner c, DragStartDetails details) {
    widget.focusNode.requestFocus();
    final model = widget.model;
    model.include(c, additive: cornerMultiSelectHeld());
    _dragStarts
      ..clear()
      ..addAll({for (final s in model.selected) s: model.positionOf(s)});
    _dragStartGlobal = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _dragStartGlobal;
    if (start == null) return;
    widget.model.dragFrom(
      _dragStarts,
      (details.globalPosition - start) / _scale,
    );
  }

  void _onPanEnd() {
    _dragStartGlobal = null;
    widget.onCommit(widget.model.commandsForSelected());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = DialogSurfaces.of(context).card;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = cornerCanvasSize.width;
          final h = cornerCanvasSize.height;
          final sx = (constraints.maxWidth / w).clamp(0.0, 1.0);
          final sy = (constraints.maxHeight / h).clamp(0.0, 1.0);
          _scale = sx < sy ? sx : sy;
          final scale = _scale;
          return Center(
            child: SizedBox(
              key: const ValueKey('corner-canvas'),
              width: w * scale,
              height: h * scale,
              child: ListenableBuilder(
                listenable: widget.model,
                builder: (context, _) {
                  final model = widget.model;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: model.clearSelection,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CornerCanvasPainter(
                              scale: scale,
                              positions: {
                                for (final c in GeometryCorner.values)
                                  c: model.positionOf(c),
                              },
                              selected: model.selected,
                              linearityV: model.shape('GMFI5'),
                              linearityH: model.shape('GMFIA'),
                              pincushionUpper: model.shape('GMFIB'),
                              pincushionLower: model.shape('GMFIC'),
                              pincushionLeft: model.shape('GMFID'),
                              pincushionRight: model.shape('GMFIE'),
                              primary: cs.primary,
                              frame: cs.outline,
                              handleFill: card,
                            ),
                          ),
                        ),
                        for (final c in GeometryCorner.values)
                          _handle(c, model.positionOf(c) * scale),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handle(GeometryCorner c, Offset center) {
    const size = CornerCanvas.handleHitSize;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        key: ValueKey('corner-handle-${c.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onHandleTap(c),
        onPanStart: (d) => _onPanStart(c, d),
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => _onPanEnd(),
        child: MouseRegion(
          cursor: defaultTargetPlatform == TargetPlatform.macOS
              ? SystemMouseCursors.grab
              : SystemMouseCursors.move,
        ),
      ),
    );
  }
}

/// Draws the canvas: dashed outer limit, default frame, the range of each
/// selected corner, the corrected shape with its Pincushion bows and the
/// Linearity cross, then the handles. Shapes are laid out on the logical
/// canvas and mapped by [scale]; strokes and handles keep their screen size.
class CornerCanvasPainter extends CustomPainter {
  CornerCanvasPainter({
    required this.scale,
    required this.positions,
    required this.selected,
    required this.linearityV,
    required this.linearityH,
    required this.pincushionUpper,
    required this.pincushionLower,
    required this.pincushionLeft,
    required this.pincushionRight,
    required this.primary,
    required this.frame,
    required this.handleFill,
  });

  final double scale;
  final Map<GeometryCorner, Offset> positions;
  final Set<GeometryCorner> selected;

  // Linearity V/H (GMFI5 / GMFIA, ±127) shifts where the cross sits between
  // opposite edges; Pincushion Upper/Lower/Left/Right (GMFIB to GMFIE, ±100)
  // bows each edge with a parabola that is zero at its two corners.
  final int linearityV, linearityH;
  final int pincushionUpper, pincushionLower, pincushionLeft, pincushionRight;
  final Color primary, frame, handleFill;

  // Calibrated against VSS screenshots: the cross moves about 15 % of the
  // frame at ±127, an edge bows about 12 % of the 320×200 frame at ±100.
  static const double _crossAmplitude = 0.15;
  static const double _pincushionAmplitudeV = 24.0;
  static const double _pincushionAmplitudeH = 38.0;
  static const int _edgeSegments = 24;

  Offset get _ul => positions[GeometryCorner.ul]!;
  Offset get _ur => positions[GeometryCorner.ur]!;
  Offset get _ll => positions[GeometryCorner.ll]!;
  Offset get _lr => positions[GeometryCorner.lr]!;

  static double _parabola(double u) => 4 * u * (1 - u);

  // Positive Pincushion bows an edge inward, toward the centre, on all four
  // edges (checked on the projector; VSS draws some with the other sign).
  Offset _top(double u) => Offset.lerp(
    _ul,
    _ur,
    u,
  )!.translate(0, pincushionUpper / 100 * _pincushionAmplitudeV * _parabola(u));
  Offset _bottom(double u) => Offset.lerp(_ll, _lr, u)!.translate(
    0,
    -(pincushionLower / 100 * _pincushionAmplitudeV * _parabola(u)),
  );
  Offset _left(double v) => Offset.lerp(
    _ul,
    _ll,
    v,
  )!.translate(pincushionLeft / 100 * _pincushionAmplitudeH * _parabola(v), 0);
  Offset _right(double v) => Offset.lerp(_ur, _lr, v)!.translate(
    -(pincushionRight / 100 * _pincushionAmplitudeH * _parabola(v)),
    0,
  );

  // Bilinear Coons patch: blends the four (possibly bowed) edges into the
  // interior, so the cross follows the bows.
  Offset _coons(double u, double v) {
    final ruled =
        _top(u) * (1 - v) + _bottom(u) * v + _left(v) * (1 - u) + _right(v) * u;
    final bilinear =
        _ul * ((1 - u) * (1 - v)) +
        _ur * (u * (1 - v)) +
        _ll * ((1 - u) * v) +
        _lr * (u * v);
    return ruled - bilinear;
  }

  Offset _s(Offset p) => p * scale;

  // lineTo only, so the four edges chain into one closed subpath.
  void _appendCurve(Path path, Offset Function(double t) point) {
    for (var i = 1; i <= _edgeSegments; i++) {
      final p = _s(point(i / _edgeSegments));
      path.lineTo(p.dx, p.dy);
    }
  }

  Path _sampled(Offset Function(double t) point) {
    final start = _s(point(0));
    final path = Path()..moveTo(start.dx, start.dy);
    _appendCurve(path, point);
    return path;
  }

  Rect _scaled(Rect r) => Rect.fromLTRB(
    r.left * scale,
    r.top * scale,
    r.right * scale,
    r.bottom * scale,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(
      dashPath(Path()..addRect(_scaled(cornerOuterLimit)), 6, 4),
      framePaint,
    );
    canvas.drawRect(_scaled(cornerDefaultFrame), framePaint);

    for (final c in selected) {
      final range = RRect.fromRectAndRadius(
        _scaled(cornerBounds(c)),
        const Radius.circular(3),
      );
      canvas.drawRRect(range, Paint()..color = primary.withValues(alpha: 0.07));
      canvas.drawRRect(
        range,
        Paint()
          ..color = primary.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final start = _s(_ul);
    final boundary = Path()..moveTo(start.dx, start.dy);
    _appendCurve(boundary, _top);
    _appendCurve(boundary, _right);
    _appendCurve(boundary, (t) => _bottom(1 - t));
    _appendCurve(boundary, (t) => _left(1 - t));
    boundary.close();
    canvas.drawPath(boundary, Paint()..color = primary.withValues(alpha: 0.13));
    canvas.drawPath(
      boundary,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final cross = Paint()
      ..color = primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final across = (0.5 + linearityH / 127 * _crossAmplitude).clamp(0.0, 1.0);
    final down = (0.5 + linearityV / 127 * _crossAmplitude).clamp(0.0, 1.0);
    canvas.drawPath(_sampled((v) => _coons(across, v)), cross);
    canvas.drawPath(_sampled((u) => _coons(u, down)), cross);

    for (final c in GeometryCorner.values) {
      final p = _s(positions[c]!);
      if (selected.contains(c)) {
        canvas.drawCircle(
          p,
          17,
          Paint()..color = primary.withValues(alpha: 0.22),
        );
        canvas.drawCircle(
          p,
          CornerCanvas.handleRadius + 1,
          Paint()..color = primary,
        );
        canvas.drawCircle(
          p,
          CornerCanvas.handleRadius + 1,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      } else {
        canvas.drawCircle(
          p,
          CornerCanvas.handleRadius,
          Paint()..color = handleFill,
        );
        canvas.drawCircle(
          p,
          CornerCanvas.handleRadius,
          Paint()
            ..color = primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  // The model notifies on every change and the builder makes a new painter
  // with copied values, so compare them.
  @override
  bool shouldRepaint(CornerCanvasPainter old) =>
      old.scale != scale ||
      !_sameMap(old.positions, positions) ||
      !_sameSet(old.selected, selected) ||
      old.linearityV != linearityV ||
      old.linearityH != linearityH ||
      old.pincushionUpper != pincushionUpper ||
      old.pincushionLower != pincushionLower ||
      old.pincushionLeft != pincushionLeft ||
      old.pincushionRight != pincushionRight ||
      old.primary != primary ||
      old.frame != frame ||
      old.handleFill != handleFill;

  static bool _sameMap(
    Map<GeometryCorner, Offset> a,
    Map<GeometryCorner, Offset> b,
  ) => GeometryCorner.values.every((c) => a[c] == b[c]);

  static bool _sameSet(Set<GeometryCorner> a, Set<GeometryCorner> b) =>
      a.length == b.length && a.containsAll(b);
}
