import 'projector_group.dart';
import 'scheduled_commands.dart';
import 'scheduled_task.dart';

const scheduleWeekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

String formatHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// `Tue 13 Oct`.
String formatDayDate(DateTime d) =>
    '${scheduleWeekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}';

/// `Tue 13 Oct, 08:00`.
String formatDayDateTime(DateTime d) =>
    '${formatDayDate(d)}, ${formatHm(d.hour, d.minute)}';

/// The task's time of day, `08:00`.
String taskTimeLabel(ScheduledTask task) {
  final at = task.oneTimeAt;
  if (task.scheduleType == ScheduleType.once && at != null) {
    return formatHm(at.hour, at.minute);
  }
  return task.timeOfDay ?? '';
}

/// The schedule as one short line: `Once, Sun 18 Oct`, `Every day`, and
/// for weekly tasks the preset name or the days (`Weekdays`, `Mon, Thu`).
String scheduleLine(ScheduledTask task) {
  switch (task.scheduleType) {
    case ScheduleType.once:
      final at = task.oneTimeAt;
      return at == null ? 'Once' : 'Once, ${formatDayDate(at)}';
    case ScheduleType.daily:
      return 'Every day';
    case ScheduleType.weekly:
      return weekdaysLabel(task.weekdays ?? const []);
  }
}

/// `Weekdays`, `Weekend`, `Every day`, or the days in week order.
String weekdaysLabel(Iterable<int> days) {
  final set = days.toSet();
  if (set.length == 7) return 'Every day';
  if (set.length == 5 && set.containsAll(const [1, 2, 3, 4, 5])) {
    return 'Weekdays';
  }
  if (set.length == 2 && set.containsAll(const [6, 7])) return 'Weekend';
  return [
    for (var d = 1; d <= 7; d++)
      if (set.contains(d)) scheduleWeekdayNames[d - 1],
  ].join(', ');
}

/// The list card's `Next: today`, `Next: tomorrow`, `Next: Tue 13 Oct`.
String nextRunShort(DateTime next, DateTime now) {
  final days = DateTime(
    next.year,
    next.month,
    next.day,
  ).difference(DateTime(now.year, now.month, now.day)).inHours;
  // Rounded: a DST change makes a day 23 or 25 hours long.
  final dayOffset = (days / 24).round();
  if (dayOffset <= 0) return 'Next: today';
  if (dayOffset == 1) return 'Next: tomorrow';
  return 'Next: ${formatDayDate(next)}';
}

/// The groups of [ids] that still exist, in the project's group order.
List<ProjectorGroup> targetGroupsOf(
  Iterable<String> ids,
  List<ProjectorGroup> groups,
) {
  final wanted = ids.toSet();
  return [
    for (final g in groups)
      if (wanted.contains(g.id)) g,
  ];
}

/// The target chip's text: `All projectors`, the group's name, `3 groups`,
/// or `No target` for a group task whose groups are all gone.
String targetLabel(
  ScheduleTarget target,
  Iterable<String> groupIds,
  List<ProjectorGroup> groups,
) {
  if (target == ScheduleTarget.all) return 'All projectors';
  final targets = targetGroupsOf(groupIds, groups);
  return switch (targets.length) {
    0 => 'No target',
    1 => targets.single.name,
    final n => '$n groups',
  };
}

/// `Shutter close, 22:30`: how a task is named in a confirmation, the event
/// log and the saved `name`.
String taskShortLabel(ScheduledTask task) =>
    '${scheduledCommandLabel(task.command, task.commandLabel)}, '
    '${taskTimeLabel(task)}';
