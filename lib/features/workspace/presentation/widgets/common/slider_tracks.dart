import 'package:flutter/material.dart';

/// A slider track that can fill from a centre zero instead of from the
/// start, and hatch the part above a limit the thumb can't pass.
///
/// - [zeroFraction]: where 0 sits on the track (0.5 for `-127 to 127`). The
///   active fill runs from there to the thumb and a tick marks the zero.
/// - [limitFraction]: a stop below the track's max (Brightness: Max light
///   output in a User mode; Edge Blending: the §8 limits). The track past it
///   is hatched and a tick marks it.
class AppSliderTrackShape extends RoundedRectSliderTrackShape {
  const AppSliderTrackShape({this.zeroFraction, this.limitFraction});

  final double? zeroFraction;
  final double? limitFraction;

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
    final canvas = context.canvas;
    final enabled = enableAnimation.value > 0.5;
    final active = (enabled
        ? sliderTheme.activeTrackColor
        : sliderTheme.disabledActiveTrackColor)!;
    final inactive = (enabled
        ? sliderTheme.inactiveTrackColor
        : sliderTheme.disabledInactiveTrackColor)!;
    final radius = Radius.circular(rect.height / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = inactive,
    );

    final limit = limitFraction;
    if (limit != null && limit < 1) {
      final limitX = rect.left + rect.width * limit;
      final hatchRect = Rect.fromLTRB(
        limitX,
        rect.top - 2,
        rect.right,
        rect.bottom + 2,
      );
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(hatchRect, radius));
      final hatch = Paint()
        ..color = active.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (
        var x = hatchRect.left - hatchRect.height;
        x < hatchRect.right;
        x += 4
      ) {
        canvas.drawLine(
          Offset(x, hatchRect.bottom),
          Offset(x + hatchRect.height, hatchRect.top),
          hatch,
        );
      }
      canvas.restore();
      _tick(canvas, limitX, rect, active);
    }

    final zero = zeroFraction;
    final startX = zero == null ? rect.left : rect.left + rect.width * zero;
    final fill = Rect.fromLTRB(
      startX < thumbCenter.dx ? startX : thumbCenter.dx,
      rect.top,
      startX < thumbCenter.dx ? thumbCenter.dx : startX,
      rect.bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, radius),
      Paint()..color = active,
    );
    if (zero != null) _tick(canvas, startX, rect, inactive.withAlpha(255));
  }

  void _tick(Canvas canvas, double x, Rect track, Color color) {
    canvas.drawLine(
      Offset(x, track.top - 4),
      Offset(x, track.bottom + 4),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }
}
