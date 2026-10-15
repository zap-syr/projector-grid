import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// A dashed rounded-rectangle outline around [child], drawn along the path
/// with [PathMetric] (no package). Used for the New task card, the empty
/// favourite slot, mouse-action pills, offline tiles and placeholders.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color,
    this.radius = 10,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget child;

  /// Defaults to the theme's `outline`.
  final Color? color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedRRectPainter(
        color: color ?? Theme.of(context).colorScheme.outline,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(dashPath(Path()..addRRect(rrect), dash, gap), paint);
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

/// [source] cut into dashes of [dash] separated by [gap].
Path dashPath(Path source, double dash, double gap) {
  final out = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      out.addPath(metric.extractPath(distance, end), Offset.zero);
      distance += dash + gap;
    }
  }
  return out;
}
