import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/slider_tracks.dart';
import '../sleek_stepper_input.dart';

/// The square with a channel's letter (R, G, B) at the start of a row.
class ChannelTile extends StatelessWidget {
  const ChannelTile({super.key, required this.letter, required this.color});

  static const double size = 22;

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Text(
      letter,
      style: AppText.of(context).caption
          .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}

/// A thin slider (visual rules §6a) in a channel's colour with the 32 px
/// value field on its right, synced both ways. A drag reports every
/// position to [onChanged] and the release to [onCommit]; the field reports
/// a typed or stepped value to [onTyped], only when it differs.
class ChannelSlider extends StatelessWidget {
  const ChannelSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
    required this.onCommit,
    required this.onTyped,
    this.zeroFraction,
  });

  final int value;
  final int min;
  final int max;
  final Color color;

  /// Fill from a centre zero tick (white balance Low).
  final double? zeroFraction;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onCommit;
  final ValueChanged<int> onTyped;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                padding: EdgeInsets.zero,
                trackShape: AppSliderTrackShape(zeroFraction: zeroFraction),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  disabledThumbRadius: 6,
                  elevation: 1,
                ),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                activeTrackColor: color,
                inactiveTrackColor: cs.outlineVariant,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
              ),
              child: Slider(
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                value: value.clamp(min, max).toDouble(),
                onChanged: (v) => onChanged(v.round()),
                onChangeEnd: (v) => onCommit(v.round()),
              ),
            ),
          ),
          SleekStepperInput(
            initialValue: '$value',
            min: min.toDouble(),
            max: max.toDouble(),
            onValueChanged: (s) {
              final v = double.tryParse(s)?.round();
              if (v != null && v != value) onTyped(v);
            },
          ),
        ],
      ),
    );
  }
}
