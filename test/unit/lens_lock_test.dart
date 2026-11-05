import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/lens_commands.dart';

void main() {
  test('every lens motor command is a lens motion, lens type is not', () {
    for (final cmd in [
      lensStepCommand(LensAxis.shiftH, plus: true, speed: LensSpeed.fast),
      lensStepCommand(LensAxis.shiftV, plus: false, speed: LensSpeed.slow),
      lensStepCommand(LensAxis.focus, plus: true, speed: LensSpeed.normal),
      lensStepCommand(LensAxis.zoom, plus: false, speed: LensSpeed.normal),
      kLensHomeCommand,
      'VXX:LNSI0=+00001',
    ]) {
      expect(isLensMotionCommand(cmd), isTrue, reason: cmd);
    }
    for (final cmd in ['VXX:LNEI1=+00001', 'OSH:1', 'PON', 'OTS:07']) {
      expect(isLensMotionCommand(cmd), isFalse, reason: cmd);
    }
  });

  test('lensLockState: none, some or all of the selection', () {
    expect(lensLockState([]), LensLockState.none);
    expect(lensLockState([false, false]), LensLockState.none);
    expect(lensLockState([true, false]), LensLockState.some);
    expect(lensLockState([true, true]), LensLockState.all);
  });
}
