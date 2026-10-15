import 'ip_sort.dart';

/// A run of consecutive IPv4 addresses in one /24 (`192.168.0.10` to
/// `192.168.0.49`); a single address is a run of one.
class IpRun {
  const IpRun(this.first, this.last, this.length);

  final String first;
  final String last;
  final int length;

  /// `192.168.0.10 to .49`, or `.10 to .49` with [short] (the prefix is
  /// shown elsewhere, e.g. the IP range tab's skip list).
  String label({bool short = false}) {
    final firstText = short ? '.${_lastOctet(first)}' : first;
    if (length == 1) return firstText;
    return '$firstText to .${_lastOctet(last)}';
  }

  @override
  bool operator ==(Object other) =>
      other is IpRun &&
      other.first == first &&
      other.last == last &&
      other.length == length;

  @override
  int get hashCode => Object.hash(first, last, length);

  @override
  String toString() => label();
}

/// Sorts [ips] numerically and joins consecutive addresses that share their
/// first three octets into one run. Duplicates count once; a string that
/// isn't a dotted quad stays a run of its own.
List<IpRun> collapseIpRanges(Iterable<String> ips) {
  final sorted = ips.toSet().toList()
    ..sort((a, b) => ipSortKey(a).compareTo(ipSortKey(b)));
  final runs = <IpRun>[];
  for (final ip in sorted) {
    final prev = runs.isEmpty ? null : runs.last;
    if (prev != null && _follows(prev.last, ip)) {
      runs[runs.length - 1] = IpRun(prev.first, ip, prev.length + 1);
    } else {
      runs.add(IpRun(ip, ip, 1));
    }
  }
  return runs;
}

bool _follows(String a, String b) {
  final pa = _octets(a);
  final pb = _octets(b);
  if (pa == null || pb == null) return false;
  return pa[0] == pb[0] &&
      pa[1] == pb[1] &&
      pa[2] == pb[2] &&
      pb[3] == pa[3] + 1;
}

List<int>? _octets(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return null;
  final values = parts.map(int.tryParse).toList();
  if (values.any((v) => v == null || v < 0 || v > 255)) return null;
  return values.cast<int>();
}

String _lastOctet(String ip) => ip.split('.').last;
