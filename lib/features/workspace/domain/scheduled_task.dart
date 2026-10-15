import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_task.freezed.dart';

enum ScheduleTarget { all, group }

enum ScheduleType { once, daily, weekly }

@Freezed(makeCollectionsUnmodifiable: false)
abstract class ScheduledTask with _$ScheduledTask {
  const factory ScheduledTask({
    required String id,
    required String name,
    required String command,
    required String commandLabel,
    required ScheduleTarget target,
    String? targetGroupId,
    required ScheduleType scheduleType,
    DateTime? oneTimeAt,
    String? timeOfDay,
    List<int>? weekdays,
    @Default(true) bool enabled,
    DateTime? lastRunAt,
  }) = _ScheduledTask;
}

/// False for a group task whose group was deleted: it would fire on
/// schedule and reach no projector, so it can't be switched on until it
/// gets a new target.
bool taskHasTarget(ScheduledTask task) =>
    task.target == ScheduleTarget.all || task.targetGroupId != null;
