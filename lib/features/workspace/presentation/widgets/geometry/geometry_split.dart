import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The body below the mode tiles: the preview or canvas card on the left,
/// the controls card on the right (§7.1). The left card is 480 wide in a
/// full-size dialog and gives way first in a smaller one, down to 340, so
/// the controls keep room for a slider next to its field.
class GeometrySplit extends StatelessWidget {
  const GeometrySplit({super.key, required this.builder});

  /// Builds the two cards; `compact` when the left card is narrower than
  /// [compactBelow] (shorter legend, hints in tooltips).
  final (Widget left, Widget right) Function(bool compact) builder;

  static const double gap = 16;
  static const double maxLeft = 480;
  static const double minLeft = 340;

  /// What the controls card keeps before the left card shrinks.
  static const double controlsWidth = 376;
  static const double compactBelow = 440;

  static double leftWidth(double width) =>
      math.max(minLeft, math.min(maxLeft, width - gap - controlsWidth));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = leftWidth(constraints.maxWidth);
        final (l, r) = builder(left < compactBelow);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: left, child: l),
            const SizedBox(width: gap),
            Expanded(child: r),
          ],
        );
      },
    );
  }
}
