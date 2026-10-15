import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/log_event.dart';
import '../../domain/schedule_due.dart';
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
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _schedulerTimer = Timer(nextMinute.difference(now), () {
      _scheduleNextTick();
      _checkAndExecuteTasks();
    });
  }

  Future<void> _checkAndExecuteTasks() async {
    final now = DateTime.now();
    for (final task in List<ScheduledTask>.from(state)) {
      if (!task.enabled) continue;
      if (!isTaskDue(task, now)) continue;
      await _execute(task, now);
    }
  }

  Future<void> _execute(ScheduledTask task, DateTime now) async {
    final wsNotifier = ref.read(workspaceProvider.notifier);
    final logNotifier = ref.read(eventLogProvider.notifier);

    if (task.target == ScheduleTarget.all) {
      await wsNotifier.sendCommandToAll(task.command);
    } else if (task.targetGroupId != null) {
      await wsNotifier.sendCommandToGroup(task.targetGroupId!, task.command);
    }

    logNotifier.log(
      LogEvent(
        severity: LogSeverity.info,
        type: LogEventType.command,
        message: '[Scheduler] "${task.name}"',
      ),
    );

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

  /// Called when group [groupId] is deleted. A task aimed at it would keep
  /// firing on schedule and reach no projector, so it loses the target and
  /// is switched off until the user picks a new one.
  void detachGroup(String groupId) => detachMissingGroups({
    for (final t in state)
      if (t.targetGroupId != null && t.targetGroupId != groupId)
        t.targetGroupId!,
  });

  /// Detaches every task whose group isn't in [groupIds] — after an undo or
  /// redo puts the group list back to a state where a task's group is gone.
  void detachMissingGroups(Set<String> groupIds) {
    bool missing(ScheduledTask t) =>
        t.targetGroupId != null && !groupIds.contains(t.targetGroupId);
    if (!state.any(missing)) return;
    state = [
      for (final t in state)
        missing(t) ? t.copyWith(targetGroupId: null, enabled: false) : t,
    ];
  }

  void toggleEnabled(String id) {
    state = state.map((t) {
      if (t.id != id) return t;
      if (!t.enabled && !taskHasTarget(t)) return t;
      return t.copyWith(enabled: !t.enabled);
    }).toList();
  }
}
