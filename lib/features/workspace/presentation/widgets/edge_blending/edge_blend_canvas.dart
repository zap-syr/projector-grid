import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart'
    show DragStartBehavior, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/black_level_zones.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/edge_blend_values.dart';
import '../../../domain/edge_blend_pair.dart';
import '../../../domain/edge_blend_labels.dart';
import '../../../domain/projector_node.dart';
import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';
import '../common/key_hold_repeater.dart';
import '../custom_tooltip.dart';
import '../dialog_title_bar.dart';
import 'black_level_state.dart';
import 'edge_blend_parts.dart';
import 'edge_blend_state.dart';

typedef EdgePick = ({BlendEdge edge, EdgePart part});

/// The edge picked on the canvas or in the panel, on projector [side]:
/// arrows act on its [part], Esc clears it.
typedef EdgeSelection = ({int side, BlendEdge edge, EdgePart part});

/// One projector as the canvas draws it. [state] is null until it has
/// loaded; the raster is then a placeholder labelled [status], or, when it
/// never answered ([unreachable]), a dashed placeholder with *No reply* and
/// [onRetry], in its place so nothing jumps when it answers.
@immutable
class BlendCanvasSide {
  const BlendCanvasSide({
    required this.node,
    required this.raster,
    this.state,
    this.black,
    this.status = '',
    this.unreachable = false,
    this.onRetry,
  });

  final ProjectorNode node;
  final EdgeBlendRaster raster;
  final EdgeBlendState? state;

  /// Null until this projector's Black Level values have loaded.
  final BlackLevelState? black;
  final String status;
  final bool unreachable;
  final VoidCallback? onRetry;
}

