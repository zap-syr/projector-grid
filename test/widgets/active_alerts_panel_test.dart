import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/active_alerts_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alert_row.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

class _FakeAlerts extends AlertsNotifier {
  _FakeAlerts(this.initial);

  final List<ActiveAlert> initial;

  @override
  Map<AlertKey, ActiveAlert> build() => {for (final a in initial) a.key: a};
}

ActiveAlert _alert(
  String node,
  AlertRule rule,
  AlertSeverity severity,
  String value, {
  bool acknowledged = false,
}) => ActiveAlert(
  nodeId: node,
  rule: rule,
  severity: severity,
  value: value,
  since: DateTime.now().subtract(const Duration(minutes: 5)),
  acknowledged: acknowledged,
);

void main() {
  useTempConfigDir();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<ActiveAlert> alerts, {
    bool withGroups = false,
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
          alertsProvider.overrideWith(() => _FakeAlerts(alerts)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ActiveAlertsPanel(),
            ),
          ),
        ),
      ),
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ActiveAlertsPanel)),
    );
    final ws = c.read(workspaceProvider.notifier);
    if (withGroups) {
      ws.setGroups(const [
        ProjectorGroup(id: 'stage', name: 'Stage', color: 0xFFE53935),
      ]);
    }
    ws.setNodes([
      for (final id in ['1', '2', '3'])
        ProjectorNode(
          id: id,
          name: 'PRJ-0$id',
          ipAddress: '10.0.0.$id',
          x: 0,
          y: 0,
          groupId: withGroups && id != '3' ? 'stage' : null,
        ),
    ]);
    await tester.pumpAndSettle();
    return c;
  }

  final alerts = [
    _alert('1', AlertRule.offline, AlertSeverity.critical, 'No answer'),
    _alert('2', AlertRule.offline, AlertSeverity.critical, 'No answer'),
    _alert('3', AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
    _alert(
      '3',
      AlertRule.intakeTemp,
      AlertSeverity.warning,
      '41 °C',
      acknowledged: true,
    ),
  ];

  testWidgets('no alerts shows the empty state', (tester) async {
    await pump(tester, []);
    expect(find.text('No active alerts'), findsOneWidget);
  });

  testWidgets('groups by projector, and by rule once switched (saved)', (
    tester,
  ) async {
    final c = await pump(tester, alerts);
    expect(find.text('PRJ-01   10.0.0.1', findRichText: true), findsOneWidget);
    expect(find.text('3 total', findRichText: true), findsNothing);
    expect(find.textContaining('4 total', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).alerts.grouping, AlertGrouping.alert);
    expect(
      find.textContaining('2 projectors', findRichText: true),
      findsOneWidget,
    );
    // Rows grouped by rule are titled by projector and IP.
    expect(find.text('PRJ-02   10.0.0.2', findRichText: true), findsOneWidget);
  });

  testWidgets('project groups: sections with Ungrouped last, toggle saved', (
    tester,
  ) async {
    final c = await pump(tester, alerts, withGroups: true);
    final stage = tester.getTopLeft(
      find.textContaining('STAGE', findRichText: true),
    );
    final ungrouped = tester.getTopLeft(
      find.textContaining('UNGROUPED', findRichText: true),
    );
    expect(stage.dy, lessThan(ungrouped.dy));
    expect(
      find.textContaining('2 projectors', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Sort into project groups'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).alerts.byProjectGroups, isFalse);
    expect(find.textContaining('STAGE', findRichText: true), findsNothing);
  });

  testWidgets('no project-groups toggle without groups or by rule', (
    tester,
  ) async {
    await pump(tester, alerts);
    expect(find.bySemanticsLabel('Sort into project groups'), findsNothing);
  });

  testWidgets('the warning filter hides critical groups', (tester) async {
    await pump(tester, alerts);
    expect(find.byType(AlertRow), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.warning).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsOneWidget);
    expect(find.text('58 °C'), findsOneWidget);
  });

  testWidgets('acknowledging a group acknowledges its alerts only', (
    tester,
  ) async {
    final c = await pump(tester, alerts);
    await tester.tap(find.bySemanticsLabel('Acknowledge projector').first);
    await tester.pumpAndSettle();
    final open = c.read(alertsProvider).values.where((a) => !a.acknowledged);
    expect(open, hasLength(2));
  });
}
