import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/telemetry_parsing.dart';

void main() {
  group('formatRuntime', () {
    test('groups thousands', () {
      expect(formatRuntime('RTMS1=2185', fallback: 'x'), '2,185H');
      expect(formatRuntime('RTMS1=7864320', fallback: 'x'), '7,864,320H');
      expect(formatRuntime('RTMS1=12', fallback: 'x'), '12H');
    });
    test('ER401 and empty render as -', () {
      expect(formatRuntime('ER401', fallback: 'x'), '-');
      expect(formatRuntime('RTMS1=', fallback: 'x'), '-');
    });
    test('transport failure keeps the last known value', () {
      expect(formatRuntime(null, fallback: '1,000H'), '1,000H');
    });
  });

  group('formatLightRuntime', () {
    test('parses after the last colon', () {
      expect(formatLightRuntime('LRTS3=00:1577', fallback: 'x'), '1,577H');
      expect(formatLightRuntime('LRTS3=00:0', fallback: 'x'), '0H');
    });
    test('lamp models (ER401, no colon) render as -', () {
      expect(formatLightRuntime('ER401', fallback: 'x'), '-');
    });
    test('non-numeric tail renders as -', () {
      expect(formatLightRuntime('LRTS3=00:abc', fallback: 'x'), '-');
    });
    test('transport failure keeps the last known value', () {
      expect(formatLightRuntime(null, fallback: '5H'), '5H');
    });
  });

  group('formatErrors', () {
    test('empty ERRS2 means no errors', () {
      expect(formatErrors('ERRS2=', fallback: 'x'), 'NO ERRORS');
    });
    test('non-empty value is passed through', () {
      expect(formatErrors('ERRS2=000100000000', fallback: 'x'), '000100000000');
    });
    test('transport failure keeps the last known value', () {
      expect(formatErrors(null, fallback: 'NO ERRORS'), 'NO ERRORS');
    });
  });

  group('formatVoltage', () {
    test('strips the 3-char +00 prefix', () {
      expect(formatVoltage('VMOI2=+00230', fallback: 'x'), '230V');
      expect(formatVoltage('VMOI2=+00120', fallback: 'x'), '120V');
    });
    test('bare 3-digit value', () {
      expect(formatVoltage('VMOI2=230', fallback: 'x'), '230V');
    });
    test('ER401 and too-short values render as -', () {
      expect(formatVoltage('ER401', fallback: 'x'), '-');
      expect(formatVoltage('VMOI2=12', fallback: 'x'), '-');
      expect(formatVoltage('VMOI2=', fallback: 'x'), '-');
    });
    test('transport failure keeps the last known value', () {
      expect(formatVoltage(null, fallback: '230V'), '230V');
    });
  });

  group('formatTemperature', () {
    test('celsius/fahrenheit pair drops the 2-char prefix', () {
      expect(formatTemperature('0030/0086', fallback: 'x'), '30°C');
      expect(formatTemperature('0041/0106', fallback: 'x'), '41°C');
    });
    test('single bare value', () {
      expect(formatTemperature('025', fallback: 'x'), '025°C');
    });
    test('short celsius segment does not throw', () {
      expect(formatTemperature('3/86', fallback: 'x'), '3°C');
    });
    test('ER codes and empty render as -', () {
      expect(formatTemperature('ER401', fallback: 'x'), '-');
      expect(formatTemperature('', fallback: 'x'), '-');
    });
    test('transport failure keeps the last known value', () {
      expect(formatTemperature(null, fallback: '30°C'), '30°C');
    });
  });

  group('signal', () {
    test('strips the NSGS1 key', () {
      expect(stripSignalKey('NSGS1=1080/60p'), '1080/60p');
      expect(stripSignalKey(null), isNull);
    });
    test('empty and ER401 are NO SIGNAL', () {
      expect(formatSignal('', fallback: 'x'), 'NO SIGNAL');
      expect(formatSignal('ER401', fallback: 'x'), 'NO SIGNAL');
      expect(formatSignal('1080/60p', fallback: 'x'), '1080/60p');
    });
    test('transport failure keeps the last known value', () {
      expect(formatSignal(null, fallback: '4K/60p'), '4K/60p');
    });
    test('isUnusableSignalValue', () {
      for (final v in [
        null,
        '',
        '-',
        'Timeout',
        'ER401',
        'NO SIGNAL',
        'no signal',
      ]) {
        expect(isUnusableSignalValue(v), isTrue, reason: '$v');
      }
      expect(isUnusableSignalValue('1080/60p'), isFalse);
    });
  });

  group('parsePowerStatus', () {
    test('maps the four POWI1 states', () {
      expect(parsePowerStatus('POWI1=+00001'), PowerStatus.standby);
      expect(parsePowerStatus('POWI1=+00002'), PowerStatus.turningOn);
      expect(parsePowerStatus('POWI1=+00003'), PowerStatus.on);
      expect(parsePowerStatus('POWI1=+00004'), PowerStatus.cooling);
    });
    test('unknown or missing is null so callers keep the last state', () {
      expect(parsePowerStatus(null), isNull);
      expect(parsePowerStatus('ER401'), isNull);
      expect(parsePowerStatus('POWI1=+00009'), isNull);
    });
  });

  group('input labels', () {
    test('NTCONTROL codes', () {
      expect(mapInputCode('HD1'), 'HDMI 1');
      expect(mapInputCode('DL1'), 'DIGITAL LINK');
      expect(mapInputCode('SVD'), 'Y/C');
      expect(mapInputCode('XYZ'), 'XYZ');
    });
    test('web UI compact spelling', () {
      expect(mapWebInputLabel('HDMI1'), 'HDMI 1');
      expect(mapWebInputLabel('SDI2'), 'SDI 2');
      expect(mapWebInputLabel('HD1'), 'HDMI 1');
      expect(mapWebInputLabel('DIGITAL LINK'), 'DIGITAL LINK');
    });
  });

  test('groupThousands', () {
    expect(groupThousands(0), '0');
    expect(groupThousands(999), '999');
    expect(groupThousands(1000), '1,000');
    expect(groupThousands(1234567), '1,234,567');
  });
}
