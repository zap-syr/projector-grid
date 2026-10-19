import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/manage_groups_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _left = ProjectorGroup(
  id: 'g1',
  name: 'Left wall',
  color: 0xFFF97316,
  oscAddress: '/group/left-wall',
);
const _right = ProjectorGroup(
  id: 'g2',
  name: 'Right wall',
  color: 0xFF14B8A6,
  oscAddress: '/group/right-wall',
);

/// Pumps a button that opens Manage Groups, seeds the workspace through the
/// scope's container and, with [open], opens the dialog. Returns the
/// container.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool open = true,
  List<ProjectorGroup> groups = const [_left, _right],
  int nodeCount = 6,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(FakeProtocolService()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ManageGroupsDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.text('open')),
  );
  // Nothing on the bare page watches the auto-dispose workspace, which would
  // otherwise drop the seeded state before the dialog opens.
  container.listen(workspaceProvider, (_, _) {});
  final ws = container.read(workspaceProvider.notifier);
  ws.setGroups(groups);
  ws.setNodes([
    for (var i = 1; i <= nodeCount; i++)
      node(
        '$i',
        ip: '192.168.0.${10 + i}',
        groupId: i <= 2 ? 'g1' : (i == 3 ? 'g2' : null),
      ),
  ]);
  if (open) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
  return container;
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  useTempConfigDir();

  group('Manage Groups', () {
    testWidgets('summary, rows and OSC chips', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester);
      expect(find.text('2 groups, 3 of 6 projectors assigned'), findsOneWidget);
      expect(find.text('2 projectors'), findsOneWidget);
      expect(find.text('1 projector'), findsOneWidget);
      expect(find.text('/group/left-wall'), findsOneWidget);
    });

    testWidgets('inline edit opens and saves', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester);

      await tester.tap(find.byTooltip('Edit Left wall'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      // Delete lives in the row, not in the editor.
      expect(find.text('Delete group'), findsNothing);
      // The OSC address isn't part of the editor.
      expect(find.text('/group/left-wall'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Balcony');
      await tester.tap(find.byKey(const ValueKey('group-color-${0xFF22C55E}')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = c.read(workspaceProvider.notifier).groups.first;
      expect(saved.name, 'Balcony');
      expect(saved.color, 0xFF22C55E);
      expect(saved.oscAddress, '/group/balcony');
      expect(find.text('Save'), findsNothing);
      expect(find.text('/group/balcony'), findsOneWidget);
    });

    testWidgets('opening the editor keeps the row buttons in place', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester);
      final edit = tester.getRect(find.byTooltip('Edit Left wall'));
      final delete = tester.getRect(find.byTooltip('Delete Left wall'));
      await tester.tap(find.byTooltip('Edit Left wall'));
      await tester.pumpAndSettle();
      // The focused name field may scroll the list a little; measure the
      // row itself, not the screen.
      final scrolled = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ManageGroupsDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      Rect unscrolled(Finder f) => tester.getRect(f).shift(Offset(0, scrolled));
      expect(unscrolled(find.byTooltip('Collapse')), edit);
      expect(unscrolled(find.byTooltip('Delete Left wall')), delete);
    });

    testWidgets('inline edit rejects a taken name', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester);
      await tester.tap(find.byTooltip('Edit Left wall'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'right wall');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('A group with this name already exists'),
        findsOneWidget,
      );
      expect(c.read(workspaceProvider.notifier).groups.first.name, 'Left wall');
    });

    testWidgets('new group form opens, closes and creates', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester);
      Finder newButton() => find.widgetWithText(FilledButton, 'New group');

      await tester.tap(newButton());
      await tester.pumpAndSettle();
      expect(find.text('New group name'), findsOneWidget);
      expect(tester.widget<FilledButton>(newButton()).onPressed, isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New group name'), findsNothing);
      expect(tester.widget<FilledButton>(newButton()).onPressed, isNotNull);

      await tester.tap(newButton());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Floor');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      final groups = c.read(workspaceProvider.notifier).groups;
      expect(groups.map((g) => g.name), ['Left wall', 'Right wall', 'Floor']);
      // First unused colour: red 500 (orange and teal are taken).
      expect(groups.last.color, 0xFFEF4444);
      expect(find.text('New group name'), findsNothing);
      expect(find.text('/group/floor'), findsOneWidget);
    });

    testWidgets('delete lists what changes and pauses the group task', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester);
      c.read(scheduledTasksProvider.notifier).loadTasks([
        const ScheduledTask(
          id: 't',
          name: 'Shutter close, 22:30',
          command: 'OSH:1',
          commandLabel: 'Shutter close',
          target: ScheduleTarget.group,
          targetGroupIds: ['g1'],
          scheduleType: ScheduleType.daily,
          timeOfDay: '22:30',
        ),
        // Keeps Right wall, so it isn't paused and isn't listed.
        const ScheduledTask(
          id: 'u',
          name: 'Power on, 08:00',
          command: 'PON',
          commandLabel: 'Power on',
          target: ScheduleTarget.group,
          targetGroupIds: ['g1', 'g2'],
          scheduleType: ScheduleType.daily,
          timeOfDay: '08:00',
        ),
      ]);
      await tester.tap(find.byTooltip('Delete Left wall'));
      await tester.pumpAndSettle();

      expect(find.text('Delete “Left wall”?'), findsOneWidget);
      expect(find.textContaining('stay in the project'), findsOneWidget);
      expect(
        find.textContaining('Shutter close, 22:30 is paused'),
        findsOneWidget,
      );
      expect(find.textContaining('is paused'), findsOneWidget);
      expect(find.textContaining('no longer answers'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete group'));
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider.notifier).groups, [_right]);
      final [paused, kept] = c.read(scheduledTasksProvider);
      expect(paused.enabled, isFalse);
      expect(paused.targetGroupIds, isEmpty);
      expect(kept.enabled, isTrue);
      expect(kept.targetGroupIds, ['g2']);
    });

    for (final (name, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('800×600 window lays out without overflow ($name)', (
        tester,
      ) async {
        _useWindow(tester, const Size(800, 600));
        await _pump(
          tester,
          theme: theme,
          groups: [
            for (var i = 1; i <= 10; i++)
              ProjectorGroup(
                id: 'g$i',
                name: 'A rather long group name $i',
                color: 0xFF3B82F6,
                oscAddress: '/group/a-rather-long-group-name-$i',
              ),
          ],
        );
        await tester.tap(find.byTooltip('Edit A rather long group name 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'New group'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('New group name'), findsOneWidget);
      });
    }
  });

  group('New Group from the context menu', () {
    testWidgets('a few projectors as a comma list; creates the group', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      ProjectorGroup? created;
      final c = await _pump(tester, open: false);
      showNewGroupDialog(
        tester.element(find.text('open')),
        projectorIds: ['3', '1', '2'],
      ).then((g) => created = g);
      await tester.pumpAndSettle();

      expect(find.text('New Group'), findsOneWidget);
      expect(find.text('192.168.0.11, 192.168.0.12, 192.168.0.13'), findsOne);
      expect(find.text('Used by another group'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Balcony');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(created?.name, 'Balcony');
      expect(c.read(workspaceProvider.notifier).groups, contains(created));
    });

    testWidgets('many projectors as range chips, fits 800×600', (tester) async {
      _useWindow(tester, const Size(800, 600));
      await _pump(tester, open: false, nodeCount: 40);
      showNewGroupDialog(
        tester.element(find.text('open')),
        projectorIds: [for (var i = 1; i <= 40; i++) '$i'],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('40 selected projectors', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('192.168.0.11 to .50'), findsOneWidget);
    });
  });
}
