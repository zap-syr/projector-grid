import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/schedule_next_run.dart';
import 'scheduled_tasks_provider.dart';
import 'workspace_provider.dart';

part 'toolbar_counts_provider.g.dart';

/// Number of groups, for the toolbar's Groups badge.
///
/// Groups live in `WorkspaceNotifier`'s private list, not in its state, so
/// this can't be a `.select()` on `workspaceProvider`. Every group edit
/// reassigns the node list in the same turn (and a project load sets the
/// nodes right before the groups), so watching the list recomputes at the
/// right times; the int result then dedupes the polling ticks away, and the
/// toolbar doesn't rebuild for them.
@riverpod
int groupCount(Ref ref) {
  ref.watch(workspaceProvider);
  return ref.watch(workspaceProvider.notifier).groups.length;
}

/// Active (enabled) scheduled tasks and when the next one runs, already
/// worded for the tooltip (`at 22:30`, `tomorrow at 07:00`).
///
/// Recomputes itself when that run time passes and at midnight, so the
/// wording never goes stale while the task list stays the same; the record
/// result dedupes those recomputes when nothing visible changed.
@riverpod
({int active, String? nextRun}) scheduledTasksSummary(Ref ref) {
  final tasks = ref.watch(scheduledTasksProvider);
  final now = DateTime.now();
  final next = nextScheduledRun(tasks, now);
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final refreshAt = next != null && next.isBefore(midnight) ? next : midnight;
  final timer = Timer(
    refreshAt.difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return (
    active: tasks.where((t) => t.enabled).length,
    nextRun: next == null ? null : describeRunTime(next, now),
  );
}
