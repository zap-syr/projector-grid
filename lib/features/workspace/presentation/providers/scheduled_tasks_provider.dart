import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/command_source.dart';
import '../../domain/schedule_due.dart';
import '../../domain/schedule_status.dart';
import '../../domain/scheduled_task.dart';
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
    // The command's row names the task, so no line of its own follows.
    final source = CommandSource.schedule(task.name);

    if (task.target == ScheduleTarget.all) {
      await wsNotifier.sendCommandToAll(task.command, source: source);
    } else if (task.targetGroupIds.isNotEmpty) {
      await wsNotifier.sendCommandToGroups(
        task.targetGroupIds.toSet(),
        task.command,
        source: source,
      );
    }

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
    _detached.clear();
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

  /// After an undo or redo puts the group list back to [groupIds]: tasks
  /// drop the groups that are gone, and get back the ones they lost to an
  /// earlier detach once those return.
  void syncGroups(Set<String> groupIds) {
    _dropGroups((id) => !groupIds.contains(id));
    _reattach(groupIds);
  }

  // Undo and redo don't snapshot tasks, so what a detach took is kept here
  // per group id: the task and whether it was on before.
  final _detached = <String, List<({String taskId, bool enabled})>>{};

  void _dropGroups(bool Function(String id) gone) {
    bool touches(ScheduledTask t) => t.targetGroupIds.any(gone);
    if (!state.any(touches)) return;
    for (final t in state) {
      for (final id in t.targetGroupIds.where(gone)) {
        (_detached[id] ??= []).add((taskId: t.id, enabled: t.enabled));
      }
    }
    state = [
      for (final t in state)
        if (touches(t))
          _withGroups(t, t.targetGroupIds.where((id) => !gone(id)).toList())
        else
          t,
    ];
  }

  void _reattach(Set<String> groupIds) {
    final back = [
      for (final id in groupIds)
        if (_detached.remove(id) case final records?)
          for (final r in records)
            (groupId: id, taskId: r.taskId, on: r.enabled),
    ];
    if (back.isEmpty) return;
    state = [
      for (final t in state)
        if (back.where((b) => b.taskId == t.id).toList() case final mine
            when mine.isNotEmpty)
          t.copyWith(
            targetGroupIds: [
              ...t.targetGroupIds,
              for (final b in mine)
                if (!t.targetGroupIds.contains(b.groupId)) b.groupId,
            ],
            // Only the switch-off the detach did is undone: a task the user
            // has since re-aimed or switched keeps its own state.
            enabled:
                t.enabled ||
                (t.targetGroupIds.isEmpty && mine.any((b) => b.on)),
          )
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
