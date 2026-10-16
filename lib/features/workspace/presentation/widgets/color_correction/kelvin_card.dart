import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/color_correction.dart';
import '../common/step_buttons.dart';
import 'card_heading.dart';
import 'color_swatches.dart';

/// Shared by the slider and the scale under it.
const double _trackHeight = 6;

/// Custom color temperature: the value large on the right, the large slider
/// (visual rules §6a) on the blackbody gradient between − / +, a scale, and
/// the preset chips. − / + and presets report through [onStep] and
/// [onPreset] for the parent to debounce; a drag reports every position to
/// [onChanged] and its release to [onCommit].
class KelvinCard extends StatelessWidget {
  const KelvinCard({
    super.key,
    required this.kelvin,
    required this.onChanged,
    required this.onCommit,
    required this.onStep,
    required this.onPreset,
  });

  final int kelvin;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onCommit;

  /// How many 100 K steps, negative for warmer.
  final ValueChanged<int> onStep;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;

    Widget valueText(String digits) => Text.rich(
      TextSpan(
        text: digits,
        children: [
          TextSpan(
            text: ' K',
            style: t.cardTitle.copyWith(
              fontWeight: FontWeight.w400,
              color: t.secondary,
            ),
          ),
        ],
      ),
      style: t.value.copyWith(height: 32 / 26),
    );

    final scaleStyle = t.caption.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ColorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColorCardHeading(
            icon: Icons.thermostat_outlined,
            title: 'Color temperature',
            subtitle: 'Lower is warmer, higher is cooler',
            // Sized by an invisible widest value, so the heading doesn't
            // reflow between 9300 K and 10000 K.
            trailing: Stack(
              alignment: Alignment.centerRight,
              children: [
                Opacity(opacity: 0, child: valueText('$kelvinMax')),
                valueText('$kelvin'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: Row(
              spacing: 12,
              children: [
                StepButton.minus(
                  tooltip: 'Warmer by $kelvinStep K',
                  onStep: kelvin > kelvinMin ? (steps) => onStep(-steps) : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: _trackHeight,
                      padding: EdgeInsets.zero,
                      trackShape: _KelvinTrackShape(border: cs.outlineVariant),
                      thumbShape: const _KelvinThumbShape(),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      overlayColor: cs.onSurface.withValues(alpha: 0.12),
                      tickMarkShape: SliderTickMarkShape.noTickMark,
                    ),
                    child: Slider(
                      min: kelvinMin.toDouble(),
                      max: kelvinMax.toDouble(),
                      divisions: (kelvinMax - kelvinMin) ~/ kelvinStep,
                      value: kelvin.toDouble(),
                      onChanged: (v) => onChanged(_snap(v)),
                      onChangeEnd: (v) => onCommit(_snap(v)),
                    ),
                  ),
                ),
                StepButton.plus(
                  tooltip: 'Cooler by $kelvinStep K',
                  onStep: kelvin < kelvinMax ? onStep : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Step button (32) + gap (12): the scale lines up with the track.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$kelvinMin K', style: scaleStyle),
                Text('$kelvinMax K', style: scaleStyle),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              SizedBox(
                height: _PresetChip.height,
                child: Center(child: Text('Presets', style: t.label)),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in kelvinPresets)
                      _PresetChip(
                        kelvin: k,
                        selected: k == kelvin,
                        onTap: () => onPreset(k),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _snap(double v) => (v / kelvinStep).round() * kelvinStep;
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.kelvin,
    required this.selected,
    required this.onTap,
  });

  static const double height = 28;

  final int kelvin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                '$kelvin K',
                style: t.label.copyWith(
                  color: selected ? cs.onPrimaryContainer : t.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The blackbody gradient as the track, no fill: the thumb shows the value.
class _KelvinTrackShape extends RoundedRectSliderTrackShape {
  const _KelvinTrackShape({required this.border});

  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    context.canvas
      ..drawRRect(rrect, Paint()..shader = kelvinGradient.createShader(rect))
      ..drawRRect(
        rrect,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }
}

/// White, so it reads on every part of the gradient; the large slider's
/// radius 9.
class _KelvinThumbShape extends SliderComponentShape {
  const _KelvinThumbShape();

  static const double _radius = 9;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas
      ..drawCircle(center, _radius, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        _radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }
}
