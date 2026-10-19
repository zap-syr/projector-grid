import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/schedule_labels.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';

const _groups = [
  ProjectorGroup(id: 'g1', name: 'Main stage', color: 0),
  ProjectorGroup(id: 'g2', name: 'Left wall', color: 0),
  ProjectorGroup(id: 'g3', name: 'Right wall', color: 0),
];

void main() {
  group('target chip label', () {
    test('all projectors', () {
      expect(
        targetLabel(ScheduleTarget.all, const [], _groups),
        'All projectors',
      );
    });

    test('one group: its name', () {
      expect(targetLabel(ScheduleTarget.group, ['g1'], _groups), 'Main stage');
    });

    test('several groups: their count', () {
      expect(
        targetLabel(ScheduleTarget.group, ['g1', 'g3'], _groups),
        '2 groups',
      );
      expect(
        targetLabel(ScheduleTarget.group, ['g1', 'g2', 'g3'], _groups),
        '3 groups',
      );
    });

    test('deleted groups are not counted', () {
      expect(
        targetLabel(ScheduleTarget.group, ['g1', 'gone'], _groups),
        'Main stage',
      );
      expect(targetLabel(ScheduleTarget.group, ['gone'], _groups), 'No target');
      expect(targetLabel(ScheduleTarget.group, const [], _groups), 'No target');
    });

    test('target groups come in project order', () {
      expect(targetGroupsOf(['g3', 'g1'], _groups).map((g) => g.name), [
        'Main stage',
        'Right wall',
      ]);
    });
  });

  test('dates and times', () {
    final d = DateTime(2026, 10, 13, 8);
    expect(formatDayDate(d), 'Tue 13 Oct');
    expect(formatDayDateTime(d), 'Tue 13 Oct, 08:00');
    expect(formatHm(7, 5), '07:05');
  });

  test('next run on a card', () {
    final now = DateTime(2026, 10, 12, 9);
    expect(nextRunShort(DateTime(2026, 10, 12, 22, 30), now), 'Next: today');
    expect(nextRunShort(DateTime(2026, 10, 13, 8), now), 'Next: tomorrow');
    expect(nextRunShort(DateTime(2026, 10, 14, 8), now), 'Next: Wed 14 Oct');
  });

  test('schedule line and weekday presets', () {
    ScheduledTask task(ScheduleType type, {List<int>? days, DateTime? at}) =>
        ScheduledTask(
          id: 't',
          name: '',
          command: 'PON',
          commandLabel: 'Power on',
          target: ScheduleTarget.all,
          scheduleType: type,
          timeOfDay: '08:00',
          weekdays: days,
          oneTimeAt: at,
        );
    expect(scheduleLine(task(ScheduleType.daily)), 'Every day');
    expect(
      scheduleLine(task(ScheduleType.once, at: DateTime(2026, 10, 18, 18))),
      'Once, Sun 18 Oct',
    );
    expect(
      scheduleLine(task(ScheduleType.weekly, days: [1, 2, 3, 4, 5])),
      'Weekdays',
    );
    expect(weekdaysLabel([7, 6]), 'Weekend');
    expect(weekdaysLabel([1, 2, 3, 4, 5, 6, 7]), 'Every day');
    expect(weekdaysLabel([4, 1]), 'Mon, Thu');
  });

  test('short label: command and time, built-in wording', () {
    const task = ScheduledTask(
      id: 't',
      name: 'Shutter Close - Left Wall - Daily 22:30',
      command: 'OSH:1',
      commandLabel: 'Shutter Close',
      target: ScheduleTarget.all,
      scheduleType: ScheduleType.daily,
      timeOfDay: '22:30',
    );
    expect(taskShortLabel(task), 'Shutter close, 22:30');
  });
}
