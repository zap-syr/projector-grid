import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/scheduled_tasks/scheduled_tasks_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _main = ProjectorGroup(id: 'g1', name: 'Main stage', color: 0xFF3B82F6);
const _left = ProjectorGroup(id: 'g2', name: 'Left wall', color: 0xFFF97316);

ScheduledTask _daily(
  String id, {
  String command = 'PON',
  String label = 'Power on',
  String time = '08:00',
  bool enabled = true,
  List<String> groups = const [],
}) => ScheduledTask(
  id: id,
  name: '$label, $time',
  command: command,
  commandLabel: label,
  target: groups.isEmpty ? ScheduleTarget.all : ScheduleTarget.group,
  targetGroupIds: groups,
  scheduleType: ScheduleType.daily,
  timeOfDay: time,
  enabled: enabled,
);

ScheduledTask _once(String id, DateTime at, {DateTime? ranAt}) => ScheduledTask(
  id: id,
  name: 'HDMI 1',
  command: 'IIS:HD1',
  commandLabel: 'HDMI 1',
  target: ScheduleTarget.all,
  scheduleType: ScheduleType.once,
  oneTimeAt: at,
  lastRunAt: ranAt,
  enabled: ranAt == null,
);

Finder _card(String id) => find.byKey(ValueKey('task-card-$id'));
Finder get _primary => find.byKey(const ValueKey('editor-primary'));
Finder get _secondary => find.byKey(const ValueKey('editor-secondary'));
Finder get _newTask => find.byKey(const ValueKey('new-task'));
Finder _timeInput() => find.descendant(
  of: find.byKey(const ValueKey('task-time')),
  matching: find.byType(TextField),
);

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('editor-title'))).data!;

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

