import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/labeled_slider_row.dart';

/// One thin slider with its 32 px value field, label on the left. Every
/// Geometry range is symmetric, so the fill starts at the centre zero tick.
class GeometrySliderRow extends StatelessWidget {
  const GeometrySliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.step = 1,
    this.snap = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool snap;

  /// Both null: disabled and dimmed (Auto linearity and pincushion).
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Fits `Horizontal`, the longest label.
  static const double labelWidth = 80;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final enabled = onChanged != null || onChangeEnd != null;
    return LabeledSliderRow(
      labelWidth: labelWidth,
      labelStyle: t.body.copyWith(color: enabled ? t.secondary : t.disabled),
      label: label,
      zeroFraction: 0.5,
      value: value,
      min: min,
      max: max,
      step: step,
      snap: snap,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// The key of Geometry's right-hand [ControlsCard], for tests.
const geometryControlsCardKey = ValueKey('geometry-controls-card');

/// The key of Geometry's left-hand canvas card, for tests.
const geometryCanvasCardKey = ValueKey('geometry-canvas-card');
