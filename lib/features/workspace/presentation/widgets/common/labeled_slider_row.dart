import 'package:flutter/material.dart';

import '../sleek_stepper_input.dart';

enum SliderLabelLayout {
  /// Label on its own line, slider + stepper below (Geometry dialog).
  above,

  /// Short coloured label, slider and stepper on one line (RGB rows).
  inline,
}

/// Label + slider + [SleekStepperInput] shared by the projector settings
/// dialogs. Passing null for both callbacks disables the row.
class LabeledSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;

  /// Snap the slider to [step]; off for continuous sliders whose value is
  /// rounded by the caller.
  final bool snap;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final SliderLabelLayout layout;

  /// Accent for the label and slider track/thumb (inline RGB rows).
  final Color? color;

  const LabeledSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.step = 1.0,
    this.snap = true,
    this.layout = SliderLabelLayout.above,
    this.color,
  });

  static String _cleanStr(double v) {
    final r = v.roundToDouble();
    return v == r ? r.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null || onChangeEnd != null;
    final accent = color;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        activeTrackColor: accent?.withValues(alpha: 0.8),
        thumbColor: accent,
        inactiveTrackColor: accent?.withValues(alpha: 0.2),
        overlayColor: accent?.withValues(alpha: 0.1),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: snap ? ((max - min) / step).round() : null,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );

    // Always wrap in the same ancestor shape (only toggling its properties)
    // so the stepper's Element/State — and its text-field semantics — survive
    // enable/disable switches instead of being torn down and recreated.
    final stepper = IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: SleekStepperInput(
          initialValue: _cleanStr(value),
          min: min,
          max: max,
          step: step,
          onValueChanged: (s) {
            final v = double.tryParse(s);
            if (v != null) {
              onChanged?.call(v);
              onChangeEnd?.call(v);
            }
          },
        ),
      ),
    );

    return switch (layout) {
      SliderLabelLayout.above => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: slider),
              const SizedBox(width: 16),
              stepper,
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      SliderLabelLayout.inline => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: slider),
            const SizedBox(width: 8),
            stepper,
          ],
        ),
      ),
    };
  }
}
