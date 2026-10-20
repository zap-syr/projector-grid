import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alert_badge.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alert_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/bar_chip.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_alert_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_card.dart';

import '../helpers/app_fonts.dart';
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
  // The panel's footer lays out at its real width.
  setUpAll(loadAppFonts);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<ActiveAlert> alerts,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [alertsProvider.overrideWith(() => _FakeAlerts(alerts))],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
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

  testWidgets('critical sets the colour; a warning beside it is not counted', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    expect(find.byIcon(Icons.error), findsOneWidget);
    // One critical: the count shows from two up.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the count is the alerts of the icon\'s severity', (
    tester,
  ) async {
    await pump(tester, [
      _alert(AlertRule.intakeTemp, AlertSeverity.warning, '41 °C'),
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
      _alert(AlertRule.error, AlertSeverity.critical, 'F305', item: 'F305'),
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
    final at = since.add(const Duration(seconds: 3));
    expect(
      find.text(
        'No signal on HDMI 1, over at ${formatAlertStart(at, at)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the panel acknowledges, staying open while hovered', (
    tester,
  ) async {
    final c = await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
    ]);
    final mouse = await hoverOpen(tester);

    expect(find.byType(ProjectorAlertPanel), findsOneWidget);
    expect(find.text('Exhaust temperature 58 °C'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    final since = c.read(alertsProvider).values.single.since;
    expect(find.text(formatAlertStart(since, since)), findsOneWidget);
    // The one-projector panel has no filters and no grouping controls.
    expect(find.byType(BarChip), findsNothing);
    expect(find.bySemanticsLabel('By alert'), findsNothing);

    final ack = tester.getCenter(find.byType(AcknowledgeButton));
    await mouse.moveTo(ack);
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(ack);
    await mouse.up();
    await tester.pump();
    expect(c.read(alertsProvider).values.single.acknowledged, isTrue);
    expect(find.text('Acknowledged 1', findRichText: true), findsOneWidget);
    expect(find.text('All acknowledged'), findsOneWidget);
    // Nothing left to acknowledge: no Acknowledge all, Event log stays.
    expect(find.byKey(const ValueKey('alerts-acknowledge-all')), findsNothing);
    expect(find.byKey(const ValueKey('alerts-event-log')), findsOneWidget);
  });

  testWidgets('the panel acknowledges all of its projector from the footer', (
    tester,
  ) async {
    final c = await pump(tester, [
      _alert(AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
      _alert(AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    final mouse = await hoverOpen(tester);
    final button = find.byKey(const ValueKey('alerts-acknowledge-all'));
    expect(tester.widget(button), isA<FilledButton>());
    final at = tester.getCenter(button);
    await mouse.moveTo(at);
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(at);
    await mouse.up();
    await tester.pump();
    expect(c.read(alertsProvider).values.every((a) => a.acknowledged), isTrue);
  });

  testWidgets('the panel fits an 800×600 window, the footer shown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pump(tester, [
      for (var i = 0; i < 16; i++)
        _alert(
          AlertRule.error,
          AlertSeverity.critical,
          'Error $i',
          item: 'E$i',
        ),
    ]);
    await hoverOpen(tester);
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byType(ProjectorAlertPanel));
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(panel.bottom, lessThanOrEqualTo(600));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('alerts-acknowledge-all')))
          .bottom,
      lessThan(panel.bottom),
    );
    final list = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ProjectorAlertPanel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(list.position.maxScrollExtent, greaterThan(0));
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
          theme: AppTheme.darkTheme,
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
                  onQuickStatus: () {},
                  onDelete: () {},
                  onColorCorrection: () {},
                  onBrightnessControl: () {},
                  onGeometryCorrection: () {},
                  onEdgeBlending: () {},
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
    // The card's name, not the panel header's.
    final inPanel = find
        .descendant(
          of: find.byType(ProjectorAlertPanel),
          matching: find.text('PRJ-03 Right'),
        )
        .evaluate()
        .toSet();
    final name = find.byElementPredicate(
      (e) =>
          e.widget is Text &&
          (e.widget as Text).data == 'PRJ-03 Right' &&
          !inPanel.contains(e),
    );
    await mouse.moveTo(tester.getCenter(name));
    await mouse.down(tester.getCenter(name));
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
    final temp = tester.getTopLeft(find.text('Exhaust temperature 58 °C'));
    expect(fan.dy, lessThan(temp.dy));
    expect(find.text('Acknowledged 4', findRichText: true), findsOneWidget);
    expect(find.textContaining('Old 1', findRichText: true), findsNothing);
  });
}
