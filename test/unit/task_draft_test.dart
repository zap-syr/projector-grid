import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_commands.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/domain/task_draft.dart';

const _groups = [
  ProjectorGroup(id: 'g1', name: 'Main stage', color: 0),
  ProjectorGroup(id: 'g2', name: 'Left wall', color: 0),
];
final _catalog = scheduledCommandCatalog(const []);
final _powerOn = _catalog.first;

void main() {
  final now = DateTime(2026, 10, 19, 12);

  group('errors', () {
    test('a blank draft needs a command only', () {
      expect(const TaskDraft.blank().errors(now), [DraftError.command]);
    });

    test('a typed command needs a name and a string', () {
      final d = const TaskDraft(useCommandString: true);
      expect(d.errors(now), [DraftError.commandName, DraftError.commandString]);
      expect(
        d.copyWith(stringName: 'Lamp eco', stringCommand: 'OLP:1').errors(now),
        isEmpty,
      );
    });

    test('groups, date, past date, days', () {
      final d = TaskDraft(command: _powerOn);
      expect(d.copyWith(target: ScheduleTarget.group).errors(now), [
        DraftError.groups,
      ]);
      expect(d.copyWith(scheduleType: ScheduleType.once).errors(now), [
        DraftError.date,
      ]);
      expect(
        d
            .copyWith(
              scheduleType: ScheduleType.once,
              date: DateTime(2026, 10, 19),
              hour: 11,
            )
            .errors(now),
        [DraftError.datePast],
      );
      expect(
        d.copyWith(scheduleType: ScheduleType.weekly, weekdays: {}).errors(now),
        [DraftError.days],
      );
    });
  });

  test('hidden fields do not make a draft differ', () {
    final a = TaskDraft(command: _powerOn);
    expect(a.copyWith(stringName: 'x', date: DateTime(2026)), a);
    expect(a.copyWith(groupIds: {'g1'}), a);
    expect(a.copyWith(weekdays: {6}), a);
    expect(a.copyWith(hour: 9), isNot(a));
    expect(a.copyWith(enabled: false), isNot(a));
  });

  test('to a task and back', () {
    final draft = TaskDraft(
      command: _powerOn,
      target: ScheduleTarget.group,
      // Out of project order: saved in project order.
      groupIds: const {'g2', 'g1'},
      scheduleType: ScheduleType.weekly,
      weekdays: const {5, 1},
      hour: 7,
      minute: 45,
    );
    final task = draft.toTask(id: 't', groups: _groups);
    expect(task.name, 'Power on, 07:45');
    expect(task.command, 'PON');
    expect(task.targetGroupIds, ['g1', 'g2']);
    expect(task.timeOfDay, '07:45');
    expect(task.weekdays, [1, 5]);
    expect(task.oneTimeAt, isNull);
    expect(TaskDraft.fromTask(task, _catalog, _groups), draft);
  });

  test('a one-time task is scheduled afresh', () {
    final previous = ScheduledTask(
      id: 't',
      name: '',
      command: 'PON',
      commandLabel: 'Power on',
      target: ScheduleTarget.all,
      scheduleType: ScheduleType.once,
      oneTimeAt: DateTime(2026, 10, 10, 18),
      lastRunAt: DateTime(2026, 10, 10, 18),
      enabled: false,
    );
    final draft = TaskDraft.fromTask(
      previous,
      _catalog,
      _groups,
    ).copyWith(date: DateTime(2026, 10, 25), enabled: true);
    final task = draft.toTask(id: 't', groups: _groups, previous: previous);
    expect(task.oneTimeAt, DateTime(2026, 10, 25, 18));
    expect(task.lastRunAt, isNull);
    expect(task.enabled, isTrue);
  });

  test('a command not in the catalog loads as a command string', () {
    const task = ScheduledTask(
      id: 't',
      name: '',
      command: 'VXX:LPMI1=1',
      commandLabel: 'Lamp mode',
      target: ScheduleTarget.group,
      targetGroupIds: ['g1', 'gone'],
      scheduleType: ScheduleType.daily,
      timeOfDay: '22:30',
    );
    final draft = TaskDraft.fromTask(task, _catalog, _groups);
    expect(draft.useCommandString, isTrue);
    expect(draft.stringName, 'Lamp mode');
    expect(draft.stringCommand, 'VXX:LPMI1=1');
    expect(draft.groupIds, {'g1'});
    expect((draft.hour, draft.minute), (22, 30));
  });

  test('next run of the draft', () {
    final daily = TaskDraft(command: _powerOn, hour: 13);
    expect(daily.nextRun(now), DateTime(2026, 10, 19, 13));
    final once = daily.copyWith(
      scheduleType: ScheduleType.once,
      date: DateTime(2026, 10, 18),
    );
    expect(once.nextRun(now), isNull);
  });
}
