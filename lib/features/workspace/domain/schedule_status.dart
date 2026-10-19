import 'schedule_next_run.dart';
import 'scheduled_task.dart';

/// How late a one-time task may still fire. The scheduler ticks once a
/// minute, so a tick can land just after the set time; later than this the
/// run is never made (owner, 2026-10-19): a "power on at 18:00" fired the
/// next morning when the app opens does more harm than good.
const oneTimeGrace = Duration(minutes: 2);

enum TaskStatus {
  /// Enabled and still due to run.
  active,

  /// Switched off, or left without a target group.
  paused,

  /// A one-time task that ran.
  completed,

  /// A one-time task whose time passed without it running (the app was
  /// closed, or the task was paused). It is never run late.
  notRun,
}

/// Where [task] stands at [now]. Completed and not run are derived from the
/// task's own dates, so nothing has to be stored for them.
TaskStatus taskStatusOf(ScheduledTask task, DateTime now) {
  if (task.scheduleType == ScheduleType.once) {
    if (task.lastRunAt != null) return TaskStatus.completed;
    final at = task.oneTimeAt;
    if (at != null && now.isAfter(at.add(oneTimeGrace))) {
      return TaskStatus.notRun;
    }
  }
  return task.enabled && taskHasTarget(task)
      ? TaskStatus.active
      : TaskStatus.paused;
}

/// Completed and not-run tasks: the list's *Completed* section, the ones
/// *Clear* removes.
bool isTaskFinished(ScheduledTask task, DateTime now) {
  final status = taskStatusOf(task, now);
  return status == TaskStatus.completed || status == TaskStatus.notRun;
}

/// The task list in display order: active tasks by their next run, paused
/// ones after them (by their would-be next run), and separately the
/// finished ones, most recent first.
({List<ScheduledTask> open, List<ScheduledTask> finished}) orderTaskList(
  Iterable<ScheduledTask> tasks,
  DateTime now,
) {
  final active = <ScheduledTask>[];
  final paused = <ScheduledTask>[];
  final finished = <ScheduledTask>[];
  for (final t in tasks) {
    switch (taskStatusOf(t, now)) {
      case TaskStatus.active:
        active.add(t);
      case TaskStatus.paused:
        paused.add(t);
      case TaskStatus.completed:
      case TaskStatus.notRun:
        finished.add(t);
    }
  }
  int byNextRun(ScheduledTask a, ScheduledTask b) {
    final x = nextRunOf(a, now);
    final y = nextRunOf(b, now);
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return x.compareTo(y);
  }

  DateTime when(ScheduledTask t) => t.lastRunAt ?? t.oneTimeAt!;
  active.sort(byNextRun);
  paused.sort(byNextRun);
  finished.sort((a, b) => when(b).compareTo(when(a)));
  return (open: [...active, ...paused], finished: finished);
}
