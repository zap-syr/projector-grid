import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/ip_input.dart';

void main() {
  test('isValidIpv4 and parsePort', () {
    expect(isValidIpv4('192.168.0.10'), isTrue);
    expect(isValidIpv4('192.168.0.256'), isFalse);
    expect(isValidIpv4('192.168.0'), isFalse);
    expect(parsePort('1024'), 1024);
    expect(parsePort('0'), isNull);
    expect(parsePort('65536'), isNull);
    expect(parsePort(''), isNull);
  });

  group('checkIp', () {
    const taken = {'10.0.0.2'};

    test('Add Projectors states', () {
      expect(checkIp('', taken), IpCheck.empty);
      expect(checkIp('10.0.0', taken), IpCheck.invalid);
      expect(checkIp('10.0.0.2', taken), IpCheck.taken);
      expect(checkIp(' 10.0.0.3 ', taken), IpCheck.free);
    });

    test('Edit Projector keeps its own address as unchanged', () {
      expect(
        checkIp('10.0.0.1', taken, original: '10.0.0.1'),
        IpCheck.unchanged,
      );
      expect(checkIp('10.0.0.2', taken, original: '10.0.0.1'), IpCheck.taken);
      expect(checkIp('10.0.0.5', taken, original: '10.0.0.1'), IpCheck.free);
    });
  });

  test('ipPrefix needs three valid octets', () {
    expect(ipPrefix('192.168.0.10'), '192.168.0.');
    expect(ipPrefix('192.168.0.'), '192.168.0.');
    expect(ipPrefix('192.168.0'), isNull);
    expect(ipPrefix('192.300.0.1'), isNull);
  });

  group('parseIpRange', () {
    test('a valid range lists its addresses', () {
      final r = parseIpRange('192.168.0.10', '13') as IpRangeValid;
      expect(r.length, 4);
      expect(r.addresses, [
        '192.168.0.10',
        '192.168.0.11',
        '192.168.0.12',
        '192.168.0.13',
      ]);
    });

    test('To below From is reversed, half typed is incomplete', () {
      expect(parseIpRange('192.168.0.10', '9'), isA<IpRangeReversed>());
      expect(parseIpRange('192.168.0.10', ''), isA<IpRangeIncomplete>());
      expect(parseIpRange('192.168.0', '20'), isA<IpRangeIncomplete>());
      expect(parseIpRange('192.168.0.10', '256'), isA<IpRangeIncomplete>());
    });
  });

  test('rangeAxisTicks: ends plus round values about six apart', () {
    expect(rangeAxisTicks(10, 59), [10, 20, 30, 40, 50, 59]);
    expect(rangeAxisTicks(0, 255), [0, 50, 100, 150, 200, 255]);
    // .20 would sit on top of .17.
    expect(rangeAxisTicks(17, 49), [17, 30, 40, 49]);
  });
}
