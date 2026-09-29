import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';

void main() {
  test('exact control-bar commands', () {
    const expected = {
      'PON': 'Power On',
      'POF': 'Power Standby',
      'OSH:0': 'Shutter Open',
      'OSH:1': 'Shutter Close',
      'OOS:1': 'OSD On',
      'OOS:0': 'OSD Off',
      'IIS:HD1': 'Input HDMI 1',
      'IIS:HD2': 'Input HDMI 2',
      'IIS:SD1': 'Input SDI 1',
      'IIS:SD2': 'Input SDI 2',
      'IIS:DL1': 'Input Digital Link',
      'IIS:DVI': 'Input DVI-D',
      'IIS:DP1': 'Input DisplayPort',
      'IIS:RG1': 'Input Computer 1',
      'IIS:RG2': 'Input Computer 2',
      'IIS:VID': 'Input Video',
      'IIS:SVD': 'Input Y/C',
      'OTS:00': 'Test Pattern Off',
      'OTS:01': 'Test Pattern White',
      'OTS:02': 'Test Pattern Black',
      'VXX:QPDI1=+00001': 'Quad Pixel On',
      'VXX:QPDI1=+00000': 'Quad Pixel Off',
      'VXX:LNSI1=+00001': 'Lens Home',
      'VXX:LNSI0=+00001': 'Lens Calibration',
    };
    expected.forEach((cmd, label) => expect(commandLabel(cmd), label));
  });

  test('prefix families', () {
    const expected = {
      'VXX:LNSI3=+00101': 'Lens Shift V',
      'VXX:LNSI2=+00001': 'Lens Shift H',
      'VXX:LNSI4=+00200': 'Focus Adjust',
      'VXX:LNSI5=+00001': 'Zoom Adjust',
      'IIS:XYZ': 'Input: XYZ',
      'OTS:22': 'Test Pattern',
      'VPM:DYN': 'Picture Mode',
      'VXX:PMDI0=+00003': 'Picture Mode',
      'VXX:SEFS1=1.0': 'Shutter Fade In',
      'VXX:SEFS2=0.5': 'Shutter Fade Out',
      'OBC:1': 'Back Color',
      'MLO:0': 'Startup Logo',
      'OIL:2': 'Projection Method',
      'VXX:LNEI1=+00001': 'Lens Type',
    };
    expected.forEach((cmd, label) => expect(commandLabel(cmd), label));
  });

  test('every control-bar command gets a human label', () {
    // Mirrors the option maps in control_bar.dart.
    const commands = [
      'PON',
      'POF',
      'OSH:0',
      'OSH:1',
      'OOS:1',
      'OOS:0',
      'OTS:00',
      'VXX:QPDI1=+00001',
      'VXX:QPDI1=+00000',
      'VXX:LNSI1=+00001',
      'VXX:LNSI0=+00001',
      'VXX:LNSI0=+00011',
      'VXX:LNSI0=+00012',
      'VXX:LNSI0=+00013',
      'VXX:LNSI0=+00021',
      'VXX:LNSI0=+00022',
      'VXX:LNSI0=+00023',
      'VXX:LNEI1=+00001',
      'VXX:LNEI1=+00009',
      'VXX:LNSI3=+00200',
      'VXX:LNSI3=+00001',
      'VXX:LNSI2=+00201',
      'VXX:LNSI2=+00000',
      'VXX:LNSI4=+00100',
      'VXX:LNSI5=+00101',
      'OTS:01',
      'OTS:32',
      'OTS:87',
      'IIS:HD1',
      'IIS:HD2',
      'IIS:DP1',
      'IIS:DVI',
      'IIS:SD1',
      'IIS:SD2',
      'IIS:DL1',
      'IIS:RG1',
      'IIS:RG2',
      'IIS:VID',
      'IIS:SVD',
      'VPM:DYN',
      'VPM:USR',
      'OBC:0',
      'OBC:3',
      'MLO:0',
      'MLO:2',
      'OIL:0',
      'OIL:5',
      'VXX:SEFS1=2.5',
      'VXX:SEFS2=10.0',
    ];
    for (final cmd in commands) {
      expect(commandLabel(cmd), isNot(cmd), reason: cmd);
    }
    expect(commandLabel('VXX:LNSI0=+00012'), 'Lens Calibration');
  });

  test('unknown commands fall through unchanged', () {
    expect(commandLabel('VXX:GMMI0=+00010'), 'VXX:GMMI0=+00010');
  });
}
