import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart'
    show DragStartBehavior, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/edge_blend_pair.dart';
import '../../../domain/projector_node.dart';
import '../common/key_hold_repeater.dart';
import '../custom_tooltip.dart';
import 'black_level_state.dart';
import 'edge_blend_state.dart';

typedef EdgePick = ({BlendEdge edge, EdgePart part});

/// The edge picked on the canvas or in the panel, on projector [side]:
/// arrows act on its [part], Esc clears it.
typedef EdgeSelection = ({int side, BlendEdge edge, EdgePart part});

/// One projector as the canvas draws it. [state] is null until it has
/// loaded; the raster is then a placeholder labelled [status].
@immutable
class BlendCanvasSide {
  const BlendCanvasSide({
    required this.node,
    required this.raster,
    this.state,
    this.black,
    this.status = '',
  });

  final ProjectorNode node;
  final EdgeBlendRaster raster;
  final EdgeBlendState? state;

  /// Null until this projector's Black Level values have loaded.
  final BlackLevelState? black;
  final String status;
}

/// The projector raster with each edge's blend zone: drag the Start / Width
/// handles, arrows (Shift ×10) nudge the selected one. One paint pass and one
/// gesture detector with its own hit-testing, so a drag repaints nothing but
/// this canvas' layer.
///
/// With [blackTab] it's the Black Level tab's canvas instead: overlapped
/// zones in their level's colour, hatched black border bands, and one
/// handle per edge that moves the border width ([EdgePart.border]).
///
/// Two [sides] are pair mode (plan §9): both rasters on one fixed scale,
/// overlapping by the facing edges' Start + Width + Start so the two ramps
/// land on the same pixels; the [active] one is drawn normally, the other
/// dimmed on top of it, and a pill by each raster switches between them.
class EdgeBlendCanvas extends StatefulWidget {
  const EdgeBlendCanvas({
    super.key,
    required this.sides,
    this.active = 0,
    this.arrangement = PairArrangement.sideBySide,
    this.blackTab = false,
    required this.selection,
    this.maxFor,
    this.onActivate,
    required this.onSelect,
    required this.onClearSelection,
    required this.onPreview,
    required this.onCommit,
    required this.onResetEdge,
  }) : assert(sides.length == 1 || sides.length == 2);

  final List<BlendCanvasSide> sides;
  final int active;
  final PairArrangement arrangement;
  final bool blackTab;
  final EdgeSelection? selection;

  /// The limit a drag or arrow stops at; defaults to the side's own §8
  /// limit (a linked Width also has to fit the other projector).
  final int Function(int side, BlendEdge edge, EdgePart part)? maxFor;
  final ValueChanged<int>? onActivate;
  final void Function(int side, BlendEdge edge, EdgePart part) onSelect;
  final VoidCallback onClearSelection;
  final void Function(int side, BlendEdge edge, EdgePart part, int v) onPreview;
  final void Function(int side, BlendEdge edge, EdgePart part) onCommit;
  final void Function(int side, BlendEdge edge) onResetEdge;

  @override
  State<EdgeBlendCanvas> createState() => _EdgeBlendCanvasState();
}

class _EdgeBlendCanvasState extends State<EdgeBlendCanvas> {
  // Room around the raster for handles and value chips on the outer edges.
  static const double _margin = 16;
  static const double _handleHitRadius = 12;
  static const double _minZoneHitThickness = 10;

  // Pair mode keeps the pills outside the rasters: a band above them side
  // by side, to their left stacked.
  static const double _pillBandTop = 36;
  static const double _pillBandLeft = 132;
  static const double _pillGap = 6;

  final _focusNode = FocusNode();
  late final _keys = KeyHoldRepeater(
    onStep: _onKeyStep,
    onRelease: () {
      final target = _keyTarget;
      if (target != null) {
        widget.onCommit(target.side, target.edge, target.part);
      }
      _keyTarget = null;
    },
  );

  List<_RasterBox> _boxes = const [];
  EdgeSelection? _hover;
  bool _hoverOnHandle = false;

  /// The box is the one at drag start: a facing Start or the wider facing
  /// Width moves both rasters while it's dragged, and measuring against
  /// the moving box would feed that back into the value. So the value
  /// follows the pointer, and the handle moves half as far.
  ({EdgeSelection pick, int v0, double in0, _RasterBox box})? _drag;
  EdgeSelection? _keyTarget;

  // Manual double-click tracking, as in the Corner canvas: onDoubleTap
  // would delay every single click by kDoubleTapTimeout.
  EdgeSelection? _lastTapped;
  DateTime? _lastTapTime;

