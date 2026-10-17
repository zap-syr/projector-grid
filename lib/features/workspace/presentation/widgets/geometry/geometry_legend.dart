import 'package:flutter/material.dart';

import '../common/canvas_card.dart';
import '../common/dashed_border.dart';

enum LegendMark { panel, image, outerLimit, defaultFrame, range }

/// The Geometry legend: [CanvasLegend] with this dialog's swatches.
class GeometryLegend extends StatelessWidget {
  const GeometryLegend({super.key, required this.items, this.trailing});

  final List<(LegendMark, String)> items;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => CanvasLegend(
    items: [for (final (mark, label) in items) (_Swatch(mark), label)],
    trailing: trailing,
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.mark);

  final LegendMark mark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(2);
    return switch (mark) {
      LegendMark.outerLimit => DashedBorder(
        color: cs.outline,
        radius: 2,
        dash: 3,
        gap: 2,
        child: const SizedBox.expand(),
      ),
      LegendMark.panel || LegendMark.defaultFrame => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: cs.outline),
        ),
      ),
      LegendMark.image => DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.16),
          borderRadius: radius,
          border: Border.all(color: cs.primary, width: 2),
        ),
      ),
      LegendMark.range => DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: radius,
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
      ),
    };
  }
}
