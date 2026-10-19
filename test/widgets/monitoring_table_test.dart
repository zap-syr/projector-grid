import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_filter.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_status.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_view_settings.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/canvas_reveal_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_filter_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_panel_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_view_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:projector_grid/features/workspace/presentation/providers/remote_preview_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/status_pill.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/test_pattern_thumb.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring/monitoring_bar.dart';
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
    expect(find.text('Locate'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectorPanel), findsNothing);
  });

  testWidgets('Locate switches to Controls with the node selected', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    final c = appContainer(tester);
    c.read(monitoringPanelProvider.notifier).open('2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
    expect(c.read(selectionProvider), {'2'});
    expect(c.read(canvasRevealProvider)?.nodeId, '2');
  });

  group('the row menu', () {
    // Opens the ⋮ menu of [ip]'s row and picks [item]; the pointer then
    // leaves the row for the menu, which unmounts the row's actions.
    Future<void> pick(WidgetTester tester, String ip, String item) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text(ip)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      final target = find.widgetWithText(MenuItemButton, item);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('Show details opens the panel', (tester) async {
      await showMonitoring(tester, rig);
      await pick(tester, '10.0.0.3', 'Show details');
      expect(appContainer(tester).read(monitoringPanelProvider), '3');
      expect(find.byType(ProjectorPanel), findsOneWidget);
    });

    testWidgets('Find on canvas switches to Controls', (tester) async {
      await showMonitoring(tester, rig);
      await pick(tester, '10.0.0.3', 'Find on canvas');
      final c = appContainer(tester);
      expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
      expect(c.read(selectionProvider), {'3'});
      expect(c.read(canvasRevealProvider)?.nodeId, '3');
    });
  });

  testWidgets('offline rows: dimmed, accent, last seen, errors Unknown', (
    tester,
  ) async {
    final seen = DateTime.now().copyWith(hour: 16, minute: 41);
    await showMonitoring(tester, [
      _node('1'),
      _node('7', status: ConnectionStatus.offline, lastSeen: seen),
    ]);
    expect(find.text('RZ34K, last seen 16:41'), findsOneWidget);
    // Its codes and signal are the last ones it sent: the Signal pill and
    // the Errors cell say Unknown, not None.
    expect(find.text('Unknown'), findsNWidgets(2));
    expect(find.text('None'), findsOneWidget);
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
    // The two Main stage cards name their group; the ungrouped one doesn't.
    expect(find.byKey(const ValueKey('card-group-pill')), findsNWidgets(2));

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
    await tester.tap(find.byIcon(Icons.monitor_outlined));
    await tester.pumpAndSettle();
    final dialog = tester.widget<RemotePreviewDialog>(
      find.byType(RemotePreviewDialog),
    );
    expect(dialog.nodes.map((n) => n.id), ['3']);
  });

  group('search and quick filters', () {
    // Wide enough for the filters' names in the test font, which is far
    // wider than the app's.
    Future<void> showWide(
      WidgetTester tester,
      List<ProjectorNode> nodes,
    ) async {
      await showMonitoring(tester, nodes);
      tester.view.physicalSize = const Size(3000, 1080);
      await tester.pumpAndSettle();
    }

    Finder filterTab(String label) => find.descendant(
      of: find.byKey(const ValueKey('monitoring-quick-filters')),
      matching: find.text(label),
    );

    testWidgets('a quick filter shows its projectors and the count', (
      tester,
    ) async {
      // No offline node here: its alert would fire a desktop notice while
      // the test waits. The Offline filter's match is tested below.
      await showWide(tester, rig);
      expect(
        find.byKey(const ValueKey('monitoring-shown-count')),
        findsNothing,
      );
      await tester.tap(filterTab('Standby'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.0.2'), findsOneWidget);
      expect(find.text('10.0.0.1'), findsNothing);
      expect(find.text('1 of 3'), findsOneWidget);

      await tester.tap(filterTab('All'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.0.1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('monitoring-shown-count')),
        findsNothing,
      );
    });

    testWidgets('an empty filter is dimmed, stays in place, does nothing', (
      tester,
    ) async {
      await showWide(tester, rig);
      final groupBy = tester.getTopLeft(find.text('Group by: group'));
      final standby = tester.getTopLeft(filterTab('Standby'));
      // No warnings, errors or offline projectors in the rig.
      for (final empty in ['Attention', 'Offline']) {
        await tester.tap(filterTab(empty));
        await tester.pumpAndSettle();
        expect(
          appContainer(tester).read(monitoringFilterProvider).quick,
          MonitoringQuickFilter.all,
        );
      }
      await tester.tap(filterTab('Online'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(filterTab('Standby')), standby);
      expect(tester.getTopLeft(find.text('Group by: group')), groupBy);
    });

    testWidgets('Group by sits with the filters, left of the view switch', (
      tester,
    ) async {
      await showWide(tester, rig);
      final filters = tester.getRect(
        find.byKey(const ValueKey('monitoring-quick-filters')),
      );
      final groupBy = tester.getRect(find.text('Group by: group'));
      final search = tester.getRect(
        find.byKey(const ValueKey('monitoring-search')),
      );
      expect(search.left, lessThan(filters.left));
      expect(groupBy.left, greaterThan(filters.right));
      expect(groupBy.left - filters.right, lessThan(30));
    });

    testWidgets('search by IP; Esc clears it, then closes the panel', (
      tester,
    ) async {
      await showMonitoring(tester, rig);
      final c = appContainer(tester);
      c.read(monitoringPanelProvider.notifier).open('1');
      await tester.enterText(
        find.byKey(const ValueKey('monitoring-search')),
        '0.0.3',
      );
      await tester.pumpAndSettle();
      expect(find.text('10.0.0.3'), findsOneWidget);
      expect(find.text('10.0.0.2'), findsNothing);
      expect(find.text('1 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(c.read(monitoringFilterProvider).query, '');
      expect(find.text('10.0.0.2'), findsOneWidget);
      expect(c.read(monitoringPanelProvider), '1');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(c.read(monitoringPanelProvider), isNull);
    });

    testWidgets('nothing matches: a note and Show all, in Table and Cards', (
      tester,
    ) async {
      await showMonitoring(tester, rig);
      await tester.enterText(
        find.byKey(const ValueKey('monitoring-search')),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No projectors match'), findsOneWidget);
      appContainer(tester)
          .read(monitoringViewProvider.notifier)
          .setMode(MonitoringViewMode.cards);
      await tester.pumpAndSettle();
      expect(find.text('No projectors match'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('No projectors match'), findsNothing);
      expect(find.text('10.0.0.1'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('monitoring-search')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('Ctrl+F focuses the search field', (tester) async {
      await showMonitoring(tester, rig);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('monitoring-search')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
    });

    test('quick filter counts and matches', () {
      const online = MonitoringStatus(online: true);
      const standby = MonitoringStatus(online: true, standby: true);
      const offline = MonitoringStatus(level: ProblemLevel.offline);
      const warning = MonitoringStatus(
        online: true,
        standby: true,
        level: ProblemLevel.warning,
      );
      final counts = quickFilterCounts([online, standby, offline, warning]);
      expect(counts[MonitoringQuickFilter.all], 4);
      expect(counts[MonitoringQuickFilter.online], 3);
      expect(counts[MonitoringQuickFilter.attention], 1);
      expect(counts[MonitoringQuickFilter.offline], 1);
      expect(counts[MonitoringQuickFilter.standby], 2);

      final n = _node('12').copyWith(serialNumber: 'SH1234');
      expect(matchesSearch(n, 'rz 10.0.0.12'), isTrue);
      expect(matchesSearch(n, 'sh12'), isTrue);
      expect(matchesSearch(n, 'rz 10.0.0.13'), isFalse);
      expect(matchesSearch(n, '   '), isTrue);
    });
  });

  testWidgets('Cards: group rows are filled bands across the view', (
    tester,
  ) async {
    await showMonitoring(tester, rig);
    appContainer(tester)
        .read(monitoringViewProvider.notifier)
        .setMode(MonitoringViewMode.cards);
    await tester.pumpAndSettle();
    final band = find.byKey(const ValueKey('group-g1'));
    final view = tester.getRect(find.byType(MonitoringTable));
    expect(tester.getRect(band).left, view.left);
    // Short of the scrollbar's lane at most.
    expect(view.right - tester.getRect(band).right, lessThan(20));
    final material = tester.widget<Material>(
      find.descendant(of: band, matching: find.byType(Material)).first,
    );
    expect(material.color, isNot(Colors.transparent));
  });

  testWidgets('Cards: Extended shows AC; Compact power red in standby, '
      'with the shutter', (tester) async {
    await showMonitoring(tester, rig);
    final view = appContainer(tester).read(monitoringViewProvider.notifier);
    view.setMode(MonitoringViewMode.cards);
    await tester.pumpAndSettle();
    expect(find.text('AC'), findsNWidgets(3));
    expect(find.text('Light'), findsNothing);

    view.setCardDensity(MonitoringCardDensity.compact);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MonitoringTable));
    final error = Theme.of(context).colorScheme.error;
    Icon icon(String ip, String key) => tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(
          of: find.text(ip),
          matching: find.byKey(const ValueKey('compact-tile')),
        ),
        matching: find.byKey(ValueKey(key)),
      ),
    );
    expect(icon('10.0.0.2', 'compact-power').color, error);
    expect(icon('10.0.0.1', 'compact-power').color, isNot(error));
    // The rig's shutters are closed: red while on, grey in standby.
    final shutter = icon('10.0.0.1', 'compact-shutter');
    expect(shutter.icon, Icons.visibility_off_outlined);
    expect(shutter.color, error);
    expect(icon('10.0.0.2', 'compact-shutter').color, isNot(error));
  });

  testWidgets('the panel shows the test pattern with its thumbnail', (
    tester,
  ) async {
    await showMonitoring(tester, [_node('1').copyWith(testPattern: 'OTS:07')]);
    appContainer(tester).read(monitoringPanelProvider.notifier).open('1');
    await tester.pumpAndSettle();
    final panel = find.byType(ProjectorPanel);
    expect(
      find.descendant(of: panel, matching: find.byType(TestPatternThumb)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Cross Hatch')),
      findsOneWidget,
    );
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

  // The bar steps down (filter names, then the rest to icons) rather than
  // overflow, and the search keeps some room at every width.
  testWidgets('the bar fits every window width', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 470);
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
    c.read(workspaceProvider.notifier).setNodes([
      for (var i = 1; i <= 120; i++) _node('$i'),
    ]);
    for (final mode in MonitoringViewMode.values) {
      c.read(monitoringViewProvider.notifier).setMode(mode);
      for (var w = 800.0; w <= 2000; w += 60) {
        tester.view.physicalSize = Size(w, 470);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode at $w');
        final search = tester.getSize(
          find.byKey(const ValueKey('monitoring-search')),
        );
        // The test font is much wider than the app's, so the real field
        // has more room than this.
        expect(search.width, greaterThan(80), reason: '$mode at $w');
        // No label of the bar is cut off (the field's own hint may be).
        final field = find.byKey(const ValueKey('monitoring-search'));
        for (final e
            in find
                .descendant(
                  of: find.byType(MonitoringBar),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          if (find
              .descendant(of: field, matching: find.byWidget(e.widget))
              .evaluate()
              .isNotEmpty) {
            continue;
          }
          final p = e.renderObject! as RenderParagraph;
          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: '"${p.text.toPlainText()}" cut, $mode at $w',
          );
        }
      }
    }
  });
}
