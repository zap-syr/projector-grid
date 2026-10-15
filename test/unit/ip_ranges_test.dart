import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/ip_ranges.dart';

void main() {
  List<String> labels(Iterable<String> ips, {bool short = false}) =>
      collapseIpRanges(ips).map((r) => r.label(short: short)).toList();

  test('consecutive addresses become one run', () {
    expect(labels(['192.168.0.12', '192.168.0.10', '192.168.0.11']), [
      '192.168.0.10 to .12',
    ]);
  });

  test('a gap splits runs; a lone address stays full', () {
    expect(labels(['192.168.0.10', '192.168.0.11', '192.168.0.15']), [
      '192.168.0.10 to .11',
      '192.168.0.15',
    ]);
  });

  test('sorts numerically, not as text', () {
    expect(labels(['10.0.0.10', '10.0.0.9', '10.0.0.100']), [
      '10.0.0.9 to .10',
      '10.0.0.100',
    ]);
  });

  test('a run never crosses a /24', () {
    expect(labels(['192.168.0.255', '192.168.1.0']), [
      '192.168.0.255',
      '192.168.1.0',
    ]);
  });

  test('duplicates count once', () {
    final runs = collapseIpRanges(['10.0.0.1', '10.0.0.1', '10.0.0.2']);
    expect(runs.single.length, 2);
  });

  test('short labels drop the prefix', () {
    expect(
      labels([
        '192.168.0.31',
        '192.168.0.32',
        '192.168.0.33',
        '192.168.0.40',
      ], short: true),
      ['.31 to .33', '.40'],
    );
  });

  test('60 projectors in a few runs', () {
    final ips = [
      for (var i = 10; i <= 49; i++) '192.168.0.$i',
      for (var i = 20; i <= 35; i++) '192.168.1.$i',
      '192.168.2.1',
      '192.168.2.5',
      '192.168.2.9',
      '192.168.2.12',
    ];
    final runs = collapseIpRanges(ips);
    expect(runs.length, 6);
    expect(runs.first.label(), '192.168.0.10 to .49');
    expect(runs[1].label(), '192.168.1.20 to .35');
    expect(runs.fold(0, (n, r) => n + r.length), 60);
  });

  test('a string that is not an IPv4 address stays its own run', () {
    expect(
      labels(['projector.local', '10.0.0.1']),
      unorderedEquals(['10.0.0.1', 'projector.local']),
    );
  });
}
