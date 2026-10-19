import 'scheduled_task.dart';

/// A task from the project file. Files written before a task could target
/// several groups carry a single `targetGroupId`; it becomes a one-item
/// list.
ScheduledTask scheduledTaskFromJson(Map<String, dynamic> j) {
  final ids = j['targetGroupIds'] as List<dynamic>?;
  final legacyId = j['targetGroupId'] as String?;
  return ScheduledTask(
    id: j['id'] as String,
    name: j['name'] as String,
    command: j['command'] as String,
    commandLabel: j['commandLabel'] as String,
    target: ScheduleTarget.values.firstWhere(
      (e) => e.name == j['target'],
      orElse: () => ScheduleTarget.all,
    ),
    targetGroupIds: ids != null
        ? [for (final id in ids) id as String]
        : [?legacyId],
    scheduleType: ScheduleType.values.firstWhere(
      (e) => e.name == j['scheduleType'],
      orElse: () => ScheduleType.daily,
    ),
    oneTimeAt: j['oneTimeAt'] != null
        ? DateTime.tryParse(j['oneTimeAt'] as String)
        : null,
    timeOfDay: j['timeOfDay'] as String?,
    weekdays: (j['weekdays'] as List<dynamic>?)?.map((e) => e as int).toList(),
    enabled: j['enabled'] as bool? ?? true,
    lastRunAt: j['lastRunAt'] != null
        ? DateTime.tryParse(j['lastRunAt'] as String)
        : null,
  );
}

/// The task as the project file stores it. The first group is also written
/// as the old single `targetGroupId`, so an older app opening the file
/// still keeps one target group.
Map<String, dynamic> scheduledTaskToJson(ScheduledTask t) => {
  'id': t.id,
  'name': t.name,
  'command': t.command,
  'commandLabel': t.commandLabel,
  'target': t.target.name,
  if (t.targetGroupIds.isNotEmpty) ...{
    'targetGroupId': t.targetGroupIds.first,
    'targetGroupIds': t.targetGroupIds,
  },
  'scheduleType': t.scheduleType.name,
  if (t.oneTimeAt != null) 'oneTimeAt': t.oneTimeAt!.toIso8601String(),
  if (t.timeOfDay != null) 'timeOfDay': t.timeOfDay,
  if (t.weekdays != null) 'weekdays': t.weekdays,
  'enabled': t.enabled,
  if (t.lastRunAt != null) 'lastRunAt': t.lastRunAt!.toIso8601String(),
};
