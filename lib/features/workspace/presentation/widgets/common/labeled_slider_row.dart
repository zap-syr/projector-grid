import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../sleek_stepper_input.dart';
import 'slider_tracks.dart';

/// The thin slider of visual rules §6a: an optional label on the left, the
/// slider (track 2, thumb r6) in [color] and the 32 px value field on the
/// right, synced both ways. Shared by Geometry, Color Correction and Edge
/// Blending. Passing null for both callbacks disables the row.
class LabeledSliderRow extends StatelessWidget {
  const LabeledSliderRow({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.label,
    this.labelWidth = 14,
    this.labelStyle,
    this.step = 1.0,
    this.snap = true,
    this.color,
    this.zeroFraction,
    this.limit,
    this.onTyped,
    this.labelMark,
  });

  /// A small mark before [label], inside [labelWidth] (Edge Blending's
  /// Start and Width squares, which tie a slider to its canvas colour).
  final Widget? labelMark;

  /// Null for no label column (Color's rows put a channel tile there).
  final String? label;

  /// 14 fits a channel letter, wider for a word (`Horizontal`, `Width`).
  final double labelWidth;

  /// Replaces the default label, a bold channel letter in [color].
  final TextStyle? labelStyle;

  final double value;
  final double min;
  final double max;
  final double step;

  /// Snap the slider to [step]; off for continuous sliders whose value is
  /// rounded by the caller.
  final bool snap;

  /// Track fill and thumb; the primary colour when null.
  final Color? color;

  /// Fill from a zero tick at this fraction of the track (0.5 for a range
  /// symmetric around 0).
  final double? zeroFraction;

  /// A stop below [max] that moves with other values (Edge Blending's §8
  /// limits). The slider keeps the full range and the caller clamps its
  /// value; the track past it is hatched, and the field gets it as its max,
  /// or its own text would run past.
  final double? limit;

  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// A typed or stepped value, only when it differs from [value]. When
  /// null, such a value goes to [onChanged] and [onChangeEnd] as a drag
  /// would.
  final ValueChanged<double>? onTyped;

  static const double fieldGap = 10;

  static String _cleanStr(double v) {
    final r = v.roundToDouble();
    return v == r ? r.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final enabled = onChanged != null || onChangeEnd != null;
    final accent = color ?? cs.primary;
    final limit = this.limit;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        // Keeps the thumb inside the row at either end, and the slider as
        // tall as the field instead of the 48 px overlay.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        trackShape: AppSliderTrackShape(
          zeroFraction: zeroFraction,
          limitFraction: limit == null ? null : (limit - min) / (max - min),
        ),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6,
          disabledThumbRadius: 6,
          elevation: 1,
        ),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        activeTrackColor: accent,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
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
          max: limit ?? max,
          step: step,
          onValueChanged: (s) {
            final v = double.tryParse(s);
            if (v == null) return;
            final typed = onTyped;
            if (typed != null) {
              if (v != value) typed(v);
            } else {
              onChanged?.call(v);
              onChangeEnd?.call(v);
            }
          },
        ),
      ),
    );

    final label = this.label;
    final labelText = label == null
        ? null
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                labelStyle ??
                t.caption.copyWith(fontWeight: FontWeight.w700, color: accent),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            if (label != null) ...[
              SizedBox(
                width: labelWidth,
                child: labelMark == null
                    ? labelText
                    : Row(
                        children: [
                          labelMark!,
                          const SizedBox(width: 7),
                          Flexible(child: labelText!),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: slider),
            const SizedBox(width: fieldGap),
            stepper,
          ],
        ),
      ),
    );
  }
}