  @override
  void didUpdateWidget(EdgeBlendCanvas old) {
    super.didUpdateWidget(old);
    // Esc or a click elsewhere while an arrow is held: its key-up may never
    // reach us as a step for this edge, so end the hold (and send) now.
    // onCommit only queues the write, nothing rebuilds during this build.
    final target = _keyTarget;
    if (widget.selection != old.selection ||
        (target != null && !_editable(target.side))) {
      _keys.release();
    }
    final hover = _hover;
    if (hover != null && !_editable(hover.side)) _hover = null;
  }

  @override
  void dispose() {
    _keys.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _pair => widget.sides.length == 2;

  /// Loaded, not Off and, on Black Level, with that tab's values: its
  /// zones and handles take clicks, drags and keys.
  bool _editable(int side) {
    if (side >= widget.sides.length) return false;
    final s = widget.sides[side];
    final state = s.state;
    return state != null &&
        state.mode != EdgeBlendMode.off &&
        (!widget.blackTab || s.black != null);
  }

  /// A disabled edge's blend handles are hidden; its border width is still
  /// accepted by the projector (§8), so the border handle never is.
  bool _hasHandles(int side, BlendEdge edge) =>
      _editable(side) &&
      (widget.blackTab || widget.sides[side].state![edge].enabled);

  int _valueOf(int side, BlendEdge edge, EdgePart part) {
    final s = widget.sides[side];
    return part == EdgePart.border
        ? s.black!.borderWidth(edge)
        : s.state![edge].valueOf(part);
  }

  /// The active projector first: its handles are drawn on top, so they win
  /// where the two overlap.
  List<int> get _hitOrder => [
    widget.active,
    for (var i = 0; i < widget.sides.length; i++)
      if (i != widget.active) i,
  ];

  // ─── Layout ──────────────────────────────────────────────────────────────
  List<_RasterBox> _layout(Size size) {
    if (!_pair) {
      final raster = widget.sides.single.raster;
      return [_RasterBox.fit(size, raster, _margin)];
    }
    final a = widget.sides[0];
    final b = widget.sides[1];
    final arrangement = widget.arrangement;
    final sideBySide = arrangement == PairArrangement.sideBySide;
    final bandTop = sideBySide ? _pillBandTop : 0.0;
    final bandLeft = sideBySide ? 0.0 : _pillBandLeft;
    final availW = max(0.0, size.width - 2 * _margin - bandLeft);
    final availH = max(0.0, size.height - 2 * _margin - bandTop);
    // Every supported raster is 16:10; both are drawn the same size, each
    // mapping its own units.
    final aspect = a.raster.v / a.raster.h;
    final extent = pairExtent(arrangement);
    final unitW = min(availW / extent.h, availH / (extent.v * aspect));
    final unitH = unitW * aspect;
    final origin = Rect.fromLTWH(
      _margin + bandLeft + (availW - extent.h * unitW) / 2,
      _margin + bandTop + (availH - extent.v * unitH) / 2,
      unitW,
      unitH,
    );
    FacingEdge? facing(BlendCanvasSide s, BlendEdge edge) {
      final e = s.state?[edge];
      return e == null
          ? null
          : (
              enabled: e.enabled,
              start: e.start,
              width: e.width,
              span: edgeBlendSpan(s.raster, edge),
            );
    }

    final fa = facing(a, arrangement.facingA);
    final fb = facing(b, arrangement.facingB);
    // Until both have loaded there is no overlap to show: they just touch.
    final pos = pairPositions(
      fa == null || fb == null ? 0 : pairOverlap(fa, fb),
    );
    Rect at(double p) =>
        origin.shift(sideBySide ? Offset(p * unitW, 0) : Offset(0, p * unitH));
    return [_RasterBox(at(pos.a), a.raster), _RasterBox(at(pos.b), b.raster)];
  }

  // ─── Hit-testing ─────────────────────────────────────────────────────────
  /// A handle (part set) beats a zone (part null); null = empty space.
  ({int side, BlendEdge edge, EdgePart? part})? _hitTest(Offset p) {
    for (final i in _hitOrder) {
      if (!_editable(i)) continue;
      final s = widget.sides[i];
      final box = _boxes[i];
      EdgePick? nearest;
      var nearestDist = _handleHitRadius;
      for (final edge in BlendEdge.values) {
        if (!_hasHandles(i, edge)) continue;
        double dist(EdgePart part) =>
            (box.handleAt(edge, _handleUnits(s.state!, s.black, edge, part)) -
                    p)
                .distance;
        final EdgePart part;
        final double d;
        if (widget.blackTab) {
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
      if (nearest != null) {
        return (side: i, edge: nearest.edge, part: nearest.part);
      }
    }

    for (final i in _hitOrder) {
      if (!_editable(i)) continue;
      final s = widget.sides[i];
      for (final edge in BlendEdge.values) {
        final depth = _zoneDepth(s, edge);
        if (_boxes[i]
            .bandHitRect(edge, depth, _minZoneHitThickness)
            .contains(p)) {
          return (side: i, edge: edge, part: null);
        }
      }
    }
    return null;
  }

  /// Everything a click on [edge] covers: the band a blend edge darkens,
  /// or the black border.
  int _zoneDepth(BlendCanvasSide s, BlendEdge edge) => widget.blackTab
      ? s.black!.borderWidth(edge)
      : s.state![edge].start + s.state![edge].width;

  void _updateHover(Offset p) {
    final hit = _hitTest(p);
    final next = hit == null
        ? null
        : (side: hit.side, edge: hit.edge, part: hit.part ?? EdgePart.start);
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
        hit.side,
        hit.edge,
        widget.blackTab
            ? EdgePart.border
            : sel != null && sel.side == hit.side && sel.edge == hit.edge
            ? sel.part
            : EdgePart.start,
      );
      return;
    }
    final pick = (side: hit.side, edge: hit.edge, part: part);
    final now = DateTime.now();
    final isDouble =
        _lastTapped == pick &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= kDoubleTapTimeout;
    _lastTapped = pick;
    _lastTapTime = now;
    widget.onSelect(pick.side, pick.edge, pick.part);
    if (isDouble) widget.onResetEdge(pick.side, pick.edge);
  }

  void _onPanStart(DragStartDetails details) {
    final hit = _hitTest(details.localPosition);
    final part = hit?.part;
    if (hit == null || part == null) return;
    _focusNode.requestFocus();
    widget.onSelect(hit.side, hit.edge, part);
    final box = _boxes[hit.side];
    setState(() {
      _drag = (
        pick: (side: hit.side, edge: hit.edge, part: part),
        v0: _valueOf(hit.side, hit.edge, part),
        in0: box.inward(hit.edge, details.localPosition),
        box: box,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final drag = _drag;
    if (drag == null) return;
    final pick = drag.pick;
    final moved = drag.box.inward(pick.edge, details.localPosition) - drag.in0;
    _preview(pick.side, pick.edge, pick.part, (drag.v0 + moved).round());
  }

  void _onPanEnd() {
    final drag = _drag;
    if (drag == null) return;
    setState(() => _drag = null);
    widget.onCommit(drag.pick.side, drag.pick.edge, drag.pick.part);
  }

  void _preview(int side, BlendEdge edge, EdgePart part, int v) {
    final s = widget.sides[side];
    final max =
        widget.maxFor?.call(side, edge, part) ??
        s.state!.maxFor(edge, part, s.raster);
    final clamped = v.clamp(0, max);
    if (clamped != _valueOf(side, edge, part)) {
      widget.onPreview(side, edge, part, clamped);
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
    final current = _valueOf(target.side, target.edge, target.part);
    _preview(target.side, target.edge, target.part, current + sign * step);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // The held key's release ends the hold whatever is selected by then.
    if (event is KeyUpEvent && event.logicalKey == _keys.held) {
      _keys.release();
      return KeyEventResult.handled;
    }
    final sel = widget.selection;
    if (sel == null ||
        !_hasHandles(sel.side, sel.edge) ||
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
    final colors = (
      raster: scheme.surfaceContainerHighest,
      outline: scheme.outline,
      start: scheme.primary,
      end: scheme.tertiary,
      idle: scheme.outlineVariant,
      text: scheme.onSurfaceVariant,
    );
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
            final size = constraints.biggest;
            final boxes = _layout(size);
            _boxes = boxes;
            final drag = _drag?.pick;
            final sel = widget.selection;
            final hover = _hover;
            final canvas = MouseRegion(
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
                  size: size,
                  painter: _EdgeBlendPainter(
                    sides: [
                      for (var i = 0; i < widget.sides.length; i++)
                        (
                          box: boxes[i],
                          state: widget.sides[i].state,
                          black: widget.blackTab ? widget.sides[i].black : null,
                          status: widget.sides[i].status,
                          editable: _editable(i),
                          selection: sel != null && sel.side == i
                              ? (edge: sel.edge, part: sel.part)
                              : null,
                          hoverEdge: hover != null && hover.side == i
                              ? hover.edge
                              : null,
                          dragging: drag != null && drag.side == i
                              ? (edge: drag.edge, part: drag.part)
                              : null,
                        ),
                    ],
                    active: widget.active,
                    blackTab: widget.blackTab,
                    colors: colors,
                  ),
                ),
              ),
            );
            if (!_pair) return canvas;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: ClipRect(child: canvas)),
                for (var i = 0; i < 2; i++) _pill(i, boxes[i].rect, size),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Side by side: above A's left corner and B's right one; stacked: left of
  /// A's top and B's bottom. Opposite corners, so the two never collide.
  Widget _pill(int i, Rect rect, Size size) {
    final pill = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _pillBandLeft - 2 * _pillGap),
      child: _ProjectorPill(
        node: widget.sides[i].node,
        active: i == widget.active,
        onTap: () => widget.onActivate?.call(i),
      ),
    );
    final first = i == 0;
    return switch (widget.arrangement) {
      PairArrangement.sideBySide => Positioned(
        left: first ? rect.left : null,
        right: first ? null : size.width - rect.right,
        bottom: size.height - rect.top + _pillGap,
        child: pill,
      ),
      PairArrangement.stacked => Positioned(
        right: size.width - rect.left + _pillGap,
        top: first ? rect.top : null,
        bottom: first ? null : size.height - rect.bottom,
        child: pill,
      ),
    };
  }
}

/// Picks the active projector in a pair. Filled with a primary outline when
/// active, outlined otherwise.
class _ProjectorPill extends StatelessWidget {
  const _ProjectorPill({
    required this.node,
    required this.active,
    required this.onTap,
  });

  final ProjectorNode node;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomTooltip(
      message: '${node.name}, ${node.ipAddress}',
      child: ChoiceChip(
        label: Text(node.name, overflow: TextOverflow.ellipsis),
        selected: active,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: active ? scheme.primary : scheme.outline),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// The raster's on-screen rectangle and the unit ↔ pixel mapping.
@immutable
class _RasterBox {
  const _RasterBox(this.rect, this.raster);

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

  @override
  bool operator ==(Object other) =>
      other is _RasterBox && other.rect == rect && other.raster == raster;

  @override
  int get hashCode => Object.hash(rect, raster);
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

/// One projector's share of a paint pass. [black] is null on the Edge
/// Blending tab, and on Black Level until that projector's values load.
typedef _PaintSide = ({
  _RasterBox box,
  EdgeBlendState? state,
  BlackLevelState? black,
  String status,
  bool editable,
  EdgePick? selection,
  BlendEdge? hoverEdge,
  EdgePick? dragging,
});

typedef _CanvasColors = ({
  Color raster,
  Color outline,
  Color start,
  Color end,
  Color idle,
  Color text,
});

class _EdgeBlendPainter extends CustomPainter {
  _EdgeBlendPainter({
    required this.sides,
    required this.active,
    required this.blackTab,
    required this.colors,
  });

  final List<_PaintSide> sides;
  final int active;
  final bool blackTab;
  final _CanvasColors colors;

  /// How much of the inactive projector shows through, drawn over the
  /// active one so the shared zone reads as both.
  static const double _inactiveOpacity = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final main = sides[active];
    _paintBody(canvas, main);
    for (var i = 0; i < sides.length; i++) {
      if (i == active) continue;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, _inactiveOpacity),
      );
      _paintBody(canvas, sides[i]);
      _paintHandles(canvas, sides[i]);
      canvas.restore();
    }
    _paintHandles(canvas, main);
    for (final side in sides) {
      final drag = side.dragging;
      if (drag != null) _paintValueChip(canvas, side, drag.edge, drag.part);
    }
  }

  void _paintBody(Canvas canvas, _PaintSide side) {
    final box = side.box;
    final rect = box.rect;
    canvas.drawRect(rect, Paint()..color = colors.raster);

    final state = side.state;
    if (state == null) {
      _paintStatus(canvas, rect, side.status);
    } else {
      final black = side.black;
      if (black != null) {
        _paintBlack(canvas, side, state, black);
      } else {
        for (final edge in BlendEdge.values) {
          final s = state[edge];
          // On Black Level before its values load, zones are outlines only.
          if (s.enabled && !blackTab) {
            _paintZone(canvas, side, edge, s);
          } else if (s.width > 0) {
            _dashedRect(
              canvas,
              box.zone(edge, s),
              Paint()
                ..color = colors.idle
                ..strokeWidth = 1.5,
            );
          }
        }
      }

      final hover = side.hoverEdge;
      if (hover != null) {
        final depth = black != null
            ? black.borderWidth(hover)
            : state[hover].start + state[hover].width;
        canvas.drawRect(
          box.bandHitRect(hover, depth, 4),
          Paint()
            ..color = colors.start.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    canvas.drawRect(
      rect,
      Paint()
        ..color = colors.outline
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintStatus(Canvas canvas, Rect rect, String status) {
    final text = TextPainter(
      text: TextSpan(
        text: status,
        style: TextStyle(color: colors.text, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    text.paint(canvas, rect.center - Offset(text.width / 2, text.height / 2));
  }

  void _paintHandles(Canvas canvas, _PaintSide side) {
    final state = side.state;
    if (!side.editable || state == null) return;
    final black = side.black;
    for (final edge in BlendEdge.values) {
      if (blackTab) {
        if (black != null) _paintHandle(canvas, side, edge, EdgePart.border);
      } else if (state[edge].enabled) {
        // Width after Start: drawn on top, as it wins the hit test.
        _paintHandle(canvas, side, edge, EdgePart.start);
        _paintHandle(canvas, side, edge, EdgePart.width);
      }
    }
  }

  /// Overlapped zones filled with their level's colour, then the black
  /// border bands in the border level's colour, hatched.
  void _paintBlack(
    Canvas canvas,
    _PaintSide side,
    EdgeBlendState state,
    BlackLevelState black,
  ) {
    final box = side.box;
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
          ..color = colors.idle
          ..strokeWidth = 1,
      );
    }

    final borderFill = _levelColor(black[LevelSlot.border]);
    final hatch = Paint()
      ..color = colors.outline
      ..strokeWidth = 1;
    for (final edge in BlendEdge.values) {
      final depth = black.borderWidth(edge);
      if (depth == 0) continue;
      final band = box.band(edge, 0, depth);
      canvas.drawRect(band, Paint()..color = borderFill);
      _hatch(canvas, band, hatch);
      _line(
        canvas,
        box,
        edge,
        box.lineAt(edge, depth),
        Paint()
          ..color = colors.start
          ..strokeWidth = side.selection?.edge == edge ? 2.5 : 2.0,
      );
    }
  }

  /// Solid dark from the raster edge to Start, then fading out at
  /// Start + Width, as the projector darkens towards its own edge.
  void _paintZone(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgeSettings s,
  ) {
    const dark = Color(0xD9000000); // black at 85 %
    final box = side.box;
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
    final selected = side.selection?.edge == edge;
    final width = selected ? 2.5 : 2.0;
    _line(
      canvas,
      box,
      edge,
      a,
      Paint()
        ..color = colors.start
        ..strokeWidth = width,
    );
    _dashedLine(
      canvas,
      box,
      edge,
      b,
      Paint()
        ..color = colors.end
        ..strokeWidth = width,
    );
  }

  void _paintHandle(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgePart part,
  ) {
    final sel = side.selection;
    final center = side.box.handleAt(
      edge,
      _handleUnits(side.state!, side.black, edge, part),
    );
    final selectedEdge = sel?.edge == edge;
    final active = selectedEdge && sel?.part == part;
    final r = selectedEdge ? 8.0 : 7.0;
    if (active) {
      canvas.drawCircle(
        center,
        r + 5,
        Paint()..color = colors.start.withValues(alpha: 0.24),
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
      Paint()..color = part == EdgePart.width ? colors.end : colors.start,
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

  void _paintValueChip(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgePart part,
  ) {
    final state = side.state!;
    final units = _handleUnits(state, side.black, edge, part);
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
    final handle = side.box.handleAt(edge, units);
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
    final r = side.box.rect;
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

  static void _line(
    Canvas canvas,
    _RasterBox box,
    BlendEdge edge,
    double at,
    Paint paint,
  ) {
    final r = box.rect;
    edge.isHorizontal
        ? canvas.drawLine(Offset(at, r.top), Offset(at, r.bottom), paint)
        : canvas.drawLine(Offset(r.left, at), Offset(r.right, at), paint);
  }

  static void _dashedLine(
    Canvas canvas,
    _RasterBox box,
    BlendEdge edge,
    double at,
    Paint paint,
  ) {
    final r = box.rect;
    edge.isHorizontal
        ? _dashes(canvas, Offset(at, r.top), Offset(at, r.bottom), paint)
        : _dashes(canvas, Offset(r.left, at), Offset(r.right, at), paint);
  }

  static void _dashedRect(Canvas canvas, Rect r, Paint paint) {
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
      !_sameSides(old.sides, sides) ||
      old.active != active ||
      old.blackTab != blackTab ||
      old.colors != colors;

  static bool _sameSides(List<_PaintSide> a, List<_PaintSide> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