/// The projector raster with each edge's blend zone: drag the Start / Width
/// handles, arrows (Shift ×10) nudge the selected one. One paint pass and one
/// gesture detector with its own hit-testing, so a drag repaints nothing but
/// this canvas' layer.
///
/// With [blackTab] it's the Black Level tab's canvas instead: each level
/// drawn where the projector applies it (§8 "Black level zones"), and one
/// handle per edge on its border line that moves the border width
/// ([EdgePart.border]).
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
    this.linked = false,
    this.compact = false,
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

  /// A pair's Link applies: a *Linked* pill between the rasters.
  final bool linked;

  /// A narrow canvas: the pair pills show the letter only, the IP goes
  /// into their tooltip.
  final bool compact;
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
  // Wider at the sides: a left or right handle's chip is centred above it,
  // so at the raster's edge half a chip (`Border 3840`) hangs outside.
  static const _margin = EdgeInsets.symmetric(horizontal: 56, vertical: 16);
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

  /// A pair's overlap, once both projectors have loaded.
  ({int px, int percent})? _readout;
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

  /// A disabled edge has no handles on either tab: the projector accepts its
  /// border width, but a disabled edge has no border band (§8).
  bool _hasHandles(int side, BlendEdge edge) =>
      _editable(side) && widget.sides[side].state![edge].enabled;

  int _valueOf(int side, BlendEdge edge, EdgePart part) =>
      widget.sides[side].state![edge].valueOf(part);

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
    final availW = max(0.0, size.width - _margin.horizontal - bandLeft);
    final availH = max(0.0, size.height - _margin.vertical - bandTop);
    // Every supported raster is 16:10; both are drawn the same size, each
    // mapping its own units.
    final aspect = a.raster.v / a.raster.h;
    final extent = pairExtent(arrangement);
    final unitW = min(availW / extent.h, availH / (extent.v * aspect));
    final unitH = unitW * aspect;
    final origin = Rect.fromLTWH(
      _margin.left + bandLeft + (availW - extent.h * unitW) / 2,
      _margin.top + bandTop + (availH - extent.v * unitH) / 2,
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
    _readout = fa == null || fb == null ? null : pairOverlapReadout(fa, fb);
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
            (box.handleAt(edge, _handleUnits(s.state!, edge, part)) - p)
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
  /// or on Black Level everything up to the border line.
  int _zoneDepth(BlendCanvasSide s, BlendEdge edge) =>
      widget.blackTab ? s.state![edge].line : s.state![edge].end;

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
    final status = AppStatusColors.of(context);
    final t = AppText.of(context);
    final colors = (
      raster: scheme.surfaceContainerHighest,
      outline: scheme.outline,
      start: status.warning,
      startContainer: status.warningContainer,
      width: scheme.primary,
      widthContainer: scheme.primaryContainer,
      onWidthContainer: scheme.onPrimaryContainer,
      border: scheme.onSurfaceVariant,
      borderSelected: scheme.onSurface,
      borderContainer: scheme.surfaceContainerHigh,
      idle: scheme.outlineVariant,
      error: scheme.error,
      handleFill: scheme.surfaceContainer,
      halo: scheme.surface,
      text: t.caption,
      value: t.caption.copyWith(fontWeight: FontWeight.w600, height: 1.2),
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
                          unreachable: widget.sides[i].unreachable,
                          inactive: _pair && i != widget.active,
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
            final placeholders = [
              for (var i = 0; i < widget.sides.length; i++)
                if (widget.sides[i] case BlendCanvasSide(
                  unreachable: true,
                  :final onRetry?,
                ))
                  Positioned.fromRect(
                    rect: boxes[i].rect,
                    child: NoReplyView(
                      title: 'No reply',
                      detail: _pair
                          ? '${sideLetter(i)} did not answer the first read'
                          : '${widget.sides[i].node.ipAddress} did not '
                                'answer the first read',
                      onRetry: onRetry,
                    ),
                  ),
            ];
            if (!_pair) {
              return Stack(
                children: [
                  Positioned.fill(child: canvas),
                  ...placeholders,
                ],
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: ClipRect(child: canvas)),
                ...placeholders,
                ..._linkAndOverlap(boxes, size),
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
    final s = widget.sides[i];
    final pill = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _pillBandLeft - 2 * _pillGap),
      child: _ProjectorPill(
        letter: sideLetter(i),
        node: s.node,
        active: i == widget.active,
        silent: s.unreachable,
        compact: widget.compact,
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

  /// The *Linked* pill between the two projector pills, and the overlap
  /// readout by the facing edges: under them side by side, left of them
  /// stacked (in the pill band).
  List<Widget> _linkAndOverlap(List<_RasterBox> boxes, Size size) {
    final a = boxes[0].rect;
    final b = boxes[1].rect;
    final readout = _readout;
    final t = AppText.of(context);
    final sideBySide = widget.arrangement == PairArrangement.sideBySide;
    // The middle of the overlap (or of the seam, when they only touch).
    final mid = sideBySide ? (a.right + b.left) / 2 : (a.bottom + b.top) / 2;
    const bandWidth = _pillBandLeft - 2 * _pillGap;
    final linked = widget.linked
        ? const _LinkedPill()
        : const SizedBox.shrink();
    final text = readout == null
        ? null
        : Text(
            pairOverlapLabel(readout),
            key: const ValueKey('edge-blend-overlap'),
            textAlign: sideBySide ? TextAlign.center : TextAlign.right,
            style: t.caption,
          );
    if (sideBySide) {
      return [
        Positioned(
          left: 0,
          right: 0,
          bottom: size.height - a.top + _pillGap,
          child: Align(
            alignment: Alignment(mid / size.width * 2 - 1, 0),
            child: linked,
          ),
        ),
        if (text != null)
          Positioned(
            left: 0,
            right: 0,
            top: max(a.bottom, b.bottom) + _pillGap,
            child: Align(
              alignment: Alignment(mid / size.width * 2 - 1, 0),
              child: text,
            ),
          ),
      ];
    }
    return [
      Positioned(
        right: size.width - a.left + _pillGap,
        width: bandWidth,
        top: 0,
        bottom: 0,
        child: Align(
          alignment: Alignment(1, mid / size.height * 2 - 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 4,
            children: [linked, ?text],
          ),
        ),
      ),
    ];
  }
}

/// Between the two projector pills while Link applies.
class _LinkedPill extends StatelessWidget {
  const _LinkedPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(
            'Linked',
            style: t.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the active projector in a pair: its letter and IP (letter only in
/// a narrow canvas), filled when active, an error dot while it doesn't
/// reply.
class _ProjectorPill extends StatelessWidget {
  const _ProjectorPill({
    required this.letter,
    required this.node,
    required this.active,
    required this.silent,
    required this.compact,
    required this.onTap,
  });

  final String letter;
  final ProjectorNode node;
  final bool active;
  final bool silent;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = active ? cs.onPrimaryContainer : t.secondary;
    return CustomTooltip(
      message: projectorLabel(node.name, node.ipAddress),
      detail: silent ? 'No reply' : null,
      child: Material(
        color: active ? cs.primaryContainer : DialogSurfaces.of(context).soft,
        shape: StadiumBorder(
          side: BorderSide(color: active ? cs.primary : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  letter,
                  style: t.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      node.ipAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.monoSmall.copyWith(color: fg, height: 1.1),
                    ),
                  ),
                ],
                if (silent) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The raster's on-screen rectangle and the unit ↔ pixel mapping.
@immutable
class _RasterBox {
  const _RasterBox(this.rect, this.raster);

  /// The largest rectangle with the raster's aspect ratio that fits [size]
  /// minus [margin], centred.
  factory _RasterBox.fit(Size size, EdgeBlendRaster raster, EdgeInsets margin) {
    final avail = Size(
      max(0, size.width - margin.horizontal),
      max(0, size.height - margin.vertical),
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
/// end (Start + Width), or the border line (the border width from the zone
/// end, §8).
int _handleUnits(EdgeBlendState state, BlendEdge edge, EdgePart part) =>
    switch (part) {
      EdgePart.start => state[edge].start,
      EdgePart.width => state[edge].end,
      EdgePart.border => state[edge].line,
    };

/// A level's R, G, B as a swatch colour (W does nothing to the image).
Color _rgbColor(Rgbw v) => Color.fromARGB(255, v.r, v.g, v.b);

/// One projector's share of a paint pass. [black] is null on the Edge
/// Blending tab, and on Black Level until that projector's values load.
typedef _PaintSide = ({
  _RasterBox box,
  EdgeBlendState? state,
  BlackLevelState? black,
  String status,
  bool unreachable,
  bool inactive,
  bool editable,
  EdgePick? selection,
  BlendEdge? hoverEdge,
  EdgePick? dragging,
});

/// Theme colours and text styles of a paint pass: Start amber, Width
/// primary, the black border neutral (owner, 2026-10-14).
typedef _CanvasColors = ({
  Color raster,
  Color outline,
  Color start,
  Color startContainer,
  Color width,
  Color widthContainer,
  Color onWidthContainer,
  Color border,
  Color borderSelected,
  Color borderContainer,
  Color idle,
  Color error,
  Color handleFill,
  Color halo,
  TextStyle text,
  TextStyle value,
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
    // The selected handle's value, or the dragged one's: a drag selects.
    for (final side in sides) {
      final pick = side.dragging ?? side.selection;
      if (pick != null && side.editable && _hasHandle(side, pick)) {
        _paintValuePill(canvas, side, pick.edge, pick.part);
      }
    }
  }

  /// Whether [pick]'s handle is drawn on this tab.
  bool _hasHandle(_PaintSide side, EdgePick pick) =>
      side.state![pick.edge].enabled &&
      (blackTab
          ? pick.part == EdgePart.border && side.black != null
          : pick.part != EdgePart.border);

  void _paintBody(Canvas canvas, _PaintSide side) {
    final box = side.box;
    final rect = box.rect;
    final state = side.state;
    if (side.unreachable && state == null) {
      // Its place, dashed in the error colour; the widget over it says
      // *No reply* and offers Retry.
      canvas.drawRect(
        rect,
        Paint()..color = colors.error.withValues(alpha: 0.06),
      );
      _dashedRect(
        canvas,
        rect,
        Paint()
          ..color = colors.error.withValues(alpha: 0.6)
          ..strokeWidth = 1.2,
      );
      return;
    }
    canvas.drawRect(rect, Paint()..color = colors.raster);

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
        final depth = black != null ? state[hover].line : state[hover].end;
        canvas.drawRect(
          box.bandHitRect(hover, depth, 4),
          Paint()
            ..color = colors.width.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // The other projector of a pair reads as a guide: dashed.
    final frame = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    side.inactive
        ? _dashedRect(canvas, rect, frame)
        : canvas.drawRect(rect, frame);
  }

  void _paintStatus(Canvas canvas, Rect rect, String status) {
    final text = TextPainter(
      text: TextSpan(text: status, style: colors.text),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    text.paint(canvas, rect.center - Offset(text.width / 2, text.height / 2));
  }

  void _paintHandles(Canvas canvas, _PaintSide side) {
    final state = side.state;
    if (!side.editable || state == null) return;
    final black = side.black;
    for (final edge in BlendEdge.values) {
      if (!state[edge].enabled) continue;
      if (blackTab) {
        if (black != null) _paintHandle(canvas, side, edge, EdgePart.border);
      } else {
        // Width after Start: drawn on top, as it wins the hit test.
        _paintHandle(canvas, side, edge, EdgePart.start);
        _paintHandle(canvas, side, edge, EdgePart.width);
      }
    }
  }

  /// The levels where the projector applies them (§8 "Black level zones"):
  /// the non-overlapped level over the whole raster, then per enabled edge
  /// black up to Start, the overlapped level to the zone end and overlapped
  /// + border (hatched) to the border line. Drawn the same in both Black
  /// Level Modes. A disabled edge has no bands, only its outline.
  void _paintBlack(
    Canvas canvas,
    _PaintSide side,
    EdgeBlendState state,
    BlackLevelState black,
  ) {
    final box = side.box;
    canvas.drawRect(
      box.rect,
      Paint()..color = _rgbColor(black[LevelSlot.nonOverlapped].value),
    );
    final border = black[LevelSlot.border].value;
    final hatch = Paint()
      ..color = colors.outline.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final idle = Paint()
      ..color = colors.idle
      ..strokeWidth = 1.5;
    for (final edge in BlendEdge.values) {
      final s = state[edge];
      final bands = blendBands(
        start: s.start,
        width: s.width,
        border: s.border,
      );
      if (!s.enabled) {
        if (bands.line > 0) {
          _dashedRect(canvas, box.band(edge, 0, bands.line), idle);
        }
        continue;
      }
      final overlapped = black[LevelSlot.overlap(edge)].value;
      if (bands.start > 0) {
        canvas.drawRect(
          box.band(edge, 0, bands.start),
          Paint()..color = Colors.black,
        );
      }
      if (bands.end > bands.start) {
        canvas.drawRect(
          box.band(edge, bands.start, bands.end),
          Paint()..color = _rgbColor(overlapped),
        );
      }
      if (bands.line > bands.end) {
        final c = box.band(edge, bands.end, bands.line);
        canvas.drawRect(
          c,
          Paint()..color = _rgbColor(stackLevels(overlapped, border)),
        );
        _hatch(canvas, c, hatch);
      }
      // Where the levels change: Start and the zone end (the markers'
      // lines on the screen), in their own colours.
      _dashedLine(
        canvas,
        box,
        edge,
        box.lineAt(edge, bands.start),
        Paint()
          ..color = colors.start.withValues(alpha: 0.7)
          ..strokeWidth = 1.2,
      );
      _dashedLine(
        canvas,
        box,
        edge,
        box.lineAt(edge, bands.end),
        Paint()
          ..color = colors.width.withValues(alpha: 0.7)
          ..strokeWidth = 1.2,
      );
    }
    // Then the border line the handle moves.
    for (final edge in BlendEdge.values) {
      final selected = side.selection?.edge == edge;
      _line(
        canvas,
        box,
        edge,
        box.lineAt(edge, state[edge].line),
        Paint()
          ..color = !state[edge].enabled
              ? colors.idle
              : selected
              ? colors.borderSelected
              : colors.border
          ..strokeWidth = selected ? 2.0 : 1.5,
      );
    }
  }

  /// Black from the raster edge to Start, then the blend zone as a ramp
  /// that fades out at Start + Width, as the projector darkens towards its
  /// own edge. Start's line is amber, the zone end's primary (owner,
  /// 2026-10-14); a selected edge's zone end is solid and its zone
  /// outlined.
  void _paintZone(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgeSettings s,
  ) {
    const dark = Color(0xEB000000); // black at 92 %
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
            colors.width.withValues(alpha: 0.5),
            colors.width.withValues(alpha: 0.03),
          ]),
      );
    }
    final selected = side.selection?.edge == edge;
    if (selected && s.width > 0) {
      canvas.drawRect(
        zone,
        Paint()
          ..color = colors.width
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    _dashedLine(
      canvas,
      box,
      edge,
      a,
      Paint()
        ..color = colors.start.withValues(alpha: selected ? 1 : 0.7)
        ..strokeWidth = 1.5,
    );
    final end = Paint()
      ..color = colors.width.withValues(alpha: selected ? 1 : 0.6)
      ..strokeWidth = selected ? 2 : 1.5;
    selected
        ? _line(canvas, box, edge, b, end)
        : _dashedLine(canvas, box, edge, b, end);
  }

  Color _partColor(EdgePart part) => switch (part) {
    EdgePart.start => colors.start,
    EdgePart.width => colors.width,
    EdgePart.border => colors.border,
  };

  /// A capsule across the line at its midpoint (at the same height on
  /// every line): ringed in its part's colour, filled when it's the
  /// selected one; other edges' handles a little faded.
  void _paintHandle(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgePart part,
  ) {
    final sel = side.selection;
    final center = side.box.handleAt(
      edge,
      _handleUnits(side.state!, edge, part),
    );
    final selectedEdge = sel?.edge == edge;
    final active = selectedEdge && sel?.part == part;
    final color = active && part == EdgePart.border
        ? colors.borderSelected
        : _partColor(part);
    final rect = Rect.fromCenter(
      center: center,
      width: edge.isHorizontal ? 10 : 30,
      height: edge.isHorizontal ? 30 : 10,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    final opacity = sel == null || selectedEdge ? 1.0 : 0.8;
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = (active ? color : colors.handleFill).withValues(
          alpha: opacity,
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = (active ? colors.halo : color).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// The selected handle's value in a pill across the edge's axis from it,
  /// kept inside the raster: `Width 640`. An edge's handles all sit on the
  /// raster's midline and move only along it, so a pill above (left, right)
  /// or beside (upper, lower) never covers a neighbouring handle, as one
  /// placed inward along the axis did at a small Width.
  void _paintValuePill(
    Canvas canvas,
    _PaintSide side,
    BlendEdge edge,
    EdgePart part,
  ) {
    final state = side.state!;
    final units = _handleUnits(state, edge, part);
    final (label, fill, fg) = switch (part) {
      EdgePart.start => (
        'Start ${state[edge].start}',
        colors.startContainer,
        colors.start,
      ),
      EdgePart.width => (
        'Width ${state[edge].width}',
        colors.widthContainer,
        colors.onWidthContainer,
      ),
      EdgePart.border => (
        'Border ${state[edge].border}',
        colors.borderContainer,
        colors.borderSelected,
      ),
    };
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: colors.value.copyWith(color: fg),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final handle = side.box.handleAt(edge, units);
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final chipSize = Size(
      text.width + pad.horizontal,
      text.height + pad.vertical,
    );
    // Half the handle's 30 px long side, plus a gap.
    const clear = 15.0 + 6;
    final r = side.box.rect;
    final Offset offset;
    if (edge.isHorizontal) {
      // Above, or below when the raster has no room above.
      final above = handle.dy - clear - chipSize.height >= r.top;
      offset = Offset(
        -chipSize.width / 2,
        above ? -clear - chipSize.height : clear,
      );
    } else {
      // Right, or left when the raster has no room on the right.
      final right = handle.dx + clear + chipSize.width <= r.right;
      offset = Offset(
        right ? clear : -clear - chipSize.width,
        -chipSize.height / 2,
      );
    }
    // Not clamped to the raster: pushed in at its edge the chip slid off
    // its handle. The canvas margin leaves room for it to hang out.
    final topLeft = handle + offset;
    canvas.drawRRect(
      RRect.fromRectAndRadius(topLeft & chipSize, const Radius.circular(6)),
      Paint()..color = fill,
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
