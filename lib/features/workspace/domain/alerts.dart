/// The alert engine as pure functions: what conditions hold for a projector,
/// and how the active list moves from one workspace state to the next.
/// `alertsProvider` only feeds these and fans out the transitions.
library;

import '../../../core/theme/status_thresholds.dart';
import 'alert_rule.dart';
import 'projector_errors.dart';
import 'projector_node.dart';

/// At most one active alert per key: per (projector, rule), and per error
/// item for [AlertRule.error] ([item] is empty for every other rule).
typedef AlertKey = ({String nodeId, AlertRule rule, String item});

/// A condition that holds for a projector right now.
typedef AlertCondition = ({
  AlertRule rule,
  String item,
  AlertSeverity severity,
  String value,
});

class ActiveAlert {
  final String nodeId;
  final AlertRule rule;
  final String item;
  final AlertSeverity severity;

  /// What the operator reads in large type: `58 °C`, `No answer`, the error.
  final String value;

  /// When the condition started; for a restart, the first poll after it.
  final DateTime since;
  final bool acknowledged;

  /// For a latched Signal lost: when the signal came back. The alert stays
  /// until acknowledged.
  final DateTime? restoredAt;

  const ActiveAlert({
    required this.nodeId,
    required this.rule,
    this.item = '',
    required this.severity,
    required this.value,
    required this.since,
    this.acknowledged = false,
    this.restoredAt,
  });

  AlertKey get key => (nodeId: nodeId, rule: rule, item: item);

  ActiveAlert copyWith({
    AlertSeverity? severity,
    String? value,
    bool? acknowledged,
  }) => ActiveAlert(
    nodeId: nodeId,
    rule: rule,
    item: item,
    severity: severity ?? this.severity,
    value: value ?? this.value,
    since: since,
    acknowledged: acknowledged ?? this.acknowledged,
    restoredAt: restoredAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ActiveAlert &&
      other.nodeId == nodeId &&
      other.rule == rule &&
      other.item == item &&
      other.severity == severity &&
      other.value == value &&
      other.since == since &&
      other.acknowledged == acknowledged &&
      other.restoredAt == restoredAt;

  @override
  int get hashCode => Object.hash(
    nodeId,
    rule,
    item,
    severity,
    value,
    since,
    acknowledged,
    restoredAt,
  );
}

enum AlertChange { raised, cleared }

/// [raised] also covers a warning escalating to critical: the operator has
/// to see it again even if the warning was acknowledged.
typedef AlertTransition = ({AlertChange change, ActiveAlert alert});

/// The leading number of a formatted temperature (`58°C`); null for `-` and
/// anything else that isn't a reading.
double? parseCelsius(String display) {
  final m = RegExp(r'^-?\d+(\.\d+)?').firstMatch(display);
  return m == null ? null : double.parse(m.group(0)!);
}

String formatCelsius(double c) =>
    '${c == c.roundToDouble() ? c.toInt() : c} °C';

/// Severity for a temperature [c] against [t], given the alert's [current]
/// severity. Each level trips at its threshold and only clears
/// [kTempHysteresis] below it.
AlertSeverity? temperatureSeverity(
  double c,
  TempThreshold t,
  AlertSeverity? current,
) {
  bool holds(double threshold, bool wasOn) =>
      c >= threshold || (wasOn && c > threshold - kTempHysteresis);
  if (holds(t.hot, current == AlertSeverity.critical)) {
    return AlertSeverity.critical;
  }
  if (holds(t.warm, current != null)) return AlertSeverity.warning;
  return null;
}

/// Conditions that hold for [node]. [current] gives the node's existing
/// alert for a rule, which temperature hysteresis needs.
List<AlertCondition> evaluateNode(
  ProjectorNode node,
  AlertSettings settings,
  ActiveAlert? Function(AlertRule rule) current,
) {
  final conditions = <AlertCondition>[];

  // `polled` keeps a just-loaded project, still offline by default, from
  // raising Offline for every projector before the first poll has run.
  if (settings.isEnabled(AlertRule.offline) &&
      node.polled &&
      node.connectionStatus == ConnectionStatus.offline) {
    conditions.add((
      rule: AlertRule.offline,
      item: '',
      severity: AlertSeverity.critical,
      value: 'No answer',
    ));
  }

  if (settings.isEnabled(AlertRule.error)) {
    for (final e in decodeProjectorErrors(node.errors)) {
      conditions.add((
        rule: AlertRule.error,
        item: e.id,
        severity: e.severity,
        value: e.label,
      ));
    }
  }

  void temperature(AlertRule rule, String display, TempThreshold t) {
    if (!settings.isEnabled(rule)) return;
    final c = parseCelsius(display);
    final old = current(rule);
    if (c == null) {
      // No reading (offline, query failed) says nothing about the
      // condition: keep the alert as it was rather than clearing it.
      if (old != null) {
        conditions.add((
          rule: rule,
          item: '',
          severity: old.severity,
          value: old.value,
        ));
      }
      return;
    }
    final severity = temperatureSeverity(c, t, old?.severity);
    if (severity == null) return;
    conditions.add((
      rule: rule,
      item: '',
      severity: severity,
      value: formatCelsius(c),
    ));
  }

  temperature(AlertRule.intakeTemp, node.intakeTemp, settings.intake);
  temperature(AlertRule.exhaustTemp, node.exhaustTemp, settings.exhaust);

  return conditions;
}

/// Moves the active list from [previous] to what [nodes] say now. Alerts of
/// removed projectors and switched-off rules clear like any other.
({Map<AlertKey, ActiveAlert> active, List<AlertTransition> transitions})
reconcileAlerts({
  required Map<AlertKey, ActiveAlert> previous,
  required Iterable<ProjectorNode> nodes,
  required AlertSettings settings,
  required DateTime now,
}) {
  final active = <AlertKey, ActiveAlert>{};
  final transitions = <AlertTransition>[];

  for (final node in nodes) {
    final conditions = evaluateNode(
      node,
      settings,
      (rule) => previous[(nodeId: node.id, rule: rule, item: '')],
    );
    for (final c in conditions) {
      final key = (nodeId: node.id, rule: c.rule, item: c.item);
      final old = previous[key];
      if (old == null) {
        final alert = ActiveAlert(
          nodeId: node.id,
          rule: c.rule,
          item: c.item,
          severity: c.severity,
          value: c.value,
          since: now,
        );
        active[key] = alert;
        transitions.add((change: AlertChange.raised, alert: alert));
      } else if (c.severity.index > old.severity.index) {
        final alert = old.copyWith(
          severity: c.severity,
          value: c.value,
          acknowledged: false,
        );
        active[key] = alert;
        transitions.add((change: AlertChange.raised, alert: alert));
      } else {
        active[key] = old.copyWith(severity: c.severity, value: c.value);
      }
    }
  }

  for (final old in previous.values) {
    if (!active.containsKey(old.key)) {
      transitions.add((change: AlertChange.cleared, alert: old));
    }
  }

  return (active: active, transitions: transitions);
}

/// Display order: unacknowledged first, then critical before warning, then
/// newest first.
List<ActiveAlert> sortAlerts(Iterable<ActiveAlert> alerts) =>
    alerts.toList()..sort((a, b) {
      if (a.acknowledged != b.acknowledged) return a.acknowledged ? 1 : -1;
      if (a.severity != b.severity) {
        return b.severity.index.compareTo(a.severity.index);
      }
      return b.since.compareTo(a.since);
    });
