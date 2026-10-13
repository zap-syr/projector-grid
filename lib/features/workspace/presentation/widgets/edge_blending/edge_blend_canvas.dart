import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart'
    show DragStartBehavior, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../common/key_hold_repeater.dart';
import 'black_level_state.dart';
import 'edge_blend_state.dart';

typedef EdgePick = ({BlendEdge edge, EdgePart part});

/// The projector raster with each edge's blend zone: drag the Start / Width
/// handles, arrows (Shift ×10) nudge the selected one. One paint pass and one
/// gesture detector with its own hit-testing, so a drag repaints nothing but
/// this canvas' layer.
///
/// Given [black], it's the Black Level tab's canvas instead: overlapped
/// zones in their level's colour, hatched black border bands, and one
/// handle per edge that moves the border width ([EdgePart.border]).
class EdgeBlendCanvas extends StatefulWidget {
  const EdgeBlendCanvas({
    super.key,
    required this.state,
    this.black,
    required this.raster,
    required this.interactive,
    required this.selection,
    required this.onSelect,
    required this.onClearSelection,
    required this.onPreview,
    required this.onCommit,
    required this.onResetEdge,
  });

  final EdgeBlendState state;
  final BlackLevelState? black;
  final EdgeBlendRaster raster;

  /// False while the mode is Off: the zones stay visible, nothing moves.
  final bool interactive;
  final EdgePick? selection;
  final void Function(BlendEdge edge, EdgePart part) onSelect;
  final VoidCallback onClearSelection;
  final void Function(BlendEdge edge, EdgePart part, int v) onPreview;
  final void Function(BlendEdge edge, EdgePart part) onCommit;
  final void Function(BlendEdge edge) onResetEdge;

  @override
  State<EdgeBlendCanvas> createState() => _EdgeBlendCanvasState();
}

class _EdgeBlendCanvasState extends State<EdgeBlendCanvas> {
  // Room around the raster for handles and value chips on the outer edges.
  static const double _margin = 16;
  static const double _handleHitRadius = 12;
  static const double _minZoneHitThickness = 10;

  final _focusNode = FocusNode();
  late final _keys = KeyHoldRepeater(
    onStep: _onKeyStep,
    onRelease: () {
      final target = _keyTarget;
      if (target != null) widget.onCommit(target.edge, target.part);
      _keyTarget = null;
    },
  );

  _RasterBox? _box;
  EdgePick? _hover;
  bool _hoverOnHandle = false;
  ({BlendEdge edge, EdgePart part, int v0, double in0})? _drag;
  EdgePick? _keyTarget;

  // Manual double-click tracking, as in the Corner canvas: onDoubleTap
  // would delay every single click by kDoubleTapTimeout.
  EdgePick? _lastTapped;
  DateTime? _lastTapTime;

  @override
  void didUpdateWidget(EdgeBlendCanvas old) {
    super.didUpdateWidget(old);
    // Esc or a click elsewhere while an arrow is held: its key-up may never
    // reach us as a step for this edge, so end the hold (and send) now.
    // onCommit only queues the write, nothing rebuilds during this build.
    if (widget.selection != old.selection || !widget.interactive) {
      _keys.release();
    }
    if (!widget.interactive) _hover = null;
  }

