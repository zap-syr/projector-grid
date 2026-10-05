import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alert_badge.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alert_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_alert_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_card.dart';

import '../helpers/test_config_dir.dart';

/// Starts from fixed alerts instead of evaluating the workspace.
class _FakeAlerts extends AlertsNotifier {
  _FakeAlerts(this.initial);

  final List<ActiveAlert> initial;

  @override
  Map<AlertKey, ActiveAlert> build() => {for (final a in initial) a.key: a};
}

const _node = ProjectorNode(
  id: '1',
  name: 'PRJ-03 Right',
  ipAddress: '10.0.0.13',
  x: 0,
  y: 0,
);

ActiveAlert _alert(
  AlertRule rule,
  AlertSeverity severity,
  String value, {
  String item = '',
  bool acknowledged = false,
}) => ActiveAlert(
  nodeId: '1',
  rule: rule,
  item: item,
  severity: severity,
  value: value,
  since: DateTime.now().subtract(const Duration(minutes: 12)),
  acknowledged: acknowledged,
);

void main() {
  useTempConfigDir();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<ActiveAlert> alerts,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [alertsProvider.overrideWith(() => _FakeAlerts(alerts))],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(40),
                child: AlertBadge(node: _node),
              ),
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(AlertBadge)));
  }

  testWidgets('no alerts, no badge', (tester) async {
    await pump(tester, []);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('critical sets the colour and the count shows from two up', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    expect(find.byIcon(Icons.error), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('outlined once everything is acknowledged', (tester) async {
    await pump(tester, [
      _alert(
        AlertRule.offline,
        AlertSeverity.critical,
        'No answer',
        acknowledged: true,
      ),
    ]);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  /// Hovers the badge until its panel is open; returns the mouse.
  Future<TestGesture> hoverOpen(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AlertBadge)));
    await tester.pump(const Duration(milliseconds: 300));
    return mouse;
  }

  testWidgets('a green check once the only open alert is over', (tester) async {
    final since = DateTime.now().subtract(const Duration(minutes: 2));
    await pump(tester, [
      ActiveAlert(
        nodeId: '1',
        rule: AlertRule.signalLost,
        severity: AlertSeverity.critical,
        value: 'No signal on HDMI 1',
        since: since,
        restoredAt: since.add(const Duration(seconds: 3)),
      ),
    ]);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNothing);

    await hoverOpen(tester);
    expect(find.text('Back after 3 s'), findsOneWidget);
  });

  testWidgets('the panel acknowledges, staying open while hovered', (
    tester,
  ) async {
    final c = await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
    ]);
    final mouse = await hoverOpen(tester);

    expect(find.byType(ProjectorAlertPanel), findsOneWidget);
    expect(find.text('Exhaust temperature'), findsOneWidget);
    expect(find.text('58 °C'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);

    final ack = tester.getCenter(find.byType(AcknowledgeButton));
    await mouse.moveTo(ack);
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(ack);
    await mouse.up();
    await tester.pump();
    expect(c.read(alertsProvider).values.single.acknowledged, isTrue);
    expect(find.text('ACKNOWLEDGED (1)'), findsOneWidget);
  });

  testWidgets('a click on the badge does not keep the panel open', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    final mouse = await hoverOpen(tester);
    final badge = tester.getCenter(find.byType(AlertBadge));
    await mouse.down(badge);
    await mouse.up();
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProjectorAlertPanel), findsNothing);
  });

  testWidgets('hover opens after a short delay and closes after leaving', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AlertBadge)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ProjectorAlertPanel), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ProjectorAlertPanel), findsOneWidget);

    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProjectorAlertPanel), findsNothing);
  });

  testWidgets('a hover-opened panel closes when the card is clicked', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(
            () => _FakeAlerts([
              _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ProjectorCard(
                  node: _node,
                  dragOverrides: ValueNotifier(const {}),
                  zoom: 1,
                  onTap: () {},
                  onPanDown: (_) {},
                  onPanUpdate: (_) {},
                  onPanEnd: (_) {},
                  onEdit: () {},
                  onDelete: () {},
                  onColorCorrection: () {},
                  onBrightnessControl: () {},
                  onGeometryCorrection: () {},
                  onRemotePreview: () {},
                  onSelectGroup: null,
                  buildGroupMenuItems: () => [],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AlertBadge)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProjectorAlertPanel), findsOneWidget);

    // Click the card's name, the way one selects it, then move away.
    await mouse.moveTo(tester.getCenter(find.text('PRJ-03 Right')));
    await mouse.down(tester.getCenter(find.text('PRJ-03 Right')));
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.up();
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProjectorAlertPanel), findsNothing);
  });

  testWidgets('critical first, acknowledged folded away past three', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
      _alert(AlertRule.error, AlertSeverity.critical, 'Fan error', item: 'F'),
      for (final i in [1, 2, 3, 4])
        _alert(
          AlertRule.error,
          AlertSeverity.critical,
          'Old $i',
          item: 'old$i',
          acknowledged: true,
        ),
    ]);
    await hoverOpen(tester);

    final fan = tester.getTopLeft(find.text('Fan error'));
    final temp = tester.getTopLeft(find.text('58 °C'));
    expect(fan.dy, lessThan(temp.dy));
    expect(find.text('ACKNOWLEDGED (4)'), findsOneWidget);
    expect(find.textContaining('Old 1'), findsNothing);
  });
}
