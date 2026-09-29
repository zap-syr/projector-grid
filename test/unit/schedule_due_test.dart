import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/schedule_due.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';

ScheduledTask _task({
  ScheduleType type = ScheduleType.daily,
  DateTime? oneTimeAt,
  String? timeOfDay = '08:30',
  List<int>? weekdays,
  DateTime? lastRunAt,
}) => ScheduledTask(
  id: 't1',
  name: 'Morning on',
  command: 'PON',
  commandLabel: 'Power On',
  target: ScheduleTarget.all,
  scheduleType: type,
  oneTimeAt: oneTimeAt,
  timeOfDay: timeOfDay,
  weekdays: weekdays,
  lastRunAt: lastRunAt,
);

void main() {
  // 2026-09-28 is a Monday.
  final monday0830 = DateTime(2026, 9, 28, 8, 30);

  group('once', () {
    final at = DateTime(2026, 9, 28, 8, 30);

    test('due after its time, not before', () {
      final t = _task(type: ScheduleType.once, oneTimeAt: at);
      expect(isTaskDue(t, at.subtract(const Duration(minutes: 1))), isFalse);
      expect(isTaskDue(t, at.add(const Duration(seconds: 1))), isTrue);
    });

    test('a missed run still fires on the next tick', () {
      final t = _task(type: ScheduleType.once, oneTimeAt: at);
      expect(isTaskDue(t, at.add(const Duration(hours: 5))), isTrue);
    });

    test('never fires twice', () {
      final t = _task(
        type: ScheduleType.once,
        oneTimeAt: at,
        lastRunAt: at.add(const Duration(minutes: 1)),
      );
      expect(isTaskDue(t, at.add(const Duration(hours: 1))), isFalse);
    });

    test('without a time it is never due', () {
      expect(isTaskDue(_task(type: ScheduleType.once), monday0830), isFalse);
    });
  });

  group('daily', () {
    test('due only on its exact minute', () {
      final t = _task();
      expect(isTaskDue(t, monday0830), isTrue);
      expect(isTaskDue(t, monday0830.add(const Duration(seconds: 59))), isTrue);
      expect(isTaskDue(t, monday0830.add(const Duration(minutes: 1))), isFalse);
      expect(
        isTaskDue(t, monday0830.subtract(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('does not re-fire within the same minute', () {
      final t = _task(lastRunAt: monday0830);
      expect(
        isTaskDue(t, monday0830.add(const Duration(seconds: 30))),
        isFalse,
      );
    });

    test('fires again the next day', () {
      final t = _task(lastRunAt: monday0830);
      expect(isTaskDue(t, monday0830.add(const Duration(days: 1))), isTrue);
    });

    test('missed minute is not caught up (current behaviour)', () {
      expect(isTaskDue(_task(), DateTime(2026, 9, 28, 8, 31)), isFalse);
    });
  });

  group('weekly', () {
    test('due on a listed weekday at its minute', () {
      final t = _task(type: ScheduleType.weekly, weekdays: [DateTime.monday]);
      expect(isTaskDue(t, monday0830), isTrue);
    });

    test('not due on an unlisted weekday', () {
      final t = _task(type: ScheduleType.weekly, weekdays: [DateTime.tuesday]);
      expect(isTaskDue(t, monday0830), isFalse);
      expect(isTaskDue(t, monday0830.add(const Duration(days: 1))), isTrue);
    });

    test('empty or missing weekdays is never due', () {
      expect(
        isTaskDue(_task(type: ScheduleType.weekly, weekdays: []), monday0830),
        isFalse,
      );
      expect(isTaskDue(_task(type: ScheduleType.weekly), monday0830), isFalse);
    });
  });

  // IMPROVEMENT_PLAN.md item 10: on the spring-forward night the scheduler
  // never ticks at 02:xx, so a 02:30 daily task is skipped with no log
  // entry. Simulates the ticks the scheduler actually sees (01:59 → 03:00)
  // rather than relying on the test machine's time zone.
  test('DST spring-forward: a task in the skipped hour still fires once', () {
    final t = _task(timeOfDay: '02:30');
    final ticks = [
      for (var m = 0; m < 60; m++) DateTime(2026, 3, 29, 1, m),
      for (var m = 0; m < 60; m++) DateTime(2026, 3, 29, 3, m),
    ];
    expect(ticks.where((now) => isTaskDue(t, now)), hasLength(1));
  }, skip: 'Known bug, IMPROVEMENT_PLAN.md item 10 — unskip once fixed');
}
