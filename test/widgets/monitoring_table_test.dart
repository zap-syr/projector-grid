import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_view_settings.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_panel_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_view_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:projector_grid/features/workspace/presentation/providers/remote_preview_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/status_pill.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring/projector_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/remote_preview_dialog.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// Never opens the projector's WebSocket.
class _IdlePreview extends RemotePreview {
  @override
  RemotePreviewState build(String host) => const RemotePreviewConnecting();
}

const _stage = ProjectorGroup(id: 'g1', name: 'Main stage', color: 0xFF3B82F6);

ProjectorNode _node(
  String id, {
  String? group,
  ConnectionStatus status = ConnectionStatus.connected,
  PowerStatus power = PowerStatus.on,
  String signal = '1920x1080/60p',
  DateTime? lastSeen,
}) => ProjectorNode(
  id: id,
  name: 'RZ34K',
  ipAddress: '10.0.0.$id',
  x: 0,
  y: 0,
  groupId: group,
  connectionStatus: status,
  polled: true,
  powerStatus: power,
  signal: signal,
  input: 'HDMI 1',
  lastSeen: lastSeen,
);

void main() {
  useTempConfigDir();

  Future<void> showMonitoring(
    WidgetTester tester,
    List<ProjectorNode> nodes,
  ) async {
    await pumpApp(
      tester,
      FakeProtocolService(),
      overrides: [remotePreviewProvider.overrideWith2((_) => _IdlePreview())],
    );
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setGroups([_stage]);
    c.read(workspaceProvider.notifier).setNodes(nodes);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  final rig = [
    _node('1', group: 'g1'),
    _node('2', group: 'g1', power: PowerStatus.standby, signal: 'NO SIGNAL'),
    _node('3', signal: 'NO SIGNAL'),
  ];

  testWidgets('grouped by default: group rows with a summary, collapsible', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    expect(find.text('Main stage'), findsOneWidget);
    expect(find.text('Ungrouped'), findsOneWidget);
    expect(find.text('2 projectors, 2 online, 1 in standby'), findsOneWidget);
    // Grouped, the Group column stays hidden.
    expect(find.text('Group'), findsNothing);
    expect(find.text('10.0.0.1'), findsOneWidget);

    await tester.tap(find.text('Main stage'));
    await tester.pumpAndSettle();
    expect(find.text('10.0.0.1'), findsNothing);
    expect(find.text('10.0.0.3'), findsOneWidget);
  });

  testWidgets('Group by none: a flat list with a Group column', (tester) async {
    await showMonitoring(tester, rig);
    await tester.tap(find.text('Group by: group'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'None'));
    await tester.pumpAndSettle();
    expect(
      appContainer(tester).read(monitoringViewProvider).groupByGroup,
      isFalse,
    );
    expect(find.text('Ungrouped'), findsNothing);
    expect(find.text('Group'), findsOneWidget);
    // The group's name now sits in its rows.
    expect(find.text('Main stage'), findsNWidgets(2));
  });

  testWidgets('the signal pill: resolution green, No signal red only when on', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    final context = tester.element(find.text('10.0.0.1'));
    final sc = AppStatusColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    final outline = Theme.of(context).colorScheme.outline;

    StatusPill pillOf(String ip) => tester.widget<StatusPill>(
      find.descendant(
        of: find.ancestor(
          of: find.text(ip),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TableRow',
          ),
        ),
        matching: find.byType(StatusPill),
      ),
    );

    expect(pillOf('10.0.0.1').label, '1920x1080/60p');
    expect(pillOf('10.0.0.1').color, sc.success);
    expect(pillOf('10.0.0.2').label, 'No signal');
    expect(pillOf('10.0.0.2').color, outline);
    expect(pillOf('10.0.0.3').color, error);
  });

  testWidgets('a row click opens the panel over the table, columns stay put', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    // The headers come first; the panel repeats some of these words.
    final power = tester.getTopLeft(find.text('Power').first);
    final errors = tester.getTopLeft(find.text('Errors').first);
    await tester.tap(find.text('10.0.0.1'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectorPanel), findsOneWidget);
    expect(tester.getSize(find.byType(ProjectorPanel)).width, 380);
    expect(tester.getTopLeft(find.text('Power').first), power);
    expect(tester.getTopLeft(find.text('Errors').first), errors);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Web UI'), findsOneWidget);
    expect(find.text('Find on canvas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectorPanel), findsNothing);
  });

  testWidgets('Find on canvas switches to Controls with the node selected', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    final c = appContainer(tester);
    c.read(monitoringPanelProvider.notifier).open('2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find on canvas'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
    expect(c.read(selectionProvider), {'2'});
  });

  testWidgets('offline rows: dimmed, accent, last seen, Offline badge', (
    tester,
  ) async {
    final seen = DateTime.now().copyWith(hour: 16, minute: 41);
    await showMonitoring(tester, [
      _node('1'),
      _node('7', status: ConnectionStatus.offline, lastSeen: seen),
    ]);
    expect(find.text('RZ34K, last seen 16:41'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byKey(const ValueKey('problem-accent')), findsOneWidget);
    // The Power cell of the offline row sits under a dimming Opacity.
    final dimmed = find.ancestor(
      of: find.text('On').last,
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
    );
    expect(dimmed, findsOneWidget);
    final live = find.ancestor(
      of: find.text('On').first,
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
    );
    expect(live, findsNothing);
  });

  testWidgets('Cards: Extended and Compact; the bar keeps its place', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    final viewSwitch = find.byKey(const ValueKey('monitoring-view-switch'));
    final before = tester.getTopLeft(viewSwitch);
    final groupBy = tester.getTopLeft(find.text('Group by: group'));

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(viewSwitch), before);
    expect(tester.getTopLeft(find.text('Group by: group')), groupBy);
    expect(find.text('Intake'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('compact-tile')), findsNothing);

    await tester.tap(find.text('Compact'));
    await tester.pumpAndSettle();
    expect(
      appContainer(tester).read(monitoringViewProvider).cardDensity,
      MonitoringCardDensity.compact,
    );
    expect(find.byKey(const ValueKey('compact-tile')), findsNWidgets(3));
    expect(find.text('Intake'), findsNothing);
    expect(tester.getTopLeft(viewSwitch), before);
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-tile')).first),
      const Size(176, 96),
    );

    await tester.tap(find.text('10.0.0.1'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectorPanel), findsOneWidget);
  });

  testWidgets('a row\'s Remote Preview action opens the dialog for it', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('10.0.0.3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.cast));
    await tester.pumpAndSettle();
    final dialog = tester.widget<RemotePreviewDialog>(
      find.byType(RemotePreviewDialog),
    );
    expect(dialog.nodes.map((n) => n.id), ['3']);
  });

  // The view alone, at what an 800x600 window leaves it under the menu,
  // toolbar and status bar.
  testWidgets('no overflow at 800x600: table, panel, both card densities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 470);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
          remotePreviewProvider.overrideWith2((_) => _IdlePreview()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: MonitoringTable()),
        ),
      ),
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MonitoringTable)),
    );
    c.read(workspaceProvider.notifier).setGroups([_stage]);
    c.read(workspaceProvider.notifier).setNodes([
      ...rig,
      _node('7', status: ConnectionStatus.offline),
    ]);
    c.read(monitoringPanelProvider.notifier).open('1');
    await tester.pumpAndSettle();
    expect(find.byType(ProjectorPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
    final view = c.read(monitoringViewProvider.notifier);
    view.setMode(MonitoringViewMode.cards);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    view.setCardDensity(MonitoringCardDensity.compact);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
