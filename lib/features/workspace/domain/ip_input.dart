/// Parsing and checks behind the Add Projectors and Edit Projector address
/// fields, kept out of the widgets so they can be unit tested.
library;

final _ipv4 = RegExp(
  r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
  r'(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
);

bool isValidIpv4(String text) => _ipv4.hasMatch(text);

const defaultNtcontrolPort = 1024;

/// The port typed into a Port field, or null when it isn't 1 to 65535.
int? parsePort(String text) {
  final port = int.tryParse(text);
  if (port == null || port < 1 || port > 65535) return null;
  return port;
}

/// What the inline check under an IP address field says.
enum IpCheck {
  empty,
  invalid,

  /// Another projector in the project has it.
  taken,

  /// Valid and not in the project.
  free,

  /// Edit Projector: still the address the projector had.
  unchanged,
}

/// [taken] holds every address in the project except, for Edit Projector,
/// the edited projector's own [original].
IpCheck checkIp(String text, Set<String> taken, {String? original}) {
  final ip = text.trim();
  if (ip.isEmpty) return IpCheck.empty;
  if (!isValidIpv4(ip)) return IpCheck.invalid;
  if (ip == original) return IpCheck.unchanged;
  if (taken.contains(ip)) return IpCheck.taken;
  return IpCheck.free;
}

/// `192.168.0.` from a full or partly typed address, or null until the first
/// three octets are valid. The IP range tab shows it before the To field,
/// where only the last octet is typed.
String? ipPrefix(String text) {
  final parts = text.trim().split('.');
  if (parts.length < 4) return null;
  final head = parts.take(3).map(int.tryParse).toList();
  if (head.any((o) => o == null || o < 0 || o > 255)) return null;
  return '${head.join('.')}.';
}

/// The addresses of an IP range tab: [from] up to the last octet [toText]
/// in the same /24.
sealed class IpRangeInput {
  const IpRangeInput();
}

class IpRangeIncomplete extends IpRangeInput {
  const IpRangeIncomplete();
}

/// To is below From.
class IpRangeReversed extends IpRangeInput {
  const IpRangeReversed(this.firstOctet);
  final int firstOctet;
}

class IpRangeValid extends IpRangeInput {
  const IpRangeValid({
    required this.prefix,
    required this.firstOctet,
    required this.lastOctet,
  });

  final String prefix;
  final int firstOctet;
  final int lastOctet;

  int get length => lastOctet - firstOctet + 1;

  List<String> get addresses => [
    for (var o = firstOctet; o <= lastOctet; o++) '$prefix$o',
  ];
}

IpRangeInput parseIpRange(String from, String toText) {
  final start = from.trim();
  final to = int.tryParse(toText.trim());
  if (!isValidIpv4(start) || to == null || to > 255) {
    return const IpRangeIncomplete();
  }
  final first = int.parse(start.split('.').last);
  if (to < first) return IpRangeReversed(first);
  return IpRangeValid(
    prefix: ipPrefix(start)!,
    firstOctet: first,
    lastOctet: to,
  );
}

/// Last octets labelled under the dense preview strip: both ends, and round
/// values in between spaced so about six labels fit (`.10 .20 .30 .40 .50
/// .59`).
List<int> rangeAxisTicks(int first, int last) {
  if (first == last) return [first];
  final span = last - first;
  final step = ((span / 6) / 10).ceil().clamp(1, 26) * 10;
  final ticks = [first];
  for (var v = (first ~/ step + 1) * step; v < last; v += step) {
    // A round value right next to an end would print over it.
    if (v - first < step / 2 || last - v < step / 2) continue;
    ticks.add(v);
  }
  ticks.add(last);
  return ticks;
}
