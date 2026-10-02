import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/status_thresholds.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_errors.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';

ProjectorNode _node({
  String id = '1',
  ConnectionStatus status = ConnectionStatus.connected,
  bool polled = true,
  String errors = 'NO ERRORS',
  String intake = '30°C',
  String exhaust = '40°C',
}) => ProjectorNode(
  id: id,
  name: 'PRJ-$id',
  ipAddress: '10.0.0.$id',
  x: 0,
  y: 0,
  connectionStatus: status,
  polled: polled,
  errors: errors,
  intakeTemp: intake,
  exhaustTemp: exhaust,
);

final _t0 = DateTime(2026, 10, 2, 14);

/// Runs [states] through reconcile one after another, as successive polls.
({Map<AlertKey, ActiveAlert> active, List<AlertTransition> transitions}) _run(
  List<List<ProjectorNode>> states, {
  AlertSettings settings = const AlertSettings(),
}) {
  var active = <AlertKey, ActiveAlert>{};
  var transitions = <AlertTransition>[];
  for (final (i, nodes) in states.indexed) {
    final r = reconcileAlerts(
      previous: active,
      nodes: nodes,
      settings: settings,
      now: _t0.add(Duration(minutes: i)),
    );
    active = r.active;
    transitions = r.transitions;
  }
  return (active: active, transitions: transitions);
}

