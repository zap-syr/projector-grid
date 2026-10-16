import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/color_correction.dart';

void main() {
  test('QTE replies map to modes and kelvin', () {
    expect(parseColorTemperature('4'), (TempMode.user1, null));
    expect(parseColorTemperature('9'), (TempMode.user2, null));
    expect(parseColorTemperature('10'), (TempMode.defaultTemp, null));
    expect(parseColorTemperature('6550'), (TempMode.custom, 6500));
    expect(parseColorTemperature('ER401'), isNull);
    expect(parseColorTemperature(null), isNull);
  });

  test('RGB triples parse with or without a key', () {
    expect(parseRgbTriple('2048,0096,0000'), [2048, 96, 0]);
    expect(parseRgbTriple('C7CS3=0000,2048,2048'), [0, 2048, 2048]);
    expect(parseRgbTriple('2048,0096'), isNull);
    expect(parseRgbTriple('a,b,c'), isNull);
  });

  test('Color Matching writes', () {
    expect(
      colorMatchingWrite(MatchMethod.three, MatchColor.green, [0, 2048, 96]),
      'VMG:0000,2048,0096',
    );
    expect(
      colorMatchingWrite(MatchMethod.seven, MatchColor.yellow, [1, 2, 3]),
      'VXX:C7CS5=0001,0002,0003',
    );
    expect(colorMatchingQuery(MatchMethod.three, MatchColor.blue), 'QMB');
    expect(
      colorMatchingQuery(MatchMethod.seven, MatchColor.white),
      'QVX:C7CS6',
    );
    expect(MatchMethod.seven.writeCommand, 'VXX:CMAI0=+00002');
  });

  test('temperature and white balance writes', () {
    expect(TempMode.user2.writeCommand(6500), 'OTE:09');
    expect(TempMode.defaultTemp.writeCommand(6500), 'OTE:10');
    expect(TempMode.custom.writeCommand(9300), 'OTE:9300');
    expect(whiteBalanceHighWrite(1, 7), 'VHG:007');
    expect(whiteBalanceLowWrite(2, -15), 'VOB:113');
    expect(whiteBalanceLowWrite(0, -127), 'VOR:001');
  });

  test('white balance reads', () {
    expect(parseWhiteBalanceHigh('300', 0), 255);
    expect(parseWhiteBalanceHigh(null, 42), 42);
    expect(parseWhiteBalanceLow('113', 0), -15);
    expect(parseWhiteBalanceLow(null, 5), 5);
  });

  test('Low snaps to 0 within 3', () {
    expect(snapWhiteBalanceLow(3), 0);
    expect(snapWhiteBalanceLow(-3), 0);
    expect(snapWhiteBalanceLow(4), 4);
  });

  test('defaults decide "changed"', () {
    expect(MatchColor.cyan.isDefault([0, 2048, 2048]), isTrue);
    expect(MatchColor.cyan.isDefault([0, 2048, 2000]), isFalse);
  });
}
