import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alert_notifications.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';

final _now = DateTime(2026, 10, 2, 14, 10);

AlertEvent _e(
  String projector,
  AlertRule rule,
  AlertSeverity severity,
  String value, {
  AlertChange change = AlertChange.raised,
}) => (
  change: change,
  alert: ActiveAlert(
    nodeId: projector,
    rule: rule,
    severity: severity,
    value: value,
    since: DateTime(2026, 10, 2, 14, 2),
  ),
  projector: projector,
  ip: '',
);

/// [count] projectors of one model: the same name, each its own node and IP.
List<AlertEvent> _sameModel(int count) => [
  for (var i = 1; i <= count; i++)
    (
      change: AlertChange.raised,
      alert: ActiveAlert(
        nodeId: '$i',
        rule: AlertRule.offline,
        severity: AlertSeverity.critical,
        value: 'No answer',
        since: DateTime(2026, 10, 2, 14, 2),
      ),
      projector: 'PT-RQ35K2',
      ip: '127.0.0.$i',
    ),
];

void main() {
  group('noticeable', () {
    final batch = [
      _e('A', AlertRule.offline, AlertSeverity.critical, 'No answer'),
      _e('B', AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
      _e(
        'C',
        AlertRule.offline,
        AlertSeverity.critical,
        'No answer',
        change: AlertChange.cleared,
      ),
    ];

    test('critical only, or everything raised', () {
      expect(noticeable(batch, AlertNotifyScope.critical), hasLength(1));
      expect(noticeable(batch, AlertNotifyScope.all), hasLength(2));
    });
  });

  group('alertNotice', () {
    test('none for nothing', () => expect(alertNotice([], _now), isNull));

    test('one alert: rule on projector, value since', () {
      expect(
        alertNotice([
          _e('PRJ-02', AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
        ], _now),
        (
          title: 'Exhaust temperature on PRJ-02',
          body: '58 °C since 14:02',
          severity: AlertSeverity.warning,
        ),
      );
    });

    test('a mass failure leads with its rule and names three', () {
      final notice = alertNotice([
        for (var i = 1; i <= 20; i++)
          _e('PRJ-$i', AlertRule.offline, AlertSeverity.critical, 'No answer'),
        _e('PRJ-30', AlertRule.intakeTemp, AlertSeverity.warning, '41 °C'),
        _e('PRJ-31', AlertRule.intakeTemp, AlertSeverity.warning, '42 °C'),
      ], _now)!;
      expect(notice.title, 'Offline on 20 projectors');
      expect(
        notice.body,
        'PRJ-1, PRJ-2, PRJ-3 and 17 more, plus 2 other alerts',
      );
      expect(notice.severity, AlertSeverity.critical);
    });

    test('projectors of one name are told apart by node, with their IPs', () {
      expect(alertNotice(_sameModel(20), _now), (
        title: 'Offline on 20 projectors',
        body:
            'PT-RQ35K2 (127.0.0.1), PT-RQ35K2 (127.0.0.2), '
            'PT-RQ35K2 (127.0.0.3) and 17 more',
        severity: AlertSeverity.critical,
      ));
      expect(
        alertNotice(_sameModel(1), _now)!.title,
        'Offline on PT-RQ35K2 (127.0.0.1)',
      );
    });

    test('critical leads even when warnings are more', () {
      final notice = alertNotice([
        _e('A', AlertRule.intakeTemp, AlertSeverity.warning, '41 °C'),
        _e('B', AlertRule.intakeTemp, AlertSeverity.warning, '41 °C'),
        _e('C', AlertRule.error, AlertSeverity.critical, 'Fan error (F305)'),
      ], _now)!;
      expect(notice.title, 'Projector error on C');
      expect(notice.body, 'Fan error (F305), plus 2 other alerts');
    });
  });
}