/// A footer button's label: the last text in it, the first being the
/// invisible widest label that holds the button's width.
String _label(WidgetTester tester, Finder button) => tester
    .widgetList<Text>(find.descendant(of: button, matching: find.byType(Text)))
    .last
    .data!;

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<ScheduledTask> tasks = const [],
  List<ProjectorGroup> groups = const [_main, _left],
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
                builder: (_) => const ScheduledTasksDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  final c = ProviderScope.containerOf(tester.element(find.text('open')));
  c.listen(workspaceProvider, (_, _) {});
  final ws = c.read(workspaceProvider.notifier);
  ws.setGroups(groups);
  ws.setNodes([
    for (var i = 1; i <= 6; i++)
      node('$i', groupId: i <= 2 ? 'g1' : (i == 3 ? 'g2' : null)),
  ]);
  c.read(scheduledTasksProvider.notifier).loadTasks(tasks);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  useTempConfigDir();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('on open', () {
    testWidgets('no tasks: the empty state, the list\'s New task only', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester);
      expect(find.text('No scheduled tasks'), findsOneWidget);
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.text(
          'Send a command to all projectors or to groups at a set time: '
          'once, daily or weekly.',
        ),
        findsOneWidget,
      );
      expect(find.text('New task'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new-task')));
      await tester.pumpAndSettle();
      expect(_title(tester), 'New task');
      expect(_card('new'), findsOneWidget);
      expect(find.text('No tasks yet'), findsNothing);
    });

    testWidgets('tasks: nothing selected, a summary instead', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(
        tester,
        tasks: [
          _daily('a'),
          _daily('b', time: '22:30'),
          _daily('c', enabled: false),
        ],
      );
      expect(find.text('2 active, 1 paused'), findsOneWidget);
      expect(find.textContaining('Next run '), findsOneWidget);
      expect(find.text('Select a task to edit it.'), findsOneWidget);
      expect(find.text('3 tasks, 2 active'), findsOneWidget);
      expect(_primary, findsNothing);
    });

    testWidgets('no next run line while nothing is active', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester, tasks: [_daily('c', enabled: false)]);
      expect(find.text('0 active, 1 paused'), findsOneWidget);
      expect(find.textContaining('Next run '), findsNothing);
    });
  });

  testWidgets('select, edit, save', (tester) async {
    _useWindow(tester, const Size(1280, 900));
    final c = await _pump(tester, tasks: [_daily('a')]);

    await tester.tap(_card('a'));
    await tester.pumpAndSettle();
    expect(_title(tester), 'Power on, All projectors');
    expect(_enabled(tester, _primary), isFalse, reason: 'nothing changed');

    await tester.enterText(_timeInput(), '0930');
    await tester.tap(find.byKey(const ValueKey('target-groups')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('target-group-g2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('target-group-g1')));
    await tester.pumpAndSettle();
    expect(_title(tester), 'Power on, 2 groups');
    expect(find.text('2 of 2 selected, 3 projectors'), findsOneWidget);
    expect(_enabled(tester, _primary), isTrue);

    await tester.tap(_primary);
    await tester.pumpAndSettle();
    final task = c.read(scheduledTasksProvider).single;
    expect(task.timeOfDay, '09:30');
    expect(task.target, ScheduleTarget.group);
    // Project order, not the order they were clicked in.
    expect(task.targetGroupIds, ['g1', 'g2']);
    expect(task.name, 'Power on, 09:30');
    expect(_enabled(tester, _primary), isFalse, reason: 'saved');
    expect(
      find.descendant(of: _card('a'), matching: find.text('2 groups')),
      findsOneWidget,
    );
  });

  testWidgets('Revert puts the saved values back', (tester) async {
    _useWindow(tester, const Size(1280, 900));
    await _pump(tester, tasks: [_daily('a')]);
    await tester.tap(_card('a'));
    await tester.pumpAndSettle();
    await tester.enterText(_timeInput(), '1015');
    await tester.pump();
    await tester.tap(_secondary);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_timeInput()).controller!.text, '08:00');
    expect(_enabled(tester, _primary), isFalse);
  });

  group('Discard changes', () {
    testWidgets('on selecting another task', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(
        tester,
        tasks: [
          _daily('a'),
          _daily('b', command: 'OSH:1', label: 'Shutter close', time: '22:30'),
        ],
      );
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();
      await tester.enterText(_timeInput(), '0930');
      await tester.pump();

      await tester.tap(_card('b'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes to “Power on, 08:00”?'), findsOne);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(_title(tester), 'Power on, All projectors');
      expect(tester.widget<TextField>(_timeInput()).controller!.text, '09:30');

      await tester.tap(_card('b'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(_title(tester), 'Shutter close, All projectors');
    });

    testWidgets('New task waits while Save changes can be pressed', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester, tasks: [_daily('a')]);
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();
      expect(_enabled(tester, _newTask), isTrue);

      await tester.enterText(_timeInput(), '0930');
      await tester.pump();
      expect(_enabled(tester, _primary), isTrue);
      expect(_enabled(tester, _newTask), isFalse);

      await tester.tap(_secondary);
      await tester.pumpAndSettle();
      expect(_enabled(tester, _newTask), isTrue);
    });

    testWidgets('on closing, with ✕ or Esc', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester, tasks: [_daily('a')]);
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();
      await tester.enterText(_timeInput(), '0930');
      await tester.pump();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard changes'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduledTasksDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard changes'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduledTasksDialog), findsNothing);
    });

    testWidgets('no question when nothing changed', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(
        tester,
        tasks: [
          _daily('a'),
          _daily('b', time: '09:00'),
        ],
      );
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();
      await tester.tap(_card('b'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard changes'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduledTasksDialog), findsNothing);
    });
  });

  group('command picker', () {
    testWidgets('filters and picks', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester, tasks: [_daily('a')]);
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('command-field')));
      await tester.pumpAndSettle();
      expect(find.text('Search commands'), findsOneWidget);
      // No command codes anywhere in the panel.
      expect(find.text('PON'), findsNothing);
      expect(find.text('IIS:HD1'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('command-search')),
        'hdmi',
      );
      await tester.pumpAndSettle();
      expect(find.text('HDMI 1'), findsOneWidget);
      expect(find.text('HDMI 2'), findsOneWidget);
      expect(find.text('Standby'), findsNothing);

      await tester.tap(find.text('HDMI 2'));
      await tester.pumpAndSettle();
      expect(find.text('Search commands'), findsNothing);
      expect(_title(tester), 'HDMI 2, All projectors');

      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(c.read(scheduledTasksProvider).single.command, 'IIS:HD2');
    });

    testWidgets('keyboard: arrows, Enter, Esc', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester, tasks: [_daily('a')]);
      await tester.tap(_card('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('command-field')));
      await tester.pumpAndSettle();

      // The search has the focus on open.
      await tester.enterText(
        find.byKey(const ValueKey('command-search')),
        'shutter',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_title(tester), 'Shutter close, All projectors');

      await tester.tap(find.byKey(const ValueKey('command-field')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Search commands'), findsNothing);
      // Esc closed the panel, not the dialog.
      expect(find.byType(ScheduledTasksDialog), findsOneWidget);
    });

    testWidgets('a typed command string', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester);
      await tester.tap(_newTask);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('command-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter a command string…'));
      await tester.pumpAndSettle();

      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsWidgets);
      expect(find.text('Command string is required'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('command-string-name')),
        'Lamp eco',
      );
      await tester.enterText(
        find.byKey(const ValueKey('command-string-value')),
        'OLP:1',
      );
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      final task = c.read(scheduledTasksProvider).single;
      expect((task.commandLabel, task.command), ('Lamp eco', 'OLP:1'));
    });
  });

  testWidgets('new task: validation, then create', (tester) async {
    _useWindow(tester, const Size(1280, 900));
    final c = await _pump(tester, tasks: [_daily('a')]);

    await tester.tap(_newTask);
    await tester.pumpAndSettle();
    expect(_card('new'), findsOneWidget);
    expect(_enabled(tester, _newTask), isFalse);
    expect(_title(tester), 'New task');

    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(find.text('Select a command'), findsOneWidget);
    expect(c.read(scheduledTasksProvider), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('command-field')));
    await tester.pumpAndSettle();
    // Power and Shutter tiles read as on the control bar: icon and word,
    // the section header carries the rest.
    expect(find.text('Power standby'), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.text('Standby'));
    await tester.pumpAndSettle();
    expect(find.text('Select a command'), findsNothing);
    await tester.enterText(_timeInput(), '2300');
    await tester.tap(_primary);
    await tester.pumpAndSettle();

    final tasks = c.read(scheduledTasksProvider);
    expect(tasks, hasLength(2));
    expect(tasks.last.command, 'POF');
    expect(tasks.last.timeOfDay, '23:00');
    expect(_card('new'), findsNothing);
    expect(_card(tasks.last.id), findsOneWidget);
    expect(_title(tester), 'Power standby, All projectors');
    expect(_enabled(tester, _newTask), isTrue);
  });

  testWidgets('the card switch applies at once', (tester) async {
    _useWindow(tester, const Size(1280, 900));
    final c = await _pump(tester, tasks: [_daily('a')]);
    await tester.tap(
      find.descendant(of: _card('a'), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(c.read(scheduledTasksProvider).single.enabled, isFalse);
    expect(
      find.descendant(of: _card('a'), matching: find.text('Paused')),
      findsOneWidget,
    );
  });

  group('completed and not run', () {
    final ranAt = today.subtract(const Duration(days: 2, hours: -18));
    final missedAt = today.subtract(const Duration(days: 1, hours: -9));
    final tasks = [
      _daily('a'),
      _once('ran', ranAt, ranAt: ranAt),
      _once('missed', missedAt),
    ];

    testWidgets('a collapsed section with its rows', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      await _pump(tester, tasks: tasks);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('1 task, 1 active'), findsOneWidget);
      expect(_card('ran'), findsNothing);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _card('ran'),
          matching: find.textContaining('Ran '),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card('missed'),
          matching: find.textContaining('Not run, '),
        ),
        findsOneWidget,
      );
      // Neither has a switch, nor the green check on the not-run one.
      expect(
        find.descendant(of: _card('ran'), matching: find.byType(Switch)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _card('missed'),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('a not-run task is scheduled again for a new date', (
      tester,
    ) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester, tasks: tasks);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(_card('missed'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This one-time task did not run at its time. Pick a new date to '
          'schedule it again.',
        ),
        findsOneWidget,
      );
      expect(_label(tester, _secondary), 'Duplicate');
      expect(_label(tester, _primary), 'Schedule again');
      expect(_enabled(tester, _primary), isFalse, reason: 'date in the past');

      final next = today.add(const Duration(days: 10));
      String two(int v) => v.toString().padLeft(2, '0');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('task-date')),
          matching: find.byType(TextField),
        ),
        '${two(next.day)}${two(next.month)}${next.year}',
      );
      await tester.pumpAndSettle();
      expect(_enabled(tester, _primary), isTrue);
      await tester.tap(_primary);
      await tester.pumpAndSettle();

      final task = c
          .read(scheduledTasksProvider)
          .firstWhere((t) => t.id == 'missed');
      expect(task.oneTimeAt, DateTime(next.year, next.month, next.day, 9));
      expect(task.lastRunAt, isNull);
      expect(task.enabled, isTrue);
      expect(_label(tester, _primary), 'Save changes');
      expect(_label(tester, _secondary), 'Revert');
    });

    testWidgets('a completed task: the Ran pill and Duplicate', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester, tasks: tasks);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(_card('ran'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This one-time task has run.'), findsOne);

      await tester.tap(_secondary);
      await tester.pumpAndSettle();
      expect(_card('new'), findsOneWidget);
      expect(_title(tester), 'New task');
      expect(c.read(scheduledTasksProvider), hasLength(3));
    });

    testWidgets('Clear removes them after a confirm', (tester) async {
      _useWindow(tester, const Size(1280, 900));
      final c = await _pump(tester, tasks: tasks);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear completed tasks?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(c.read(scheduledTasksProvider).map((t) => t.id), ['a']);
      expect(find.text('Completed'), findsNothing);
    });
  });

  testWidgets('a task left without groups reads No target', (tester) async {
    _useWindow(tester, const Size(1280, 900));
    await _pump(
      tester,
      tasks: [
        // What a group delete leaves: group target, no groups, paused.
        _daily('a', enabled: false).copyWith(target: ScheduleTarget.group),
        _daily('b', groups: ['g1', 'g2']),
      ],
    );
    expect(
      find.descendant(of: _card('a'), matching: find.text('No target')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _card('b'), matching: find.text('2 groups')),
      findsOneWidget,
    );
    // Can't be switched on without a target.
    final toggle = tester.widget<Switch>(
      find.descendant(of: _card('a'), matching: find.byType(Switch)),
    );
    expect(toggle.onChanged, isNull);
  });

  testWidgets('cards and footer buttons keep their place across states', (
    tester,
  ) async {
    _useWindow(tester, const Size(1280, 900));
    final ranAt = today.subtract(const Duration(days: 2));
    await _pump(
      tester,
      tasks: [
        _daily('a'),
        _daily('p', enabled: false, groups: ['g1']),
        _once('ran', ranAt, ranAt: ranAt),
      ],
    );
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    final cardHeight = tester.getSize(_card('a')).height;
    expect(tester.getSize(_card('p')).height, cardHeight);
    expect(tester.getSize(_card('ran')).height, cardHeight);
    final newTaskRect = tester.getRect(_newTask);

    await tester.tap(_card('a'));
    await tester.pumpAndSettle();
    final primary = tester.getRect(_primary);
    final secondary = tester.getRect(_secondary);
    final title = tester.getTopLeft(find.byKey(const ValueKey('editor-title')));

    await tester.tap(_card('ran'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_primary), primary);
    expect(tester.getRect(_secondary), secondary);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('editor-title'))),
      title,
    );

    await tester.tap(_newTask);
    await tester.pumpAndSettle();
    expect(tester.getRect(_primary), primary);
    expect(tester.getRect(_secondary), secondary);
    expect(tester.getSize(_card('new')).height, cardHeight);
    expect(tester.getRect(_newTask), newTaskRect);

    // A validation message doesn't move them either.
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(find.text('Select a command'), findsOneWidget);
    expect(tester.getRect(_primary), primary);
  });

  for (final (name, theme) in [
    ('dark', AppTheme.darkTheme),
    ('light', AppTheme.lightTheme),
  ]) {
    testWidgets('800×600 window lays out without overflow ($name)', (
      tester,
    ) async {
      _useWindow(tester, const Size(800, 600));
      final groups = [
        for (var i = 1; i <= 12; i++)
          ProjectorGroup(
            id: 'g$i',
            name: 'A long group name $i',
            color: 0xFF3B82F6,
          ),
      ];
      await _pump(
        tester,
        theme: theme,
        groups: groups,
        tasks: [
          ScheduledTask(
            id: 'w',
            name: 'Power on, 08:00',
            command: 'PON',
            commandLabel: 'Power on',
            target: ScheduleTarget.group,
            targetGroupIds: [for (final g in groups.take(10)) g.id],
            scheduleType: ScheduleType.weekly,
            timeOfDay: '08:00',
            weekdays: const [1, 2, 3, 4, 5],
          ),
          for (var i = 0; i < 12; i++)
            _daily('d$i', time: '${(8 + i).toString().padLeft(2, '0')}:15'),
          _once('ran', today, ranAt: today),
        ],
      );
      expect(tester.takeException(), isNull);

      await tester.tap(_card('w'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Weekdays'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('command-field')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The open picker pushes When below the fold; the editor scrolls.
      await tester.ensureVisible(find.text('Once'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Once'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('task-date')), findsOneWidget);
    });
  }
}
