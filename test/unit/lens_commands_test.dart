import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/lens_commands.dart';

void main() {
  // The exact strings the control bar sent before the encoding moved here.
  test('lens steps match the control bar\'s commands', () {
    String s(LensAxis a, bool plus, LensSpeed speed) =>
        lensStepCommand(a, plus: plus, speed: speed);
    const f = LensSpeed.fast, n = LensSpeed.normal, sl = LensSpeed.slow;

    expect(s(LensAxis.shiftV, true, f), 'VXX:LNSI3=+00200'); // up
    expect(s(LensAxis.shiftV, true, n), 'VXX:LNSI3=+00100');
    expect(s(LensAxis.shiftV, true, sl), 'VXX:LNSI3=+00000');
    expect(s(LensAxis.shiftV, false, sl), 'VXX:LNSI3=+00001'); // down
    expect(s(LensAxis.shiftV, false, n), 'VXX:LNSI3=+00101');
    expect(s(LensAxis.shiftV, false, f), 'VXX:LNSI3=+00201');
    expect(s(LensAxis.shiftH, false, f), 'VXX:LNSI2=+00201'); // left
    expect(s(LensAxis.shiftH, false, n), 'VXX:LNSI2=+00101');
    expect(s(LensAxis.shiftH, false, sl), 'VXX:LNSI2=+00001');
    expect(s(LensAxis.shiftH, true, sl), 'VXX:LNSI2=+00000'); // right
    expect(s(LensAxis.shiftH, true, n), 'VXX:LNSI2=+00100');
    expect(s(LensAxis.shiftH, true, f), 'VXX:LNSI2=+00200');
    expect(s(LensAxis.focus, false, f), 'VXX:LNSI4=+00201');
    expect(s(LensAxis.focus, true, sl), 'VXX:LNSI4=+00000');
    expect(s(LensAxis.zoom, false, n), 'VXX:LNSI5=+00101');
    expect(s(LensAxis.zoom, true, f), 'VXX:LNSI5=+00200');
    expect(kLensHomeCommand, 'VXX:LNSI1=+00001');
  });
}
