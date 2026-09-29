/// Pure parsers for the raw NTCONTROL telemetry replies gathered by
/// `PanasonicProtocolService.pollProjectorTelemetry`. Each takes the reply
/// (null = the query failed at the transport level) and the node's current
/// display value, which is kept on a transport failure rather than guessing.
library;

import 'projector_node.dart';

/// Inserts thousands separators: `2185` → `2,185`. No `intl` dependency for
/// one call site.
String groupThousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String mapInputCode(String input) => switch (input) {
  'HD1' => 'HDMI 1',
  'HD2' => 'HDMI 2',
  'SD1' => 'SDI 1',
  'SD2' => 'SDI 2',
  'DL1' => 'DIGITAL LINK',
  'DVI' => 'DVI-D',
  'DP1' => 'DISPLAY PORT',
  'RG1' => 'COMPUTER 1',
  'RG2' => 'COMPUTER 2',
  'VID' => 'VIDEO',
  'SVD' => 'Y/C',
  _ => input,
};

// The web status page uses its own compact spelling for INPUT — confirmed
// as `HDMI1` (see REMOTE_PREVIEW_PLAN.md §3.4), not NTCONTROL's short codes
// (`HD1`) that mapInputCode handles, so that map's default case was
// passing it through unchanged — "HDMI1" in the Monitoring table right
// next to NTCONTROL-sourced rows reading "HDMI 1". Reuses mapInputCode
// for the handful of names that do match verbatim (e.g. if a firmware
// variant reports NTCONTROL-style codes here too), then normalizes the
// common "LETTERSdigits" compact style into this app's "LETTERS digits"
// one used everywhere else.
String mapWebInputLabel(String input) {
  final mapped = mapInputCode(input);
  if (mapped != input) return mapped;
  final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(input);
  return m != null ? '${m.group(1)} ${m.group(2)}' : input;
}

/// Parses `QVX:POWI1`'s `POWI1=+0000N` reply into a [PowerStatus]. Returns
/// null for a transport failure or any unrecognized reply, so callers fall
/// back to the last known status instead of guessing one.
PowerStatus? parsePowerStatus(String? raw) {
  final suffix = raw?.split('=').last.trim();
  return switch (suffix) {
    '+00001' => PowerStatus.standby,
    '+00002' => PowerStatus.turningOn,
    '+00003' => PowerStatus.on,
    '+00004' => PowerStatus.cooling,
    _ => null,
  };
}

/// Strips the `NSGS1=` key from a `QVX:NSGS1` reply; null stays null.
String? stripSignalKey(String? raw) => raw?.replaceAll('NSGS1=', '').trim();

/// [raw] is the already key-stripped signal (see [stripSignalKey]).
String formatSignal(String? raw, {required String fallback}) {
  if (raw == null) return fallback;
  return raw.isEmpty || raw == 'ER401' ? 'NO SIGNAL' : raw;
}

/// `QVX:RTMS1` replies `RTMS1=<hours>`.
String formatRuntime(String? raw, {required String fallback}) {
  final value = raw?.replaceAll('RTMS1=', '').trim();
  if (value == null) return fallback;
  final hours = int.tryParse(value);
  if (hours != null) return '${groupThousands(hours)}H';
  return value.isEmpty || value == 'ER401' ? '-' : '${value}H';
}

/// The `QVX:LRTS3=00` reply carries the light-source on-time in hours after
/// the last ':', same unit as RTMS1 (e.g. `LRTS3=00:1577`). Lamp models
/// answer ER401 (no ':') and garbage has no digits → `-`.
String formatLightRuntime(String? raw, {required String fallback}) {
  final value = raw?.trim();
  if (value == null) return fallback;
  final colon = value.lastIndexOf(':');
  final hours = colon < 0
      ? null
      : int.tryParse(value.substring(colon + 1).trim());
  return hours == null ? '-' : '${groupThousands(hours)}H';
}

/// Formats a raw `QTM` temperature reading. The usual reply is a
/// `<celsius>/<fahrenheit>` pair whose Celsius half carries a 2-char prefix
/// that gets stripped; some non-standard firmware sends a single bare value.
/// An `ERxxx` code or an empty reply renders as `-` rather than e.g.
/// `ER401°C`, and a Celsius segment shorter than the prefix doesn't throw.
String formatTemperature(String? raw, {required String fallback}) {
  if (raw == null) return fallback;
  final celsius = raw.contains('/') ? raw.split('/').first : raw;
  final value = raw.contains('/') && celsius.length > 2
      ? celsius.substring(2)
      : celsius;
  return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value) ? '$value°C' : '-';
}

/// `QVX:VMOI2` replies `VMOI2=<code><volts>`: a 3-char prefix before the
/// voltage on most firmware, just the 3-digit voltage on some.
String formatVoltage(String? raw, {required String fallback}) {
  final value = raw?.replaceAll('VMOI2=', '').trim();
  if (value == null) return fallback;
  if (value != 'ER401' && value.length > 3) return '${value.substring(3)}V';
  if (value.length == 3) return '${value}V';
  return '-';
}

/// `QVX:ERRS2` replies `ERRS2=` with nothing after it when healthy.
String formatErrors(String? raw, {required String fallback}) {
  final value = raw?.replaceAll('ERRS2=', '').trim();
  if (value == null) return fallback;
  return value.isEmpty ? 'NO ERRORS' : value;
}
