import 'scheduled_task.dart';

/// The next time an enabled task in [tasks] fires after [now], or null when
/// none will. A one-time task already past its time is left out: the
/// scheduler runs it on its next tick, which changes the task list anyway.
DateTime? nextScheduledRun(Iterable<ScheduledTask> tasks, DateTime now) {
  DateTime? next;
  for (final task in tasks) {
    if (!task.enabled) continue;
    final at = _nextRunOf(task, now);
    if (at != null && (next == null || at.isBefore(next))) next = at;
  }
  return next;
}

DateTime? _nextRunOf(ScheduledTask task, DateTime now) {
  switch (task.scheduleType) {
    case ScheduleType.once:
      final at = task.oneTimeAt;
      if (at == null || task.lastRunAt != null || !at.isAfter(now)) {
        return null;
      }
      return at;
    case ScheduleType.daily:
    case ScheduleType.weekly:
      final time = task.timeOfDay;
      if (time == null) return null;
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final weekdays = task.scheduleType == ScheduleType.weekly
          ? task.weekdays
          : null;
      if (task.scheduleType == ScheduleType.weekly &&
          (weekdays == null || weekdays.isEmpty)) {
        return null;
      }
      // Eight days: today's time may already be past, and a weekly task on
      // today's weekday then comes back a week later.
      for (var d = 0; d < 8; d++) {
        final at = DateTime(now.year, now.month, now.day + d, hour, minute);
        if (!at.isAfter(now)) continue;
        if (weekdays != null && !weekdays.contains(at.weekday)) continue;
        return at;
      }
      return null;
  }
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// When [at] is, as read from [now]: `at 22:30` today, `tomorrow at 07:00`,
/// `on Mon at 22:30` within the week, `on 12 Nov at 22:30` further out.
String describeRunTime(DateTime at, DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(at.hour)}:${two(at.minute)}';
  final days = DateTime(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime(now.year, now.month, now.day)).inHours;
  // inHours / 24 rounded: a DST change makes a day 23 or 25 hours long.
  final dayOffset = (days / 24).round();
  if (dayOffset <= 0) return 'at $time';
  if (dayOffset == 1) return 'tomorrow at $time';
  if (dayOffset < 7) return 'on ${_weekdayNames[at.weekday - 1]} at $time';
  return 'on ${at.day} ${_monthNames[at.month - 1]} at $time';
}
