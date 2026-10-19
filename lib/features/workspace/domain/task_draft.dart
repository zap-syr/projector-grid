import 'package:flutter/foundation.dart';

import 'projector_group.dart';
import 'schedule_labels.dart';
import 'schedule_next_run.dart';
import 'scheduled_commands.dart';
import 'scheduled_task.dart';

/// What can be wrong with a draft, in the editor's order: the first one is
/// the footer's message.
enum DraftError {
  command('Select a command'),
  commandName('Name is required'),
  commandString('Command string is required'),
  groups('Select at least one group'),
  date('Pick a date'),
  datePast('Pick a time in the future'),
  days('Select at least one day');

  const DraftError(this.message);

  final String message;
}

/// The Scheduled Tasks editor's fields, before they become a task.
@immutable
class TaskDraft {
  const TaskDraft({
    this.command,
    this.useCommandString = false,
    this.stringName = '',
    this.stringCommand = '',
    this.target = ScheduleTarget.all,
    this.groupIds = const {},
    this.scheduleType = ScheduleType.daily,
    this.date,
    this.hour = 8,
    this.minute = 0,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.enabled = true,
  });

  /// A new task: no command yet, all projectors, daily at 08:00.
  const TaskDraft.blank() : this();

  /// The editor's fields for [task]. Groups deleted since are left out; a
  /// command that isn't in [catalog] is a typed command string.
  factory TaskDraft.fromTask(
    ScheduledTask task,
    List<ScheduledCommand> catalog,
    List<ProjectorGroup> groups,
  ) {
    final picked = scheduledCommandFor(
      catalog,
      task.command,
      task.commandLabel,
    );
    final at = task.oneTimeAt;
    var (hour, minute) = (8, 0);
    final time = task.timeOfDay;
    if (task.scheduleType == ScheduleType.once && at != null) {
      (hour, minute) = (at.hour, at.minute);
    } else if (time != null) {
      final parts = time.split(':');
      (hour, minute) = (int.parse(parts[0]), int.parse(parts[1]));
    }
    return TaskDraft(
      command: picked,
      useCommandString: picked == null,
      stringName: picked == null ? task.commandLabel : '',
      stringCommand: picked == null ? task.command : '',
      target: task.target,
      groupIds: {
        for (final g in targetGroupsOf(task.targetGroupIds, groups)) g.id,
      },
      scheduleType: task.scheduleType,
      date: at == null ? null : DateTime(at.year, at.month, at.day),
      hour: hour,
      minute: minute,
      weekdays: {
        ...(task.weekdays ?? const [1, 2, 3, 4, 5]),
      },
      enabled: task.enabled,
    );
  }

  final ScheduledCommand? command;

  /// The command was typed (Name + Command string) instead of picked.
  final bool useCommandString;
  final String stringName;
  final String stringCommand;
  final ScheduleTarget target;
  final Set<String> groupIds;
  final ScheduleType scheduleType;

  /// The day of a one-time task (time of day zero).
  final DateTime? date;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final bool enabled;

  String? get commandLabel =>
      useCommandString ? stringName.trim() : command?.label;

  /// When a one-time draft would run, or null without a date.
  DateTime? get oneTimeAt {
    final d = date;
    return d == null ? null : DateTime(d.year, d.month, d.day, hour, minute);
  }

  /// When the draft's schedule would fire next after [now], whatever the
  /// rest of the draft says (the editor's header shows it while the command
  /// is still missing).
  DateTime? nextRun(DateTime now) {
    if (scheduleType == ScheduleType.once) {
      final at = oneTimeAt;
      return at != null && at.isAfter(now) ? at : null;
    }
    return nextRunOf(
      ScheduledTask(
        id: '',
        name: '',
        command: '',
        commandLabel: '',
        target: target,
        scheduleType: scheduleType,
        timeOfDay: formatHm(hour, minute),
        weekdays: weekdays.toList(),
      ),
      now,
    );
  }

