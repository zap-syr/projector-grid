import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/slider_tracks.dart';

/// Records where [Slider] paints the thumb.
class _RecordingThumb extends RoundSliderThumbShape {
  _RecordingThumb(this.centers);

  final List<Offset> centers;

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
  }) => centers.add(center);
}

void main() {
  const width = 300.0;
  const trackHeight = 6.0;

  Future<double> thumbX(
    WidgetTester tester,
    double fraction, {
    required int? divisions,
  }) async {
    final centers = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: width,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: trackHeight,
                  padding: EdgeInsets.zero,
                  trackShape: const AppSliderTrackShape(limitFraction: 0.8),
                  thumbShape: _RecordingThumb(centers),
                ),
                child: Slider(
                  value: fraction,
                  divisions: divisions,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The slider paints in its own layer, so the centre is already local.
    return centers.last.dx;
  }

  for (final fraction in [0.0, 0.25, 0.8, 1.0]) {
    testWidgets('a discrete thumb at $fraction sits on positionOf', (
      tester,
    ) async {
      final x = await thumbX(tester, fraction, divisions: 20);
      expect(
        x,
        moreOrLessEquals(
          AppSliderTrackShape.positionOf(
            fraction,
            left: 0,
            width: width,
            trackHeight: trackHeight,
            isDiscrete: true,
          ),
        ),
      );
    });
  }

  testWidgets('a continuous thumb at 0.8 sits on positionOf', (tester) async {
    final x = await thumbX(tester, 0.8, divisions: null);
    expect(
      x,
      moreOrLessEquals(
        AppSliderTrackShape.positionOf(
          0.8,
          left: 0,
          width: width,
          trackHeight: trackHeight,
          isDiscrete: false,
        ),
      ),
    );
  });
}
