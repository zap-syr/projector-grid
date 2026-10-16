import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/schedule_next_run.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';

ScheduledTask _task(
  ScheduleType type, {
  String? time,
  List<int>? weekdays,
  DateTime? at,
  DateTime? lastRunAt,
  bool enabled = true,
}) => ScheduledTask(
  id: '$type$time$at',
  name: 'Task',
  command: 'PON',
  commandLabel: 'Power on',
  target: ScheduleTarget.all,
  scheduleType: type,
  timeOfDay: time,
  weekdays: weekdays,
  oneTimeAt: at,
  lastRunAt: lastRunAt,
  enabled: enabled,
);

void main() {
  // Wednesday 2026-10-14, 21:00.
  final now = DateTime(2026, 10, 14, 21);

  group('nextScheduledRun', () {
    test('daily: today when still ahead, else tomorrow', () {
      expect(
        nextScheduledRun([_task(ScheduleType.daily, time: '22:30')], now),
        DateTime(2026, 10, 14, 22, 30),
      );
      expect(
        nextScheduledRun([_task(ScheduleType.daily, time: '07:00')], now),
        DateTime(2026, 10, 15, 7),
      );
    });

    test('weekly: the next listed weekday, a week on for today past', () {
      expect(
        nextScheduledRun([
          _task(
            ScheduleType.weekly,
            time: '09:00',
            weekdays: [DateTime.monday],
          ),
        ], now),
        DateTime(2026, 10, 19, 9),
      );
      expect(
        nextScheduledRun([
          _task(
            ScheduleType.weekly,
            time: '20:00',
            weekdays: [DateTime.wednesday],
          ),
        ], now),
        DateTime(2026, 10, 21, 20),
      );
      expect(
        nextScheduledRun([
          _task(ScheduleType.weekly, time: '20:00', weekdays: []),
        ], now),
        isNull,
      );
    });

    test('once: only a future run that has not happened', () {
      final future = DateTime(2026, 11, 2, 8);
      expect(
        nextScheduledRun([_task(ScheduleType.once, at: future)], now),
        future,
      );
      expect(
        nextScheduledRun([
          _task(ScheduleType.once, at: DateTime(2026, 10, 1)),
        ], now),
        isNull,
      );
      expect(
        nextScheduledRun([
          _task(ScheduleType.once, at: future, lastRunAt: now),
        ], now),
        isNull,
      );
    });

    test('the earliest enabled task wins; disabled ones are skipped', () {
      expect(
        nextScheduledRun([
          _task(ScheduleType.daily, time: '07:00'),
          _task(ScheduleType.daily, time: '21:30', enabled: false),
          _task(ScheduleType.daily, time: '23:00'),
        ], now),
        DateTime(2026, 10, 14, 23),
      );
      expect(nextScheduledRun(const [], now), isNull);
    });
  });

  group('describeRunTime', () {
    test('today, tomorrow, this week, later', () {
      expect(describeRunTime(DateTime(2026, 10, 14, 22, 30), now), 'at 22:30');
      expect(
        describeRunTime(DateTime(2026, 10, 15, 7), now),
        'tomorrow at 07:00',
      );
      expect(
        describeRunTime(DateTime(2026, 10, 19, 9, 5), now),
        'on Mon at 09:05',
      );
      expect(
        describeRunTime(DateTime(2026, 11, 2, 8), now),
        'on 2 Nov at 08:00',
      );
    });
  });
}