  /// Every problem that keeps the draft from being saved at [now].
  List<DraftError> errors(DateTime now) {
    final at = oneTimeAt;
    return [
      if (!useCommandString && command == null) DraftError.command,
      if (useCommandString && stringName.trim().isEmpty) DraftError.commandName,
      if (useCommandString && stringCommand.trim().isEmpty)
        DraftError.commandString,
      if (target == ScheduleTarget.group && groupIds.isEmpty) DraftError.groups,
      if (scheduleType == ScheduleType.once && at == null) DraftError.date,
      if (scheduleType == ScheduleType.once && at != null && !at.isAfter(now))
        DraftError.datePast,
      if (scheduleType == ScheduleType.weekly && weekdays.isEmpty)
        DraftError.days,
    ];
  }

  /// The task this draft describes, as [id]. Groups go in the project's
  /// order, so the first one (written for older apps) is stable. A
  /// recurring task keeps [previous]'s last run so it doesn't fire twice in
  /// the minute it was saved; a one-time task is scheduled afresh.
  ScheduledTask toTask({
    required String id,
    required List<ProjectorGroup> groups,
    ScheduledTask? previous,
  }) {
    final once = scheduleType == ScheduleType.once;
    final task = ScheduledTask(
      id: id,
      name: '',
      command: useCommandString ? stringCommand.trim() : command!.command,
      commandLabel: commandLabel!,
      target: target,
      targetGroupIds: target == ScheduleTarget.group
          ? [for (final g in targetGroupsOf(groupIds, groups)) g.id]
          : const [],
      scheduleType: scheduleType,
      oneTimeAt: once ? oneTimeAt : null,
      timeOfDay: once ? null : formatHm(hour, minute),
      weekdays: scheduleType == ScheduleType.weekly
          ? (weekdays.toList()..sort())
          : null,
      enabled: enabled,
      lastRunAt: once ? null : previous?.lastRunAt,
    );
    return task.copyWith(name: taskShortLabel(task));
  }

  /// The draft as far as it goes, for the list's New card: a missing
  /// command or date stays empty instead of failing.
  ScheduledTask preview(List<ProjectorGroup> groups) {
    final once = scheduleType == ScheduleType.once;
    return ScheduledTask(
      id: '',
      name: '',
      command: useCommandString ? stringCommand.trim() : command?.command ?? '',
      commandLabel: commandLabel ?? '',
      target: target,
      targetGroupIds: target == ScheduleTarget.group
          ? [for (final g in targetGroupsOf(groupIds, groups)) g.id]
          : const [],
      scheduleType: scheduleType,
      oneTimeAt: once ? oneTimeAt : null,
      timeOfDay: once && date != null ? null : formatHm(hour, minute),
      weekdays: scheduleType == ScheduleType.weekly
          ? (weekdays.toList()..sort())
          : null,
    );
  }

  TaskDraft copyWith({
    ScheduledCommand? command,
    bool? useCommandString,
    String? stringName,
    String? stringCommand,
    ScheduleTarget? target,
    Set<String>? groupIds,
    ScheduleType? scheduleType,
    DateTime? date,
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? enabled,

    /// A date field that no longer holds a whole date.
    bool clearDate = false,
  }) => TaskDraft(
    command: command ?? this.command,
    useCommandString: useCommandString ?? this.useCommandString,
    stringName: stringName ?? this.stringName,
    stringCommand: stringCommand ?? this.stringCommand,
    target: target ?? this.target,
    groupIds: groupIds ?? this.groupIds,
    scheduleType: scheduleType ?? this.scheduleType,
    date: clearDate ? null : date ?? this.date,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdays: weekdays ?? this.weekdays,
    enabled: enabled ?? this.enabled,
  );

  /// Equal when they'd save the same task: fields the current choices hide
  /// (the typed string while a command is picked, the date of a daily task)
  /// don't count, so flipping an option and back leaves nothing unsaved.
  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      other.useCommandString == useCommandString &&
      (useCommandString
          ? other.stringName == stringName &&
                other.stringCommand == stringCommand
          : other.command == command) &&
      other.target == target &&
      (target == ScheduleTarget.all || setEquals(other.groupIds, groupIds)) &&
      other.scheduleType == scheduleType &&
      (scheduleType != ScheduleType.once || other.date == date) &&
      other.hour == hour &&
      other.minute == minute &&
      (scheduleType != ScheduleType.weekly ||
          setEquals(other.weekdays, weekdays)) &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(useCommandString, target, scheduleType, hour);
}
