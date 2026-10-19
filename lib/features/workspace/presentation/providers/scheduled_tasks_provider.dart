import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/log_event.dart';
import '../../domain/schedule_due.dart';
import '../../domain/schedule_status.dart';
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
    } else if (task.targetGroupIds.isNotEmpty) {
      await wsNotifier.sendCommandToGroups(
        task.targetGroupIds.toSet(),
        task.command,
      );
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

  /// Removes the completed and not-run one-time tasks (the list's *Clear*).
  void clearFinished(DateTime now) {
    if (!state.any((t) => isTaskFinished(t, now))) return;
    state = state.where((t) => !isTaskFinished(t, now)).toList();
  }

  /// Called when group [groupId] is deleted: every task drops it, and one
  /// left with no group is switched off (it would fire on schedule and reach
  /// no projector) until the user picks a new target.
  void detachGroup(String groupId) => _dropGroups((id) => id == groupId);

  /// Drops every group not in [groupIds] from the tasks, after an undo or
  /// redo puts the group list back to a state where some are gone.
  void detachMissingGroups(Set<String> groupIds) =>
      _dropGroups((id) => !groupIds.contains(id));

  void _dropGroups(bool Function(String id) gone) {
    bool touches(ScheduledTask t) => t.targetGroupIds.any(gone);
    if (!state.any(touches)) return;
    state = [
      for (final t in state)
        if (touches(t))
          _withGroups(t, t.targetGroupIds.where((id) => !gone(id)).toList())
        else
          t,
    ];
  }

  static ScheduledTask _withGroups(ScheduledTask t, List<String> ids) =>
      t.copyWith(
        targetGroupIds: ids,
        enabled:
            t.enabled && (ids.isNotEmpty || t.target == ScheduleTarget.all),
      );

  void toggleEnabled(String id) {
    state = state.map((t) {
      if (t.id != id) return t;
      if (!t.enabled && !taskHasTarget(t)) return t;
      return t.copyWith(enabled: !t.enabled);
    }).toList();
  }
}
