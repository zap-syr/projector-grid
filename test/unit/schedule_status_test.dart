import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/schedule_status.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';

ScheduledTask _task(
  String id, {
  ScheduleType type = ScheduleType.daily,
  String? timeOfDay = '08:00',
  DateTime? oneTimeAt,
  DateTime? lastRunAt,
  bool enabled = true,
  ScheduleTarget target = ScheduleTarget.all,
  List<String> groupIds = const [],
}) => ScheduledTask(
  id: id,
  name: id,
  command: 'PON',
  commandLabel: 'Power on',
  target: target,
  targetGroupIds: groupIds,
  scheduleType: type,
  timeOfDay: type == ScheduleType.once ? null : timeOfDay,
  oneTimeAt: oneTimeAt,
  lastRunAt: lastRunAt,
  enabled: enabled,
);

void main() {
  // A Monday.
  final now = DateTime(2026, 10, 19, 12);

  group('one-time task status', () {
    final at = DateTime(2026, 10, 19, 11, 59);

    test('within the 2-minute grace it is still active', () {
      final t = _task('a', type: ScheduleType.once, oneTimeAt: at);
      expect(taskStatusOf(t, now), TaskStatus.active);
    });

    test('past the grace without a run it is not run', () {
      final t = _task(
        'a',
        type: ScheduleType.once,
        oneTimeAt: now.subtract(const Duration(minutes: 3)),
      );
      expect(taskStatusOf(t, now), TaskStatus.notRun);
      expect(isTaskFinished(t, now), isTrue);
    });

    test('a paused one-time task past its time is not run too', () {
      final t = _task(
        'a',
        type: ScheduleType.once,
        oneTimeAt: DateTime(2026, 10, 8, 18),
        enabled: false,
      );
      expect(taskStatusOf(t, now), TaskStatus.notRun);
    });

    test('one that ran is completed', () {
      final t = _task(
        'a',
        type: ScheduleType.once,
        oneTimeAt: DateTime(2026, 10, 10, 18),
        lastRunAt: DateTime(2026, 10, 10, 18, 0, 1),
        enabled: false,
      );
      expect(taskStatusOf(t, now), TaskStatus.completed);
    });

    test('a future one is active or paused', () {
      final future = DateTime(2026, 10, 20, 9);
      expect(
        taskStatusOf(
          _task('a', type: ScheduleType.once, oneTimeAt: future),
          now,
        ),
        TaskStatus.active,
      );
      expect(
        taskStatusOf(
          _task(
            'a',
            type: ScheduleType.once,
            oneTimeAt: future,
            enabled: false,
          ),
          now,
        ),
        TaskStatus.paused,
      );
    });
  });

  test('a group task without groups is paused', () {
    final t = _task('a', target: ScheduleTarget.group);
    expect(taskStatusOf(t, now), TaskStatus.paused);
  });

  test('list order: active by next run, paused after, finished apart', () {
    final tasks = [
      _task('paused', timeOfDay: '13:00', enabled: false),
      _task('later', timeOfDay: '09:00'), // tomorrow
      _task('soon', timeOfDay: '12:30'), // today
      _task(
        'ran',
        type: ScheduleType.once,
        oneTimeAt: DateTime(2026, 10, 10, 18),
        lastRunAt: DateTime(2026, 10, 10, 18),
        enabled: false,
      ),
      _task(
        'missed',
        type: ScheduleType.once,
        oneTimeAt: DateTime(2026, 10, 15, 8),
      ),
    ];
    final (:open, :finished) = orderTaskList(tasks, now);
    expect(open.map((t) => t.id), ['soon', 'later', 'paused']);
    expect(finished.map((t) => t.id), ['missed', 'ran']);
  });
}
