import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/toolbar.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

class _FakeAlignment extends AlignmentNotifier {
  void setActive(bool active) => state = state.copyWith(active: active);
}

const _keys = [
  ValueKey('toolbar-add'),
  ValueKey('toolbar-groups'),
  ValueKey('toolbar-tasks'),
  ValueKey('toolbar-alignment'),
  ValueKey('toolbar-view-switch'),
];

void _setWindow(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
}

Future<ProviderContainer> _pump(WidgetTester tester, double width) async {
  _setWindow(tester, width);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(FakeProtocolService()),
        alignmentProvider.overrideWith(_FakeAlignment.new),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              MainToolbar(),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MainToolbar)));
}

Future<void> _setGroups(WidgetTester tester, ProviderContainer c, int n) async {
  final ws = c.read(workspaceProvider.notifier);
  ws.setGroups([
    for (var i = 0; i < n; i++)
      ProjectorGroup(id: 'g$i', name: 'Group $i', color: 0xFF4C8DF6),
  ]);
  ws.setNodes([node('1')]);
  await tester.pump();
}

ScheduledTask _task(int i, {bool enabled = true}) => ScheduledTask(
  id: 't$i',
  name: 'Task $i',
  command: 'PON',
  commandLabel: 'Power on',
  target: ScheduleTarget.all,
  scheduleType: ScheduleType.daily,
  timeOfDay: '22:30',
  enabled: enabled,
);

Future<void> _setTasks(WidgetTester tester, ProviderContainer c, int n) async {
  c.read(scheduledTasksProvider.notifier).loadTasks([
    for (var i = 0; i < n; i++) _task(i),
    // Disabled tasks don't count.
    _task(99, enabled: false),
  ]);
  await tester.pump();
}

Map<Key, Rect> _rects(WidgetTester tester) => {
  for (final k in _keys) k: tester.getRect(find.byKey(k)),
};

Finder _badgeText(String text) => find.descendant(
  of: find.byKey(const ValueKey('toolbar-badge')),
  matching: find.text(text),
);

bool _isCompact(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const ValueKey('toolbar-tasks')),
      matching: find.text('Scheduled tasks'),
    )
    .evaluate()
    .isEmpty;

void main() {
  useTempConfigDir();

  group('toolbarCompact', () {
    test('thresholds and hysteresis', () {
      expect(toolbarCompact(800), isTrue);
      expect(toolbarCompact(879), isTrue);
      expect(toolbarCompact(921), isFalse);
      expect(toolbarCompact(1600), isFalse);
      // In the band the current mode stays.
      expect(toolbarCompact(881, wasCompact: false), isFalse);
      expect(toolbarCompact(919, wasCompact: true), isTrue);
      expect(toolbarCompact(879, wasCompact: false), isTrue);
      expect(toolbarCompact(921, wasCompact: true), isFalse);
    });
  });

  group('MainToolbar', () {
    testWidgets('52 px high, labels per §7f.1', (tester) async {
      await _pump(tester, 1600);
      expect(tester.getSize(find.byType(MainToolbar)).height, 52);
      for (final label in [
        'Add projectors',
        'Groups',
        'Scheduled tasks',
        'Alignment',
        'Controls',
        'Monitoring',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('toolbar-groups'))).height,
        36,
      );
    });

    testWidgets('compact from the window width, with hysteresis', (
      tester,
    ) async {
      await _pump(tester, 1180);
      expect(_isCompact(tester), isFalse);

      Future<bool> resize(double w) async {
        _setWindow(tester, w);
        await tester.pump();
        return _isCompact(tester);
      }

      expect(await resize(921), isFalse);
      expect(await resize(881), isFalse, reason: 'band keeps full');
      expect(await resize(879), isTrue);
      expect(await resize(881), isTrue, reason: 'band keeps compact');
      expect(await resize(919), isTrue);
      expect(await resize(921), isFalse);
      expect(await resize(800), isTrue);
      expect(await resize(1600), isFalse);

      // Compact: icon-only 38 px tools; Add projectors and the view switch
      // keep their labels.
      await resize(800);
      for (final k in const [
        ValueKey('toolbar-groups'),
        ValueKey('toolbar-tasks'),
        ValueKey('toolbar-alignment'),
      ]) {
        expect(tester.getSize(find.byKey(k)), const Size(38, 36));
      }
      expect(find.text('Add projectors'), findsOneWidget);
      expect(find.text('Monitoring'), findsOneWidget);
    });

    testWidgets('fits 800 in compact mode without overflow or clipping', (
      tester,
    ) async {
      final c = await _pump(tester, 800);
      await _setGroups(tester, c, 12);
      await _setTasks(tester, c, 12);
      expect(tester.takeException(), isNull);
      final alignment = tester.getRect(
        find.byKey(const ValueKey('toolbar-alignment')),
      );
      final viewSwitch = tester.getRect(
        find.byKey(const ValueKey('toolbar-view-switch')),
      );
      expect(alignment.right, lessThan(viewSwitch.left));
      expect(viewSwitch.right, lessThanOrEqualTo(800));
    });

    for (final width in [800.0, 1180.0, 1600.0]) {
      testWidgets('badges never move a button (window $width)', (tester) async {
        final c = await _pump(tester, width);
        final before = _rects(tester);
        expect(find.byKey(const ValueKey('toolbar-badge')), findsNothing);

        for (final n in [1, 9, 12, 0, 4]) {
          await _setGroups(tester, c, n);
          await _setTasks(tester, c, n);
          expect(_rects(tester), before, reason: 'count $n');
        }
        expect(_badgeText('4'), findsNWidgets(2));

        await _setGroups(tester, c, 12);
        expect(_badgeText('9+'), findsOneWidget);
        expect(_rects(tester), before);

        await _setGroups(tester, c, 0);
        await _setTasks(tester, c, 0);
        expect(find.byKey(const ValueKey('toolbar-badge')), findsNothing);
        expect(_rects(tester), before);
      });

      testWidgets('Alignment on/off never changes a size (window $width)', (
        tester,
      ) async {
        final c = await _pump(tester, width);
        final before = _rects(tester);
        final fake = c.read(alignmentProvider.notifier) as _FakeAlignment;

        fake.setActive(true);
        await tester.pump();
        expect(_rects(tester), before);
        final fill = tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('toolbar-alignment')),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        expect(fill, AppTheme.darkTheme.colorScheme.primaryContainer);

        fake.setActive(false);
        await tester.pump();
        expect(_rects(tester), before);
      });
    }

    testWidgets('the badge is the same size for 1 and 9', (tester) async {
      final c = await _pump(tester, 1600);
      await _setGroups(tester, c, 1);
      final one = tester.getSize(find.byKey(const ValueKey('toolbar-badge')));
      await _setGroups(tester, c, 9);
      final nine = tester.getSize(find.byKey(const ValueKey('toolbar-badge')));
      expect(one, nine);
      expect(one.height, 17);
      expect(one.width, greaterThanOrEqualTo(17));
    });

    testWidgets('view switch changes the view', (tester) async {
      final c = await _pump(tester, 1180);
      await tester.tap(find.text('Monitoring'));
      await tester.pump();
      expect(c.read(appSettingsProvider).isMonitoringView, isTrue);
      await tester.tap(find.text('Controls'));
      await tester.pump();
      expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
    });
  });
}
