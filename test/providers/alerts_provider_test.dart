import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  List<LogEvent> alertLog(ProviderContainer c) => [
    for (final e in c.read(eventLogProvider))
      if (e.type == LogEventType.alert) e,
  ];

  test('raises and clears from workspace changes, logging both', () {
    final c = makeContainer(FakeProtocolService());
    c.listen(alertsProvider, (_, _) {});
    final ws = c.read(workspaceProvider.notifier);

    ws.setNodes([node('1').copyWith(exhaustTemp: '58°C', polled: true)]);
    final alert = c.read(alertsProvider).values.single;
    expect(alert.rule, AlertRule.exhaustTemp);
    expect(alertLog(c).single.message, 'Exhaust temperature: 58 °C (warning)');
    expect(alertLog(c).single.projectorName, 'Proj 1');

    ws.setNodes([node('1').copyWith(exhaustTemp: '40°C', polled: true)]);
    expect(c.read(alertsProvider), isEmpty);
    expect(alertLog(c).first.message, 'Exhaust temperature cleared');
  });

  test('does not notify on a tick that changes no alert', () {
    final c = makeContainer(FakeProtocolService());
    var notifications = 0;
    c.listen(alertsProvider, (_, _) => notifications++);
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1').copyWith(exhaustTemp: '58°C')]);
    expect(notifications, 1);

    ws.setNodes([
      node('1').copyWith(exhaustTemp: '58°C', powerStatus: PowerStatus.on),
    ]);
    expect(notifications, 1);
  });

  test('acknowledge and acknowledgeAll', () {
    final c = makeContainer(FakeProtocolService());
    c.listen(alertsProvider, (_, _) {});
    c.read(workspaceProvider.notifier).setNodes([
      node('1').copyWith(exhaustTemp: '58°C'),
      node('2').copyWith(errors: '000100000000'),
    ]);
    final alerts = c.read(alertsProvider.notifier);

    final key = c.read(alertsProvider).keys.firstWhere((k) => k.nodeId == '1');
    alerts.acknowledge(key);
    expect(c.read(alertsProvider)[key]!.acknowledged, isTrue);
    expect(alertLog(c).first.message, 'Exhaust temperature acknowledged');

    alerts.acknowledgeAll(nodeId: '2');
    expect(c.read(alertsProvider).values.every((a) => a.acknowledged), isTrue);
  });

  test('switching a rule off clears its alerts', () {
    final c = makeContainer(FakeProtocolService());
    c.listen(alertsProvider, (_, _) {});
    c.read(workspaceProvider.notifier).setNodes([
      node('1').copyWith(exhaustTemp: '58°C'),
    ]);
    final settings = c.read(appSettingsProvider.notifier);
    settings.setAlertSettings(
      const AlertSettings(enabled: {AlertRule.offline}),
    );
    expect(c.read(alertsProvider), isEmpty);
  });
}
