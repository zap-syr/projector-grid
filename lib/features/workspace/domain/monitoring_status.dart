/// What the Monitoring view says about a projector's health: its problems
/// (the Errors badge, the panel's Needs attention section), the row accent
/// level and the group rows' summary line.
library;

import 'package:flutter/foundation.dart';

import 'alert_rule.dart';
import 'alerts.dart';
import 'projector_errors.dart';
import 'projector_node.dart';

/// The row accent and card border: amber [warning], red [error], grey
/// [offline].
enum ProblemLevel { none, warning, error, offline }

/// Where a problem comes from. Only [projectorError] is the projector's own
/// fault; the table's Errors column shows those alone, the others have a
/// column of their own (Signal, Temperature, Connection, Projector).
enum ProblemKind { offline, login, projectorError, temperature, signal }

class MonitoringProblem {
  final ProblemLevel level;
  final ProblemKind kind;

  /// Short, for a badge: `Exhaust hot`, `Error F305`, `Warning H001`,
  /// `Offline`.
  final String badge;

  /// The panel's row label: `Exhaust temperature`, `Fan error`.
  final String title;

  /// The panel's row value: `52 °C, above 50 °C`, `F305`.
  final String value;

  /// Shortest, for the corner of a compact tile: `52 °C`, `F305`.
  final String flag;

  /// When the alert behind it started; null without one (the rule is off).
  final DateTime? since;

  const MonitoringProblem({
    required this.level,
    required this.kind,
    required this.badge,
    required this.title,
    required this.value,
    required this.flag,
    this.since,
  });

  @override
  bool operator ==(Object other) =>
      other is MonitoringProblem &&
      other.level == level &&
      other.kind == kind &&
      other.badge == badge &&
      other.title == title &&
      other.value == value &&
      other.flag == flag &&
      other.since == since;

  @override
  int get hashCode =>
      Object.hash(level, kind, badge, title, value, flag, since);
}

/// One projector as Monitoring reads it. Value equality, so a widget
/// selecting it rebuilds only when something it shows changes.
class MonitoringStatus {
  final ProblemLevel level;

  /// Worst first.
  final List<MonitoringProblem> problems;

  /// Answers polls with a working login.
  final bool online;

  /// Online and in standby.
  final bool standby;

  /// The temperature alerts' severities, which tint the bars.
  final AlertSeverity? intake;
  final AlertSeverity? exhaust;

  const MonitoringStatus({
    this.level = ProblemLevel.none,
    this.problems = const [],
    this.online = false,
    this.standby = false,
    this.intake,
    this.exhaust,
  });

  @override
  bool operator ==(Object other) =>
      other is MonitoringStatus &&
      other.level == level &&
      listEquals(other.problems, problems) &&
      other.online == online &&
      other.standby == standby &&
      other.intake == intake &&
      other.exhaust == exhaust;

  @override
  int get hashCode => Object.hash(
    level,
    Object.hashAll(problems),
    online,
    standby,
    intake,
    exhaust,
  );
}

