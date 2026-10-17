/// Display text and bar geometry of the Monitoring view.
library;

import '../../../core/theme/status_thresholds.dart';
import 'alerts.dart';
import 'projector_node.dart';

/// A telemetry display value with a space before its unit and hours in
/// lower case: `1,644H` → `1,644 h`, `25°C` → `25 °C`, `230V` → `230 V`.
/// Anything else (`-`, `Timeout`) as it is.
String withUnit(String display) {
  final m = RegExp(r'^(-?[\d,.]+)\s*(°C|H|V)$').firstMatch(display.trim());
  if (m == null) return display;
  final unit = m.group(2) == 'H' ? 'h' : m.group(2)!;
  return '${m.group(1)} $unit';
}

String powerLabel(PowerStatus s) => switch (s) {
  PowerStatus.on => 'On',
  PowerStatus.turningOn => 'Warming up',
  PowerStatus.cooling => 'Cooling',
  PowerStatus.standby => 'Standby',
};

String shutterLabel(ShutterStatus s) =>
    s == ShutterStatus.open ? 'Open' : 'Closed';

/// `last seen 16:41` under an offline projector's model (`Sep 30 16:41`
/// before today); null while it answers or when it hasn't this session.
String? lastSeenLabel(ProjectorNode node, DateTime now) {
  final at = node.lastSeen;
  if (at == null || node.connectionStatus != ConnectionStatus.offline) {
    return null;
  }
  return 'last seen ${formatAlertStart(at, now)}';
}

/// The top of a temperature bar's scale: a quarter above the critical
/// threshold, so the warning mark sits well inside the bar.
double temperatureScaleMax(TempThreshold t) => t.hot * 1.25;

/// How full a temperature bar is for [display] (`25°C`); null without a
/// reading.
double? temperatureFraction(String display, TempThreshold t) {
  final c = parseCelsius(display);
  if (c == null) return null;
  return (c / temperatureScaleMax(t)).clamp(0.0, 1.0);
}

/// Where the warning threshold mark sits on the bar.
double thresholdFraction(TempThreshold t) => t.warm / temperatureScaleMax(t);
