import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
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
import 'package:projector_grid/features/workspace/presentation/widgets/anchored_panel_layout.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/severity_pill.dart';

import '../helpers/app_fonts.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

class _FakeAlerts extends AlertsNotifier {
  _FakeAlerts(this.initial);

  final List<ActiveAlert> initial;

  @override
  Map<AlertKey, ActiveAlert> build() => {for (final a in initial) a.key: a};
}

final _since = DateTime.now().subtract(const Duration(minutes: 5));

ActiveAlert _alert(
  String node,
  AlertRule rule,
  AlertSeverity severity,
  String value, {
  String item = '',
  bool acknowledged = false,
  DateTime? restoredAt,
}) => ActiveAlert(
  nodeId: node,
  rule: rule,
  item: item,
  severity: severity,
  value: value,
  since: _since,
  acknowledged: acknowledged,
  restoredAt: restoredAt,
);

Finder _rowOf(String text) => find.ancestor(
  of: find.textContaining(text, findRichText: true),
  matching: find.byType(AlertRow),
);

void main() {
  useTempConfigDir();
  // Rows measure and lay out at their real widths.
  setUpAll(loadAppFonts);

  /// The panel as the status bar anchors it, in a [size] window.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<ActiveAlert> alerts, {
    bool withGroups = false,
    Size size = const Size(900, 900),
    int projectors = 3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
          alertsProvider.overrideWith(() => _FakeAlerts(alerts)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: AnchoredPanelLayout(
                      anchor: const Rect.fromLTWH(300, 96, 120, 28),
                      width: ActiveAlertsPanel.width,
                      flip: false,
                    ),
                    child: const ActiveAlertsPanel(),
                  ),
                ),
              ],
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
      for (var i = 1; i <= projectors; i++)
        ProjectorNode(
          id: '$i',
          name: 'PT-RZ$i',
          ipAddress: '10.0.0.$i',
          x: 0,
          y: 0,
          groupId: withGroups && i != 3 ? 'stage' : null,
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

  Finder ackAll() => find.byKey(const ValueKey('alerts-acknowledge-all'));
  Finder eventLog() => find.byKey(const ValueKey('alerts-event-log'));

  testWidgets('nothing active: the empty state and Event log only', (
    tester,
  ) async {
    await pump(tester, []);
    expect(find.text('No active alerts'), findsOneWidget);
    expect(find.byKey(const ValueKey('alerts-filter-all')), findsNothing);
    expect(eventLog(), findsOneWidget);
    expect(ackAll(), findsNothing);
  });

  testWidgets('groups by projector, and by alert once switched (saved)', (
    tester,
  ) async {
    final c = await pump(tester, alerts);
    expect(find.text('10.0.0.1'), findsOneWidget);
    expect(find.text('PT-RZ1'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);
    expect(find.text('Exhaust temperature 58 °C'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('By alert'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).alerts.grouping, AlertGrouping.alert);
    expect(find.text('2 projectors'), findsOneWidget);
    // Rows grouped by alert lead with the projector's IP and model.
    expect(find.text('10.0.0.2  PT-RZ2', findRichText: true), findsOneWidget);
  });

  testWidgets('a group header hovers over its full height, IP and model on '
      'one baseline', (tester) async {
    await pump(tester, alerts);
    final ip = find.text('10.0.0.1');
    final ink = find.ancestor(of: ip, matching: find.byType(InkWell)).first;
    // Was the text's height: a thin strip of hover fill.
    expect(tester.getSize(ink).height, 36);
    expect(
      tester.getBottomLeft(ip).dy,
      closeTo(tester.getBottomLeft(find.text('PT-RZ1')).dy, 3),
    );
  });

  testWidgets('both groupings show the severity pills in their headers', (
    tester,
  ) async {
    await pump(tester, alerts);
    // Two projector groups with one critical each, one with a warning.
    expect(
      find.byWidgetPredicate(
        (w) => w is SeverityPill && w.kind == SeverityPillKind.critical,
      ),
      findsNWidgets(2),
    );
    await tester.tap(find.bySemanticsLabel('By alert'));
    await tester.pumpAndSettle();
    final offline = tester.widget<SeverityPill>(
      find.byWidgetPredicate(
        (w) => w is SeverityPill && w.kind == SeverityPillKind.critical,
      ),
    );
    expect(offline.count, 2);
    expect(offline.filled, isTrue);
  });

  testWidgets('project groups: sections in sentence case with pills, saved', (
    tester,
  ) async {
    final c = await pump(tester, alerts, withGroups: true);
    final stage = tester.getTopLeft(find.text('Stage'));
    final ungrouped = tester.getTopLeft(find.text('Ungrouped'));
    expect(stage.dy, lessThan(ungrouped.dy));
    expect(find.text('2 projectors'), findsOneWidget);
    // Section and projector headers: 2 per section with a critical.
    expect(
      find.byWidgetPredicate(
        (w) => w is SeverityPill && w.kind == SeverityPillKind.critical,
      ),
      findsNWidgets(3),
    );

    await tester.tap(find.bySemanticsLabel('Sort into project groups'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).alerts.byProjectGroups, isFalse);
    expect(find.text('Stage'), findsNothing);
  });

  testWidgets('no project-groups toggle without groups', (tester) async {
    await pump(tester, alerts);
    expect(find.bySemanticsLabel('Sort into project groups'), findsNothing);
  });

  testWidgets('by alert, the toggle stays and splits alerts into sections', (
    tester,
  ) async {
    final c = await pump(tester, alerts, withGroups: true);
    await tester.tap(find.bySemanticsLabel('By alert'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Sort into project groups'), findsOneWidget);
    // Offline holds 10.0.0.1 and .2, both on Stage; Exhaust is .3's.
    expect(find.text('Stage'), findsOneWidget);
    expect(find.text('Ungrouped'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Acknowledge Stage'));
    await tester.pumpAndSettle();
    final open = c.read(alertsProvider).values.where((a) => !a.acknowledged);
    expect(open.map((a) => a.nodeId), ['3']);

    await tester.tap(find.bySemanticsLabel('Sort into project groups'));
    await tester.pumpAndSettle();
    expect(find.text('Ungrouped'), findsNothing);
  });

  testWidgets('fold / unfold all: one alert group, its sections too', (
    tester,
  ) async {
    await pump(tester, alerts.take(2).toList(), withGroups: true);
    await tester.tap(find.bySemanticsLabel('By alert'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsNWidgets(2));

    // Fold the Stage section by hand: not everything is open any more.
    await tester.tap(find.text('Stage'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsNothing);
    await tester.tap(find.bySemanticsLabel('Unfold all'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Fold all'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsNothing);
    expect(find.text('Stage'), findsNothing);
  });

  testWidgets('the warning filter hides critical groups', (tester) async {
    await pump(tester, alerts);
    expect(find.byType(AlertRow), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('alerts-filter-warning')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertRow), findsOneWidget);
    expect(find.text('Exhaust temperature 58 °C'), findsOneWidget);
  });

  testWidgets('an alert that is over shows under All only', (tester) async {
    final at = _since.add(const Duration(minutes: 1));
    await pump(tester, [
      _alert(
        '1',
        AlertRule.signalLost,
        AlertSeverity.critical,
        'No signal on HDMI 1',
        restoredAt: at,
      ),
      _alert('2', AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    expect(_rowOf('No signal on HDMI 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alerts-filter-critical')));
    await tester.pumpAndSettle();
    expect(_rowOf('No signal on HDMI 1'), findsNothing);
    expect(_rowOf('No answer'), findsOneWidget);
  });

  testWidgets('a chip at 0 stays in place, dimmed', (tester) async {
    await pump(tester, alerts.take(2).toList());
    final warning = find.byKey(const ValueKey('alerts-filter-warning'));
    expect(warning, findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.descendant(of: warning, matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('a filter that empties says what it hides, Show all', (
    tester,
  ) async {
    await pump(tester, alerts);
    await tester.tap(find.byKey(const ValueKey('alerts-filter-warning')));
    await tester.pumpAndSettle();
    // The one warning acknowledged: the filter stays selected.
    await tester.tap(
      find.descendant(
        of: _rowOf('Exhaust temperature'),
        matching: find.byType(AcknowledgeButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No warnings'), findsOneWidget);
    expect(
      find.text('2 critical alerts are hidden by the filter'),
      findsOneWidget,
    );

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('No warnings'), findsNothing);
    expect(find.byType(AlertRow), findsNWidgets(2));
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

  testWidgets('Acknowledge all is filled and takes what the filter hides', (
    tester,
  ) async {
    final c = await pump(tester, alerts);
    final filled = find.byWidgetPredicate((w) => w is FilledButton);
    expect(tester.widget(ackAll()), isA<FilledButton>());
    // The panel's one filled button.
    expect(filled, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alerts-filter-warning')));
    await tester.pumpAndSettle();
    await tester.tap(ackAll());
    await tester.pumpAndSettle();
    expect(c.read(alertsProvider).values.every((a) => a.acknowledged), isTrue);

    // Nothing left to acknowledge: hidden, Event log stays in place.
    expect(ackAll(), findsNothing);
    expect(eventLog(), findsOneWidget);
    expect(find.text('All acknowledged'), findsOneWidget);
    expect(find.text('4 acknowledged'), findsOneWidget);
  });

  testWidgets('the message is in the primary text colour, the edge red', (
    tester,
  ) async {
    await pump(tester, alerts.take(1).toList());
    final cs = AppTheme.darkTheme.colorScheme;
    final row = _rowOf('No answer');
    final text = tester.widget<RichText>(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'No answer',
        ),
      ),
    );
    expect(text.text.style?.color, cs.onSurface);
    final edge = tester.widget<DecoratedBox>(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('alert-row-edge')),
      ),
    );
    expect((edge.decoration as BoxDecoration).color, cs.error);
  });

  testWidgets('a long message takes two lines and the row grows to 70', (
    tester,
  ) async {
    await pump(tester, [
      _alert(
        '1',
        AlertRule.error,
        AlertSeverity.critical,
        'Lamp 2 failed to light up. Replace the lamp unit',
        item: 'U21',
      ),
      _alert('2', AlertRule.offline, AlertSeverity.critical, 'No answer'),
    ]);
    expect(tester.getSize(_rowOf('Lamp 2')).height, AlertRow.tallHeight);
    expect(tester.getSize(_rowOf('No answer')).height, AlertRow.height);
  });

  testWidgets('icon, time and Acknowledge share the row\'s centre line', (
    tester,
  ) async {
    await pump(tester, [
      _alert(
        '1',
        AlertRule.error,
        AlertSeverity.critical,
        'Lamp 2 failed to light up. Replace the lamp unit',
        item: 'U21',
      ),
    ]);
    final row = _rowOf('Lamp 2');
    final centre = tester.getCenter(row).dy;
    double centreOf(Finder f) =>
        tester.getCenter(find.descendant(of: row, matching: f).first).dy;
    expect(centreOf(find.byType(Icon)), closeTo(centre, 0.5));
    expect(
      centreOf(find.byKey(const ValueKey('alert-row-time'))),
      closeTo(centre, 0.5),
    );
    expect(centreOf(find.byType(AcknowledgeButton)), closeTo(centre, 0.5));
  });

  testWidgets('over at: a recovered row of any rule ends with it', (
    tester,
  ) async {
    final at = _since.add(const Duration(minutes: 2));
    await pump(tester, [
      _alert(
        '1',
        AlertRule.exhaustTemp,
        AlertSeverity.warning,
        '52 °C',
        restoredAt: at,
      ),
    ]);
    expect(
      find.text(
        'Exhaust temperature 52 °C, over at ${formatAlertStart(at, at)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('fits an 800×600 window: footer shown, only the list scrolls', (
    tester,
  ) async {
    await pump(
      tester,
      [
        for (var i = 1; i <= 12; i++) ...[
          _alert('$i', AlertRule.offline, AlertSeverity.critical, 'No answer'),
          _alert('$i', AlertRule.exhaustTemp, AlertSeverity.warning, '58 °C'),
        ],
      ],
      size: const Size(800, 600),
      projectors: 12,
    );
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byType(ActiveAlertsPanel));
    expect(panel.bottom, lessThanOrEqualTo(600));
    expect(tester.getRect(ackAll()).bottom, lessThan(panel.bottom));
    expect(tester.getRect(eventLog()).bottom, lessThan(panel.bottom));
    final list = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ActiveAlertsPanel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(list.position.maxScrollExtent, greaterThan(0));
  });
}
