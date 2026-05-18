import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/log_event.dart';
import '../../domain/scheduled_task.dart';
import 'event_log_provider.dart';
import 'workspace_provider.dart';

part 'scheduled_tasks_provider.g.dart';

@Riverpod(keepAlive: true)
class ScheduledTasksNotifier extends _$ScheduledTasksNotifier {
  Timer? _schedulerTimer;

  @override
  List<ScheduledTask> build() {
    _startScheduler();
    ref.onDispose(() => _schedulerTimer?.cancel());
    return [];
  }

  void _startScheduler() {
    _schedulerTimer?.cancel();
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    _schedulerTimer = Timer(nextMinute.difference(now), () {
      _scheduleNextTick();
      _checkAndExecuteTasks();
    });
  }

  Future<void> _checkAndExecuteTasks() async {
    final now = DateTime.now();
    for (final task in List<ScheduledTask>.from(state)) {
      if (!task.enabled) continue;
      if (!_isDue(task, now)) continue;
      await _execute(task, now);
    }
  }

  bool _isDue(ScheduledTask task, DateTime now) {
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
        if (!task.weekdays!.contains(now.weekday)) { return false; }
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

  Future<void> _execute(ScheduledTask task, DateTime now) async {
    final wsNotifier = ref.read(workspaceProvider.notifier);
    final logNotifier = ref.read(eventLogProvider.notifier);

    if (task.target == ScheduleTarget.all) {
      await wsNotifier.sendCommandToAll(task.command);
    } else if (task.targetGroupId != null) {
      await wsNotifier.sendCommandToGroup(task.targetGroupId!, task.command);
    }

    logNotifier.log(LogEvent(
      severity: LogSeverity.info,
      type: LogEventType.command,
      message:
          '[Scheduler] "${task.name}"',
    ));

    state = state.map((t) {
      if (t.id != task.id) return t;
      return t.copyWith(
        lastRunAt: now,
        enabled: task.scheduleType != ScheduleType.once,
      );
    }).toList();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  void loadTasks(List<ScheduledTask> tasks) {
    state = tasks;
  }

  void add(ScheduledTask task) {
    state = [...state, task];
  }

  void update(ScheduledTask task) {
    state = state.map((t) => t.id == task.id ? task : t).toList();
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void toggleEnabled(String id) {
    state = state
        .map((t) => t.id == id ? t.copyWith(enabled: !t.enabled) : t)
        .toList();
  }
}