void main() {
  group('parseCelsius / formatCelsius', () {
    test('reads the leading number', () {
      expect(parseCelsius('58°C'), 58);
      expect(parseCelsius('41.5°C'), 41.5);
      expect(parseCelsius('-3°C'), -3);
      expect(parseCelsius('-'), isNull);
      expect(parseCelsius('Timeout'), isNull);
    });

    test('drops a whole-number decimal', () {
      expect(formatCelsius(58), '58 °C');
      expect(formatCelsius(41.5), '41.5 °C');
    });
  });

  group('temperatureSeverity', () {
    const t = (warm: 55.0, hot: 65.0);

    test('trips at each threshold', () {
      expect(temperatureSeverity(54, t, null), isNull);
      expect(temperatureSeverity(55, t, null), AlertSeverity.warning);
      expect(temperatureSeverity(65, t, null), AlertSeverity.critical);
    });

    test('clears only the hysteresis below the threshold', () {
      final w = AlertSeverity.warning;
      final c = AlertSeverity.critical;
      expect(temperatureSeverity(53.5, t, w), w);
      expect(temperatureSeverity(55 - kTempHysteresis, t, w), isNull);
      expect(temperatureSeverity(63.5, t, c), c);
      expect(temperatureSeverity(65 - kTempHysteresis, t, c), w);
    });
  });

  group('decodeProjectorErrors', () {
    test('healthy or unknown is empty', () {
      expect(decodeProjectorErrors('NO ERRORS'), isEmpty);
      expect(decodeProjectorErrors('-'), isEmpty);
      expect(decodeProjectorErrors('000000000000'), isEmpty);
    });

    test('names known codes, exact codes before their range', () {
      final items = decodeProjectorErrors('U200,U355 F305');
      expect(items, [
        (
          id: 'U200',
          name: 'Intake air temperature warning',
          severity: AlertSeverity.warning,
        ),
        (
          id: 'U355',
          name: 'AC IN terminal high temperature error',
          severity: AlertSeverity.critical,
        ),
        (id: 'F305', name: 'Fan error', severity: AlertSeverity.critical),
      ]);
      expect(projectorErrorLabel(items.last), 'Fan error (F305)');
    });

    test('an unknown code or a reply without codes comes through raw', () {
      final unknown = decodeProjectorErrors('U999');
      expect(unknown, [
        (id: 'U999', name: null, severity: AlertSeverity.critical),
      ]);
      expect(projectorErrorLabel(unknown.single), 'U999');
      expect(decodeProjectorErrors('000100000000'), [
        (id: '000100000000', name: null, severity: AlertSeverity.critical),
      ]);
    });

    test('sortProjectorErrors: critical first, then newest, no alert last', () {
      final items = decodeProjectorErrors('U200 F305 F011 F306');
      final since = {
        'U200': _t0,
        'F305': _t0,
        'F011': _t0.add(const Duration(minutes: 5)),
      };
      expect(sortProjectorErrors(items, (id) => since[id]).map((e) => e.id), [
        'F011',
        'F305',
        'F306',
        'U200',
      ]);
    });
  });

  group('reconcileAlerts', () {
    test('Offline waits for the first poll', () {
      final notYet = _run([
        [_node(status: ConnectionStatus.offline, polled: false)],
      ]);
      expect(notYet.active, isEmpty);

      final r = _run([
        [_node(status: ConnectionStatus.offline)],
      ]);
      final a = r.active.values.single;
      expect(a.rule, AlertRule.offline);
      expect(a.severity, AlertSeverity.critical);
      expect(r.transitions.single.change, AlertChange.raised);
    });

    test('one Projector error alert per reported error', () {
      final r = _run([
        [_node(errors: 'F011 F200')],
      ]);
      expect(r.active.keys.map((k) => k.item), ['F011', 'F200']);
      expect(r.active.values.every((a) => a.rule == AlertRule.error), isTrue);
      expect(r.active.values.map((a) => a.severity), [
        AlertSeverity.critical,
        AlertSeverity.warning,
      ]);
    });

    test('keeps since and acknowledgement while the condition holds', () {
      var r = _run([
        [_node(exhaust: '58°C')],
      ]);
      final key = r.active.keys.single;
      final acked = {key: r.active[key]!.copyWith(acknowledged: true)};

      r = reconcileAlerts(
        previous: acked,
        nodes: [_node(exhaust: '60°C')],
        settings: const AlertSettings(),
        now: _t0.add(const Duration(minutes: 5)),
      );
      final a = r.active[key]!;
      expect(r.transitions, isEmpty);
      expect(a.value, '60 °C');
      expect(a.since, _t0);
      expect(a.acknowledged, isTrue);
    });

    test('escalation re-raises an acknowledged warning', () {
      final first = _run([
        [_node(exhaust: '58°C')],
      ]);
      final key = first.active.keys.single;
      final r = reconcileAlerts(
        previous: {key: first.active[key]!.copyWith(acknowledged: true)},
        nodes: [_node(exhaust: '66°C')],
        settings: const AlertSettings(),
        now: _t0.add(const Duration(minutes: 1)),
      );
      final a = r.active[key]!;
      expect(a.severity, AlertSeverity.critical);
      expect(a.acknowledged, isFalse);
      expect(a.since, _t0);
      expect(r.transitions.single.change, AlertChange.raised);
    });

    test('a missing reading keeps the alert and its value', () {
      final r = _run([
        [_node(exhaust: '58°C')],
        [_node(status: ConnectionStatus.offline, exhaust: '-')],
      ]);
      final temp = r.active.values.firstWhere(
        (a) => a.rule == AlertRule.exhaustTemp,
      );
      expect(temp.value, '58 °C');
    });

    test(
      'clears when the condition goes, the rule is off or the node is gone',
      () {
        expect(
          _run([
            [_node(exhaust: '58°C')],
            [_node(exhaust: '50°C')],
          ]).transitions.single.change,
          AlertChange.cleared,
        );

        final off = reconcileAlerts(
          previous: _run([
            [_node(exhaust: '58°C')],
          ]).active,
          nodes: [_node(exhaust: '58°C')],
          settings: const AlertSettings(enabled: {AlertRule.offline}),
          now: _t0,
        );
        expect(off.active, isEmpty);
        expect(off.transitions.single.change, AlertChange.cleared);

        expect(
          _run([
            [_node(exhaust: '58°C')],
            [],
          ]).transitions.single.change,
          AlertChange.cleared,
        );
      },
    );

    test('uses the configured thresholds', () {
      final r = _run([
        [_node(intake: '36°C')],
      ], settings: const AlertSettings(intake: (warm: 35, hot: 38)));
      expect(r.active.values.single.severity, AlertSeverity.warning);
    });
  });

  test('sortAlerts: unacknowledged, critical, newest first', () {
    ActiveAlert a(String id, AlertSeverity s, int minute, {bool ack = false}) =>
        ActiveAlert(
          nodeId: id,
          rule: AlertRule.offline,
          severity: s,
          value: '',
          since: _t0.add(Duration(minutes: minute)),
          acknowledged: ack,
        );
    final sorted = sortAlerts([
      a('old-warn', AlertSeverity.warning, 1),
      a('acked', AlertSeverity.critical, 9, ack: true),
      a('old-crit', AlertSeverity.critical, 2),
      a('new-crit', AlertSeverity.critical, 5),
    ]);
    expect(sorted.map((x) => x.nodeId), [
      'new-crit',
      'old-crit',
      'old-warn',
      'acked',
    ]);
  });

  group('alertBadge', () {
    ActiveAlert a(AlertSeverity s, {bool ack = false}) => ActiveAlert(
      nodeId: '1',
      rule: AlertRule.offline,
      severity: s,
      value: '',
      since: _t0,
      acknowledged: ack,
    );

    test('none without alerts', () => expect(alertBadge([]), isNull));

    test('colour follows the unacknowledged alerts', () {
      expect(
        alertBadge([
          a(AlertSeverity.critical, ack: true),
          a(AlertSeverity.warning),
        ]),
        (severity: AlertSeverity.warning, acknowledged: false, count: 2),
      );
      expect(
        alertBadge([
          a(AlertSeverity.critical, ack: true),
          a(AlertSeverity.warning, ack: true),
        ]),
        (severity: AlertSeverity.critical, acknowledged: true, count: 2),
      );
    });
  });

  group('groupAlerts / countAlerts', () {
    ActiveAlert a(
      String node,
      AlertRule rule,
      AlertSeverity s,
      int minute, {
      bool ack = false,
    }) => ActiveAlert(
      nodeId: node,
      rule: rule,
      severity: s,
      value: '',
      since: _t0.add(Duration(minutes: minute)),
      acknowledged: ack,
    );
    final alerts = [
      a('1', AlertRule.exhaustTemp, AlertSeverity.warning, 5),
      a('2', AlertRule.offline, AlertSeverity.critical, 1),
      a('3', AlertRule.offline, AlertSeverity.critical, 2),
      a('3', AlertRule.intakeTemp, AlertSeverity.warning, 3, ack: true),
    ];

    test('by projector: most urgent group first', () {
      final groups = groupAlerts(alerts, AlertGrouping.projector);
      expect(groups.map((g) => g.key), ['3', '2', '1']);
      expect(groups.first.alerts.map((x) => x.rule), [
        AlertRule.offline,
        AlertRule.intakeTemp,
      ]);
    });

    test('by projector with IPs: IP ascending, numerically', () {
      const ips = {'1': '10.0.0.10', '2': '10.0.0.9', '3': '10.0.0.100'};
      final groups = groupAlerts(
        alerts,
        AlertGrouping.projector,
        ipOf: (id) => ips[id],
      );
      expect(groups.map((g) => g.key), ['2', '1', '3']);
    });

    test('by rule: one group per rule', () {
      final groups = groupAlerts(alerts, AlertGrouping.alert);
      expect(groups.map((g) => g.key), [
        'offline',
        'exhaust-temp',
        'intake-temp',
      ]);
      expect(groups.first.alerts, hasLength(2));
    });

    test('sections follow the group order, Ungrouped last', () {
      final groups = groupAlerts(alerts, AlertGrouping.projector);
      const groupOf = {'1': 'stage', '2': 'gone', '3': 'balcony'};
      final sections = sectionByProjectGroup(groups, (id) => groupOf[id], [
        'stage',
        'balcony',
        'truss',
      ]);
      expect(sections.map((s) => s.groupId), ['stage', 'balcony', null]);
      expect(sections.last.groups.single.key, '2');
    });

    test('counts unacknowledged and total per severity', () {
      expect(countAlerts(alerts), (
        critical: 2,
        warning: 1,
        criticalTotal: 2,
        warningTotal: 2,
      ));
    });
  });

  test('formatAlertDuration / formatAlertStart', () {
    expect(formatAlertDuration(const Duration(seconds: 40)), '< 1 min');
    expect(formatAlertDuration(const Duration(minutes: 12)), '12 min');
    expect(formatAlertDuration(const Duration(minutes: 65)), '1 h 05 min');
    expect(formatAlertStart(DateTime(2026, 10, 2, 9, 5), _t0), '09:05');
    expect(formatAlertStart(DateTime(2026, 9, 30, 14, 2), _t0), 'Sep 30 14:02');
  });

  test('temperatureThresholdError', () {
    expect(temperatureThresholdError(40, 45), isNull);
    expect(temperatureThresholdError(null, 45), 'Enter both values');
    expect(temperatureThresholdError(45, 45), 'Warning must be below critical');
  });

  test('AlertSettings JSON round trip', () {
    const s = AlertSettings(
      enabled: {AlertRule.offline, AlertRule.exhaustTemp},
      intake: (warm: 38, hot: 44),
      sound: true,
      soundFor: AlertNotifyScope.all,
      grouping: AlertGrouping.alert,
    );
    final back = AlertSettings.fromJson(s.toJson());
    expect(back.enabled, s.enabled);
    expect(back.intake, s.intake);
    expect(back.exhaust, kDefaultExhaustTempThreshold);
    expect(back.sound, isTrue);
    expect(back.soundFor, AlertNotifyScope.all);
    expect(back.grouping, AlertGrouping.alert);
    expect(
      AlertSettings.fromJson(const {}).enabled,
      AlertSettings.defaultEnabled,
    );
  });
}