/// [node]'s status from its own state and its active [alerts] (only that
/// node's). Errors come from the projector's own report, so they show even
/// with the Projector error rule off; temperatures and Signal lost need
/// their alert, which carries the hysteresis and the latch. An offline
/// projector shows Offline alone: its other values are the last ones it
/// sent.
MonitoringStatus monitoringStatusOf(
  ProjectorNode node,
  Iterable<ActiveAlert> alerts,
  AlertSettings settings,
) {
  final online =
      node.connectionStatus == ConnectionStatus.connected ||
      node.connectionStatus == ConnectionStatus.unprotected;
  final standby = online && node.powerStatus == PowerStatus.standby;

  // `polled`: a project that was just opened is offline by default until
  // the first poll has asked.
  if (node.polled && node.connectionStatus == ConnectionStatus.offline) {
    final since = alerts
        .where((a) => a.rule == AlertRule.offline)
        .firstOrNull
        ?.since;
    return MonitoringStatus(
      level: ProblemLevel.offline,
      problems: [
        MonitoringProblem(
          level: ProblemLevel.offline,
          kind: ProblemKind.offline,
          badge: 'Offline',
          title: 'Offline',
          value: 'No answer',
          flag: 'Offline',
          since: since,
        ),
      ],
    );
  }

  final problems = <MonitoringProblem>[];
  AlertSeverity? intake, exhaust;

  if (node.connectionStatus == ConnectionStatus.unauthorized) {
    problems.add(
      const MonitoringProblem(
        level: ProblemLevel.warning,
        kind: ProblemKind.login,
        badge: 'Wrong login',
        title: 'Wrong login',
        value: 'Check the login',
        flag: 'Login',
      ),
    );
  }

  final errorSince = {
    for (final a in alerts)
      if (a.rule == AlertRule.error) a.item: a.since,
  };
  for (final e in decodeProjectorErrors(node.errors)) {
    problems.add(
      MonitoringProblem(
        level: _levelOf(e.severity),
        kind: ProblemKind.projectorError,
        // An amber code is the projector's warning, not a fault.
        badge: e.severity == AlertSeverity.critical
            ? 'Error ${e.id}'
            : 'Warning ${e.id}',
        title: e.name ?? 'Projector error',
        value: e.id,
        flag: e.id,
        since: errorSince[e.id],
      ),
    );
  }

  for (final a in alerts) {
    if (a.recovered) continue;
    switch (a.rule) {
      case AlertRule.intakeTemp || AlertRule.exhaustTemp:
        final isIntake = a.rule == AlertRule.intakeTemp;
        final t = isIntake ? settings.intake : settings.exhaust;
        final limit = a.severity == AlertSeverity.critical ? t.hot : t.warm;
        if (isIntake) {
          intake = a.severity;
        } else {
          exhaust = a.severity;
        }
        problems.add(
          MonitoringProblem(
            level: _levelOf(a.severity),
            kind: ProblemKind.temperature,
            badge: isIntake ? 'Intake hot' : 'Exhaust hot',
            title: a.rule.label,
            value: '${a.value}, above ${formatCelsius(limit)}',
            flag: a.value,
            since: a.since,
          ),
        );
      case AlertRule.signalLost:
        problems.add(
          MonitoringProblem(
            level: _levelOf(a.severity),
            kind: ProblemKind.signal,
            badge: 'Signal lost',
            title: 'Signal lost',
            value: a.value,
            flag: 'No signal',
            since: a.since,
          ),
        );
      case AlertRule.offline || AlertRule.error:
        break;
    }
  }

  // Stable, so equal levels keep the order above (login, errors, alerts).
  mergeSort(
    problems,
    compare: (a, b) => b.level.index.compareTo(a.level.index),
  );
  return MonitoringStatus(
    level: problems.isEmpty ? ProblemLevel.none : problems.first.level,
    problems: List.unmodifiable(problems),
    online: online,
    standby: standby,
    intake: intake,
    exhaust: exhaust,
  );
}

/// The table's Errors column: the projector's own error codes. Signal lost,
/// a hot reading and a wrong login show in their own columns.
List<MonitoringProblem> projectorErrorsOf(MonitoringStatus status) => [
  for (final p in status.problems)
    if (p.kind == ProblemKind.projectorError) p,
];

ProblemLevel _levelOf(AlertSeverity s) =>
    s == AlertSeverity.critical ? ProblemLevel.error : ProblemLevel.warning;

/// A group row's summary: `8 projectors, 7 online, 1 needs attention`.
/// Problems and standby are named only when there are some.
String monitoringGroupSummary(Iterable<MonitoringStatus> members) {
  var total = 0, online = 0, attention = 0, errors = 0, offline = 0;
  var standby = 0;
  for (final m in members) {
    total++;
    if (m.online) online++;
    if (m.standby) standby++;
    switch (m.level) {
      case ProblemLevel.warning:
        attention++;
      case ProblemLevel.error:
        errors++;
      case ProblemLevel.offline:
        offline++;
      case ProblemLevel.none:
        break;
    }
  }
  return [
    '$total ${total == 1 ? 'projector' : 'projectors'}',
    '$online online',
    if (errors > 0) '$errors ${errors == 1 ? 'error' : 'errors'}',
    if (attention > 0)
      '$attention ${attention == 1 ? 'needs' : 'need'} attention',
    if (offline > 0) '$offline offline',
    if (standby > 0) '$standby in standby',
  ].join(', ');
}
