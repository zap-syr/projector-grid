import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'common/key_caps.dart';

enum TooltipPlacement { top, bottom }

/// The app's tooltip: a raised surface with an arrow to its anchor, a title
/// line, an optional [detail] line and an optional [shortcut] in key caps.
/// [warning] gives it an amber border and title with a warning icon.
///
/// Transparent to the mouse pointer via [IgnorePointer]. Placed above the
/// anchor by default, below with [TooltipPlacement.bottom], clamped to the
/// window horizontally.
class CustomTooltip extends StatefulWidget {
  final String message;
  final String? detail;

  /// Keys shown as caps right of the title, e.g. `['Ctrl', 'L']`.
  final List<String>? shortcut;
  final bool warning;
  final Widget child;
  final TooltipPlacement placement;

  const CustomTooltip({
    super.key,
    required this.message,
    required this.child,
    this.detail,
    this.shortcut,
    this.warning = false,
    this.placement = TooltipPlacement.top,
  });

  @override
  State<CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<CustomTooltip> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null || !mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(
      builder: (_) => CustomMultiChildLayout(
        delegate: _TooltipLayoutDelegate(
          anchorPosition: position,
          anchorSize: size,
          placement: widget.placement,
        ),
        children: [
          LayoutId(
            id: _TooltipSlot.bubble,
            child: IgnorePointer(
              child: TooltipBubble(
                message: widget.message,
                detail: widget.detail,
                shortcut: widget.shortcut,
                warning: widget.warning,
              ),
            ),
          ),
          LayoutId(
            id: _TooltipSlot.arrow,
            child: IgnorePointer(
              child: _TooltipArrow(
                pointsDown: widget.placement == TooltipPlacement.top,
                warning: widget.warning,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}

const double _maxBubbleWidth = 260;
const double _radius = 9;
const Size _arrowSize = Size(12, 6);

/// The tooltip's body without the arrow; public so other overlays (the
/// quick status popover) can share the surface.
class TooltipBubble extends StatelessWidget {
  const TooltipBubble({
    super.key,
    required this.message,
    this.detail,
    this.shortcut,
    this.warning = false,
  });

  final String message;
  final String? detail;
  final List<String>? shortcut;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sc = AppStatusColors.of(context);
    final titleColor = warning ? sc.warning : cs.onSurface;
    final title = Text(
      message,
      style: TextStyle(
        color: titleColor,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
    final shortcut = this.shortcut;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: sc.tooltipBackground,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: warning ? sc.warning : sc.tooltipBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.light ? 0.14 : 0.35,
              ),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (warning) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: sc.warning,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(child: title),
                if (shortcut != null && shortcut.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  KeyCaps(shortcut, small: true),
                ],
              ],
            ),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(
                detail!,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TooltipArrow extends StatelessWidget {
  const _TooltipArrow({required this.pointsDown, required this.warning});

  final bool pointsDown;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final sc = AppStatusColors.of(context);
    return CustomPaint(
      size: _arrowSize,
      painter: _ArrowPainter(
        pointsDown: pointsDown,
        fill: sc.tooltipBackground,
        border: warning ? sc.warning : sc.tooltipBorder,
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.pointsDown,
    required this.fill,
    required this.border,
  });

  final bool pointsDown;
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    // The arrow overlaps the bubble's 1 px border so the fill hides it there
    // and only the two slanted sides carry the border colour.
    final w = size.width;
    final h = size.height;
    final tipY = pointsDown ? h : 0.0;
    final baseY = pointsDown ? -1.0 : h + 1;
    final path = Path()
      ..moveTo(0, baseY)
      ..lineTo(w / 2, tipY)
      ..lineTo(w, baseY)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    final edge = Path()
      ..moveTo(0, baseY)
      ..lineTo(w / 2, tipY)
      ..lineTo(w, baseY);
    canvas.drawPath(
      edge,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.pointsDown != pointsDown || old.fill != fill || old.border != border;
}

// ── Layout delegate ───────────────────────────────────────────────────────────

enum _TooltipSlot { bubble, arrow }

/// Lays out bubble and arrow together: once the bubble is clamped to the
/// window edge, the arrow still has to point at the anchor's centre, which a
/// single-child layout can't hand to its child.
class _TooltipLayoutDelegate extends MultiChildLayoutDelegate {
  final Offset anchorPosition;
  final Size anchorSize;
  final TooltipPlacement placement;

  static const double _margin = 8.0;
  static const double _gap = 4.0;

  _TooltipLayoutDelegate({
    required this.anchorPosition,
    required this.anchorSize,
    required this.placement,
  });

  @override
  void performLayout(Size size) {
    final bubble = layoutChild(
      _TooltipSlot.bubble,
      BoxConstraints(maxWidth: size.width - _margin * 2),
    );
    layoutChild(_TooltipSlot.arrow, BoxConstraints.tight(_arrowSize));

    final centerX = anchorPosition.dx + anchorSize.width / 2;
    final left = (centerX - bubble.width / 2).clamp(
      _margin,
      size.width - bubble.width - _margin,
    );
    final above = placement == TooltipPlacement.top;
    final arrowTop = above
        ? anchorPosition.dy - _gap - _arrowSize.height
        : anchorPosition.dy + anchorSize.height + _gap;
    final bubbleTop = above
        ? arrowTop - bubble.height
        : arrowTop + _arrowSize.height;
    positionChild(_TooltipSlot.bubble, Offset(left, bubbleTop));

    // Keep the arrow off the bubble's rounded corners.
    final minArrow = left + _radius;
    final arrowLeft = (centerX - _arrowSize.width / 2).clamp(
      minArrow,
      (left + bubble.width - _radius - _arrowSize.width).clamp(
        minArrow,
        double.infinity,
      ),
    );
    positionChild(_TooltipSlot.arrow, Offset(arrowLeft, arrowTop));
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate old) =>
      old.anchorPosition != anchorPosition ||
      old.anchorSize != anchorSize ||
      old.placement != placement;
}
