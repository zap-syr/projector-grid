/// What desktop notifications and the alert sound say about a batch of
/// alerts raised close together, as pure functions.
library;

import 'alert_rule.dart';
import 'alerts.dart';

/// Alerts raised within this long of the first one go into one notification
/// (and one sound), so a failed media server gives one, not twenty.
const Duration kAlertBatchWindow = Duration(seconds: 2);

typedef AlertNotice = ({String title, String body, AlertSeverity severity});

/// The [batch]'s raised alerts that [scope] lets through.
List<AlertEvent> noticeable(List<AlertEvent> batch, AlertNotifyScope scope) => [
  for (final e in batch)
    if (e.change == AlertChange.raised &&
        (scope == AlertNotifyScope.all ||
            e.alert.severity == AlertSeverity.critical))
      e,
];

/// One notification for [events] (raised, in order), or null for none.
///
/// One alert: "Exhaust temperature on PRJ-02 (10.0.0.12)", "58 °C since
/// 14:02". More: the most common rule leads (critical before warning):
/// "Offline on 20 projectors", "PRJ-13 (10.0.0.13), PRJ-14 (10.0.0.14),
/// PRJ-15 (10.0.0.15) and 17 more, plus 2 other alerts".
///
/// Projectors are told apart by node, not name: a rig of one model often
/// has every projector named the same.
AlertNotice? alertNotice(List<AlertEvent> events, DateTime now) {
  if (events.isEmpty) return null;
  final severity = events.any((e) => e.alert.severity == AlertSeverity.critical)
      ? AlertSeverity.critical
      : AlertSeverity.warning;
  if (events.length == 1) {
    final e = events.single;
    return (
      title: '${e.alert.rule.label} on ${_projector(e)}',
      body: '${e.alert.value} since ${formatAlertStart(e.alert.since, now)}',
      severity: severity,
    );
  }

  final byRule = <AlertRule, List<AlertEvent>>{};
  for (final e in events) {
    byRule.putIfAbsent(e.alert.rule, () => []).add(e);
  }
  int rank(List<AlertEvent> g) =>
      g.any((e) => e.alert.severity == AlertSeverity.critical) ? 1 : 0;
  final lead = byRule.values.reduce(
    (a, b) => rank(b) > rank(a) || (rank(b) == rank(a) && b.length > a.length)
        ? b
        : a,
  );
  final names = {for (final e in lead) e.alert.nodeId: _projector(e)}.values
      .toList();
  final others = events.length - lead.length;

  final who = names.length == 1 ? names.single : '${names.length} projectors';
  final listed = names.length > 3
      ? '${names.take(3).join(', ')} and ${names.length - 3} more'
      : names.join(', ');
  final rest = others == 0
      ? ''
      : '${names.length == 1 ? '' : ', '}plus $others other '
            '${others == 1 ? 'alert' : 'alerts'}';
  return (
    title: '${lead.first.alert.rule.label} on $who',
    body: names.length == 1
        ? '${lead.first.alert.value}${rest.isEmpty ? '' : ', $rest'}'
        : '$listed$rest',
    severity: severity,
  );
}

String _projector(AlertEvent e) =>
    e.ip.isEmpty ? e.projector : '${e.projector} (${e.ip})';
