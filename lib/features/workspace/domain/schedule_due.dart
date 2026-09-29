import 'scheduled_task.dart';

/// Whether [task] should fire on the scheduler tick at [now]. The scheduler
/// ticks once per wall-clock minute; daily/weekly tasks match on that exact
/// minute and are guarded against firing twice within it by [lastRunAt].
bool isTaskDue(ScheduledTask task, DateTime now) {
  switch (task.scheduleType) {
    case ScheduleType.once:
      if (task.oneTimeAt == null || task.lastRunAt != null) return false;
      return now.isAfter(task.oneTimeAt!);

    case ScheduleType.daily:
      if (task.timeOfDay == null) return false;
      final (dh, dm) = _parseTime(task.timeOfDay!);
      return now.hour == dh &&
          now.minute == dm &&
          !_ranThisMinute(task.lastRunAt, now);

    case ScheduleType.weekly:
      if (task.timeOfDay == null ||
          task.weekdays == null ||
          task.weekdays!.isEmpty) {
        return false;
      }
      if (!task.weekdays!.contains(now.weekday)) return false;
      final (wh, wm) = _parseTime(task.timeOfDay!);
      return now.hour == wh &&
          now.minute == wm &&
          !_ranThisMinute(task.lastRunAt, now);
  }
}

(int, int) _parseTime(String timeOfDay) {
  final parts = timeOfDay.split(':');
  return (int.parse(parts[0]), int.parse(parts[1]));
}

bool _ranThisMinute(DateTime? lastRunAt, DateTime now) {
  if (lastRunAt == null) return false;
  return lastRunAt.year == now.year &&
      lastRunAt.month == now.month &&
      lastRunAt.day == now.day &&
      lastRunAt.hour == now.hour &&
      lastRunAt.minute == now.minute;
}