  @override
  void dispose() {
    _keys.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _blackMode => widget.black != null;

  int _valueOf(BlendEdge edge, EdgePart part) => part == EdgePart.border
      ? widget.black!.borderWidth(edge)
      : widget.state[edge].valueOf(part);

  /// A disabled edge's blend handles are hidden; its border width is still
  /// accepted by the projector (§8), so the border handle never is.
  bool _hasHandles(BlendEdge edge) => _blackMode || widget.state[edge].enabled;

  // ─── Hit-testing ─────────────────────────────────────────────────────────
  /// A handle (part set) beats a zone (part null); null = empty space.
  ({BlendEdge edge, EdgePart? part})? _hitTest(Offset p) {
    final box = _box;
    if (box == null || !widget.interactive) return null;
    final state = widget.state;
    final black = widget.black;

    EdgePick? nearest;
    var nearestDist = _handleHitRadius;
    for (final edge in BlendEdge.values) {
      if (!_hasHandles(edge)) continue;
      double dist(EdgePart part) =>
          (box.handleAt(edge, _handleUnits(state, black, edge, part)) - p)
              .distance;
      final EdgePart part;
      final double d;
      if (black != null) {
        (part, d) = (EdgePart.border, dist(EdgePart.border));
      } else {
        // Both handles share the line's midpoint, so at a small Width they
        // overlap: Width is drawn on top and wins, and once it's pulled
        // away Start is reachable again.
        final widthDist = dist(EdgePart.width);
        (part, d) = widthDist <= _handleHitRadius
            ? (EdgePart.width, widthDist)
            : (EdgePart.start, dist(EdgePart.start));
      }
      if (d <= nearestDist) {
        nearest = (edge: edge, part: part);
        nearestDist = d;
      }
    }
    if (nearest != null) return (edge: nearest.edge, part: nearest.part);

    for (final edge in BlendEdge.values) {
      final depth = black != null
          ? black.borderWidth(edge)
          : state[edge].start + state[edge].width;
      if (box.bandHitRect(edge, depth, _minZoneHitThickness).contains(p)) {
        return (edge: edge, part: null);
      }
    }
    return null;
  }

  void _updateHover(Offset p) {
    final hit = _hitTest(p);
    final next = hit == null
        ? null
        : (edge: hit.edge, part: hit.part ?? EdgePart.start);
    final onHandle = hit?.part != null;
    if (next != _hover || onHandle != _hoverOnHandle) {
      setState(() {
        _hover = next;
        _hoverOnHandle = onHandle;
      });
    }
  }

  MouseCursor get _cursor {
    final hover = _hover;
    if (hover == null) return SystemMouseCursors.basic;
    if (!_hoverOnHandle) return SystemMouseCursors.click;
    return hover.edge.isHorizontal
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.resizeUpDown;
  }

  // ─── Pointer ─────────────────────────────────────────────────────────────
  void _onTapUp(TapUpDetails details) {
    final hit = _hitTest(details.localPosition);
    if (hit == null) {
      widget.onClearSelection();
      return;
    }
    _focusNode.requestFocus();
    final part = hit.part;
    if (part == null) {
      // A click on a zone keeps the part already chosen on that edge.
      final sel = widget.selection;
      widget.onSelect(
        hit.edge,
        _blackMode
            ? EdgePart.border
            : sel != null && sel.edge == hit.edge
            ? sel.part
            : EdgePart.start,
      );
      return;
    }
    final pick = (edge: hit.edge, part: part);
    final now = DateTime.now();
    final isDouble =
        _lastTapped == pick &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= kDoubleTapTimeout;
    _lastTapped = pick;
    _lastTapTime = now;
    widget.onSelect(pick.edge, pick.part);
    if (isDouble) widget.onResetEdge(pick.edge);
  }

  void _onPanStart(DragStartDetails details) {
    final hit = _hitTest(details.localPosition);
    final part = hit?.part;
    if (hit == null || part == null) return;
    _focusNode.requestFocus();
    widget.onSelect(hit.edge, part);
    setState(() {
      _drag = (
        edge: hit.edge,
        part: part,
        v0: _valueOf(hit.edge, part),
        in0: _box!.inward(hit.edge, details.localPosition),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final drag = _drag;
    if (drag == null) return;
    final moved = _box!.inward(drag.edge, details.localPosition) - drag.in0;
    _preview(drag.edge, drag.part, (drag.v0 + moved).round());
  }

  void _onPanEnd() {
    final drag = _drag;
    if (drag == null) return;
    setState(() => _drag = null);
    widget.onCommit(drag.edge, drag.part);
  }

  void _preview(BlendEdge edge, EdgePart part, int v) {
    final max = widget.state.maxFor(edge, part, widget.raster);
    final clamped = v.clamp(0, max);
    if (clamped != _valueOf(edge, part)) {
      widget.onPreview(edge, part, clamped);
    }
  }

  // ─── Keyboard ────────────────────────────────────────────────────────────
  /// +1 for the arrow pointing inward from the edge (Right arrow grows the
  /// Left zone), −1 for the outward one, null for the other axis.
  static int? _inwardSign(BlendEdge edge, LogicalKeyboardKey key) =>
      switch ((edge, key)) {
        (BlendEdge.left, LogicalKeyboardKey.arrowRight) => 1,
        (BlendEdge.left, LogicalKeyboardKey.arrowLeft) => -1,
        (BlendEdge.right, LogicalKeyboardKey.arrowLeft) => 1,
        (BlendEdge.right, LogicalKeyboardKey.arrowRight) => -1,
        (BlendEdge.upper, LogicalKeyboardKey.arrowDown) => 1,
        (BlendEdge.upper, LogicalKeyboardKey.arrowUp) => -1,
        (BlendEdge.lower, LogicalKeyboardKey.arrowUp) => 1,
        (BlendEdge.lower, LogicalKeyboardKey.arrowDown) => -1,
        _ => null,
      };

  void _onKeyStep(LogicalKeyboardKey key) {
    final target = _keyTarget;
    if (target == null || !mounted) return;
    final sign = _inwardSign(target.edge, key)!;
    final step = HardwareKeyboard.instance.isShiftPressed ? 10 : 1;
    final current = _valueOf(target.edge, target.part);
    _preview(target.edge, target.part, current + sign * step);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // The held key's release ends the hold whatever is selected by then.
    if (event is KeyUpEvent && event.logicalKey == _keys.held) {
      _keys.release();
      return KeyEventResult.handled;
    }
    final sel = widget.selection;
    if (!widget.interactive ||
        sel == null ||
        !_hasHandles(sel.edge) ||
        _inwardSign(sel.edge, event.logicalKey) == null) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent():
        _keyTarget = sel;
        _keys.press(event.logicalKey);
      case KeyUpEvent():
        _keys.release();
      case KeyRepeatEvent():
        break;
    }
    return KeyEventResult.handled;
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      // A key-up that lands elsewhere would leave the hold running.
      onFocusChange: (focused) {
        if (!focused) _keys.release();
      },
      child: Semantics(
        label: 'Edge blend preview',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = _RasterBox.fit(
              constraints.biggest,
              widget.raster,
              _margin,
            );
            _box = box;
            final drag = _drag;
            return MouseRegion(
              cursor: _cursor,
              onHover: (e) => _updateHover(e.localPosition),
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTapUp: _onTapUp,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: (_) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: CustomPaint(
                  size: constraints.biggest,
                  painter: _EdgeBlendPainter(
                    box: box,
                    state: widget.state,
                    black: widget.black,
                    interactive: widget.interactive,
                    selection: widget.selection,
                    hoverEdge: _hover?.edge,
                    dragging: drag == null
                        ? null
                        : (edge: drag.edge, part: drag.part),
                    raster: scheme.surfaceContainerHighest,
                    outline: scheme.outline,
                    startColor: scheme.primary,
                    endColor: scheme.tertiary,
                    idleZone: scheme.outlineVariant,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The raster's on-screen rectangle and the unit ↔ pixel mapping.
class _RasterBox {
  _RasterBox(this.rect, this.raster);

  /// The largest rectangle with the raster's aspect ratio that fits [size]
  /// minus [margin] on every side, centred.
  factory _RasterBox.fit(Size size, EdgeBlendRaster raster, double margin) {
    final avail = Size(
      max(0, size.width - 2 * margin),
      max(0, size.height - 2 * margin),
    );
    final scale = min(avail.width / raster.h, avail.height / raster.v);
    final w = raster.h * scale;
    final h = raster.v * scale;
    final rect = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );
    return _RasterBox(rect, raster);
  }

  final Rect rect;
  final EdgeBlendRaster raster;

  double _scale(BlendEdge e) =>
      e.isHorizontal ? rect.width / raster.h : rect.height / raster.v;

  /// Screen x (Left / Right) or y (Upper / Lower) of the line [units] in
  /// from [e].
  double lineAt(BlendEdge e, num units) => switch (e) {
    BlendEdge.left => rect.left + units * _scale(e),
    BlendEdge.right => rect.right - units * _scale(e),
    BlendEdge.upper => rect.top + units * _scale(e),
    BlendEdge.lower => rect.bottom - units * _scale(e),
  };

  /// How far [p] lies in from [e], in raster units.
  double inward(BlendEdge e, Offset p) => switch (e) {
    BlendEdge.left => (p.dx - rect.left) / _scale(e),
    BlendEdge.right => (rect.right - p.dx) / _scale(e),
    BlendEdge.upper => (p.dy - rect.top) / _scale(e),
    BlendEdge.lower => (rect.bottom - p.dy) / _scale(e),
  };

  /// The full-length band between the lines [from] and [to] units in.
  Rect band(BlendEdge e, num from, num to) {
    final a = lineAt(e, from);
    final b = lineAt(e, to);
    return e.isHorizontal
        ? Rect.fromLTRB(min(a, b), rect.top, max(a, b), rect.bottom)
        : Rect.fromLTRB(rect.left, min(a, b), rect.right, max(a, b));
  }

  Rect zone(BlendEdge e, EdgeSettings s) => band(e, s.start, s.start + s.width);

  /// The band from the raster edge to [depth] units in (everything a blend
  /// edge darkens, or a black border), widened to at least [minThickness]
  /// px so a narrow one can still be clicked.
  Rect bandHitRect(BlendEdge e, num depth, double minThickness) {
    final z = band(e, 0, depth);
    final grow = max(
      0.0,
      (minThickness - (e.isHorizontal ? z.width : z.height)) / 2,
    );
    return e.isHorizontal
        ? Rect.fromLTRB(z.left - grow, z.top, z.right + grow, z.bottom)
        : Rect.fromLTRB(z.left, z.top - grow, z.right, z.bottom + grow);
  }

  /// The midpoint of the line [units] in from [e].
  Offset handleAt(BlendEdge e, num units) {
    final line = lineAt(e, units);
    return e.isHorizontal
        ? Offset(line, rect.center.dy)
        : Offset(rect.center.dx, line);
  }
}

/// How far in from [edge] the line [part]'s handle sits on: Start, the zone
/// end (Start + Width), or the black border width.
int _handleUnits(
  EdgeBlendState state,
  BlackLevelState? black,
  BlendEdge edge,
  EdgePart part,
) => switch (part) {
  EdgePart.start => state[edge].start,
  EdgePart.width => state[edge].start + state[edge].width,
  EdgePart.border => black!.borderWidth(edge),
};

/// The level's channels as a swatch colour; Interlocked shows W as grey.
Color _levelColor(RgbwLevel level) => Color.fromARGB(
  255,
  level.shown(RgbwChannel.r),
  level.shown(RgbwChannel.g),
  level.shown(RgbwChannel.b),
);

class _EdgeBlendPainter extends CustomPainter {
  _EdgeBlendPainter({
    required this.box,
    required this.state,
    required this.black,
    required this.interactive,
    required this.selection,
    required this.hoverEdge,
    required this.dragging,
    required this.raster,
    required this.outline,
    required this.startColor,
    required this.endColor,
    required this.idleZone,
  });

  final _RasterBox box;
  final EdgeBlendState state;
  final BlackLevelState? black;
  final bool interactive;
  final EdgePick? selection;
  final BlendEdge? hoverEdge;
  final EdgePick? dragging;
  final Color raster;
  final Color outline;
  final Color startColor;
  final Color endColor;
  final Color idleZone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = box.rect;
    canvas.drawRect(rect, Paint()..color = raster);

    final black = this.black;
    if (black != null) {
      _paintBlack(canvas, black);
    } else {
      for (final edge in BlendEdge.values) {
        final s = state[edge];
        if (s.enabled) {
          _paintZone(canvas, edge, s);
        } else if (s.width > 0) {
          _dashedRect(
            canvas,
            box.zone(edge, s),
            Paint()
              ..color = idleZone
              ..strokeWidth = 1.5,
          );
        }
      }
    }

    final hover = hoverEdge;
    if (hover != null) {
      final depth = black != null
          ? black.borderWidth(hover)
          : state[hover].start + state[hover].width;
      canvas.drawRect(
        box.bandHitRect(hover, depth, 4),
        Paint()
          ..color = startColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke,
    );

    if (!interactive) return;
    for (final edge in BlendEdge.values) {
      if (black != null) {
        _paintHandle(canvas, edge, EdgePart.border);
      } else if (state[edge].enabled) {
        // Width after Start: drawn on top, as it wins the hit test.
        _paintHandle(canvas, edge, EdgePart.start);
        _paintHandle(canvas, edge, EdgePart.width);
      }
    }
    final drag = dragging;
    if (drag != null) _paintValueChip(canvas, drag.edge, drag.part);
  }

  /// Overlapped zones filled with their level's colour, then the black
  /// border bands in the border level's colour, hatched.
  void _paintBlack(Canvas canvas, BlackLevelState black) {
    for (final edge in BlendEdge.values) {
      final s = state[edge];
      if (!s.enabled || s.width == 0) continue;
      final zone = box.zone(edge, s);
      final level = black[LevelSlot.overlap(edge)];
      canvas.drawRect(
        zone,
        Paint()..color = _levelColor(level).withValues(alpha: 0.85),
      );
      _dashedRect(
        canvas,
        zone,
        Paint()
          ..color = idleZone
          ..strokeWidth = 1,
      );
    }

    final borderFill = _levelColor(black[LevelSlot.border]);
    final hatch = Paint()
      ..color = outline
      ..strokeWidth = 1;
    for (final edge in BlendEdge.values) {
      final depth = black.borderWidth(edge);
      if (depth == 0) continue;
      final band = box.band(edge, 0, depth);
      canvas.drawRect(band, Paint()..color = borderFill);
      _hatch(canvas, band, hatch);
      _line(
        canvas,
        edge,
        box.lineAt(edge, depth),
        Paint()
          ..color = startColor
          ..strokeWidth = selection?.edge == edge ? 2.5 : 2.0,
      );
    }
  }

  /// Solid dark from the raster edge to Start, then fading out at
  /// Start + Width, as the projector darkens towards its own edge.
  void _paintZone(Canvas canvas, BlendEdge edge, EdgeSettings s) {
    const dark = Color(0xD9000000); // black at 85 %
    if (s.start > 0) {
      canvas.drawRect(box.band(edge, 0, s.start), Paint()..color = dark);
    }
    final zone = box.zone(edge, s);
    final a = box.lineAt(edge, s.start);
    final b = box.lineAt(edge, s.start + s.width);
    final from = edge.isHorizontal
        ? Offset(a, zone.center.dy)
        : Offset(zone.center.dx, a);
    final to = edge.isHorizontal
        ? Offset(b, zone.center.dy)
        : Offset(zone.center.dx, b);
    if (s.width > 0) {
      canvas.drawRect(
        zone,
        Paint()
          ..shader = ui.Gradient.linear(from, to, [
            dark,
            dark.withValues(alpha: 0),
          ]),
      );
    }
    final selected = selection?.edge == edge;
    final width = selected ? 2.5 : 2.0;
    _line(
      canvas,
      edge,
      a,
      Paint()
        ..color = startColor
        ..strokeWidth = width,
    );
    _dashedLine(
      canvas,
      edge,
      b,
      Paint()
        ..color = endColor
        ..strokeWidth = width,
    );
  }

  void _paintHandle(Canvas canvas, BlendEdge edge, EdgePart part) {
    final sel = selection;
    final center = box.handleAt(edge, _handleUnits(state, black, edge, part));
    final selectedEdge = sel?.edge == edge;
    final active = selectedEdge && sel?.part == part;
    final r = selectedEdge ? 8.0 : 7.0;
    if (active) {
      canvas.drawCircle(
        center,
        r + 5,
        Paint()..color = startColor.withValues(alpha: 0.24),
      );
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()..color = part == EdgePart.width ? endColor : startColor,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedEdge ? 3 : 2,
    );
  }

  void _paintValueChip(Canvas canvas, BlendEdge edge, EdgePart part) {
    final units = _handleUnits(state, black, edge, part);
    final label = switch (part) {
      EdgePart.start => 'Start ${state[edge].start}',
      EdgePart.width => 'Width ${state[edge].width}',
      EdgePart.border => 'Border $units',
    };
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final handle = box.handleAt(edge, units);
    const pad = EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    final chipSize = Size(
      text.width + pad.horizontal,
      text.height + pad.vertical,
    );
    // Beside the handle on the zone's inner side, kept inside the raster.
    final inwardOffset = switch (edge) {
      BlendEdge.left => const Offset(14, -8),
      BlendEdge.right => Offset(-14 - chipSize.width, -8),
      BlendEdge.upper => Offset(-chipSize.width / 2, 12),
      BlendEdge.lower => Offset(-chipSize.width / 2, -12 - chipSize.height),
    };
    var topLeft = handle + inwardOffset;
    final r = box.rect;
    topLeft = Offset(
      topLeft.dx.clamp(r.left, max(r.left, r.right - chipSize.width)),
      topLeft.dy.clamp(r.top, max(r.top, r.bottom - chipSize.height)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topLeft & chipSize, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    text.paint(canvas, topLeft + Offset(pad.left, pad.top));
  }

  void _line(Canvas canvas, BlendEdge edge, double at, Paint paint) {
    final r = box.rect;
    edge.isHorizontal
        ? canvas.drawLine(Offset(at, r.top), Offset(at, r.bottom), paint)
        : canvas.drawLine(Offset(r.left, at), Offset(r.right, at), paint);
  }

  void _dashedLine(Canvas canvas, BlendEdge edge, double at, Paint paint) {
    final r = box.rect;
    edge.isHorizontal
        ? _dashes(canvas, Offset(at, r.top), Offset(at, r.bottom), paint)
        : _dashes(canvas, Offset(r.left, at), Offset(r.right, at), paint);
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) {
    _dashes(canvas, r.topLeft, r.topRight, paint);
    _dashes(canvas, r.topRight, r.bottomRight, paint);
    _dashes(canvas, r.bottomRight, r.bottomLeft, paint);
    _dashes(canvas, r.bottomLeft, r.topLeft, paint);
  }

  static void _dashes(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final length = (b - a).distance;
    if (length == 0) return;
    final dir = (b - a) / length;
    for (var d = 0.0; d < length; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * min(d + dash, length), paint);
    }
  }

  static void _hatch(Canvas canvas, Rect r, Paint paint) {
    const gap = 8.0;
    canvas
      ..save()
      ..clipRect(r);
    for (var x = r.left - r.height; x < r.right; x += gap) {
      canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgeBlendPainter old) =>
      old.box.rect != box.rect ||
      old.state != state ||
      old.black != black ||
      old.interactive != interactive ||
      old.selection != selection ||
      old.hoverEdge != hoverEdge ||
      old.dragging != dragging ||
      old.raster != raster ||
      old.outline != outline ||
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.idleZone != idleZone;
}
