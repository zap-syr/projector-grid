import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/schedule_labels.dart';
import '../../../domain/schedule_next_run.dart';
import '../../../domain/schedule_status.dart';
import '../../../domain/scheduled_commands.dart';
import '../../../domain/scheduled_task.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import 'target_chip.dart';

const _cardPadding = EdgeInsets.fromLTRB(14, 10, 10, 10);
const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// One task in the list: time and Active switch, command and target, then
/// the schedule and when it runs next. Every variant (active, paused,
/// completed, not run, the dashed New card) has the same rows at the same
/// heights, so cards never change size with their state.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.groups,
    required this.now,
    required this.selected,
    required this.onTap,
    this.onToggle,
  }) : isNew = false;

  /// The dashed card of a task being created, drawn from the editor's
  /// fields so far.
  const TaskCard.creating({
    super.key,
    required this.task,
    required this.groups,
    required this.now,
  }) : isNew = true,
       selected = true,
       onTap = null,
       onToggle = null;

  final ScheduledTask task;
  final List<ProjectorGroup> groups;
  final DateTime now;
  final bool selected;
  final bool isNew;
  final VoidCallback? onTap;

  /// The card's Active switch, applied at once. Null hides it.
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    // A task being created has no state yet, whatever its date says.
    final status = isNew ? TaskStatus.active : taskStatusOf(task, now);
    final finished =
        status == TaskStatus.completed || status == TaskStatus.notRun;
    final paused = status == TaskStatus.paused;
    final quiet = finished ? t.secondary : null;
    final command = scheduledCommandLabel(task.command, task.commandLabel);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  taskTimeLabel(task),
                  style: _timeStyle(t).copyWith(color: quiet),
                ),
              ),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'New',
                    style: t.description.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                )
              else if (!finished)
                _SmallSwitch(
                  value: task.enabled,
                  onChanged: task.enabled || taskHasTarget(task)
                      ? onToggle
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 22,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  command.isEmpty ? 'No command yet' : command,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: command.isEmpty ? t.tertiary : quiet,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TargetChip(task: task, groups: groups),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(height: 20, child: _bottomRow(context, status)),
      ],
    );

    if (isNew) {
      final radius = BorderRadius.circular(14);
      return DashedBorder(
        color: cs.primary,
        radius: 14,
        strokeWidth: 2,
        dash: 6,
        gap: 4,
        child: Container(
          padding: _cardPadding.add(const EdgeInsets.all(1)),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              cs.primary.withValues(alpha: 0.06),
              DialogSurfaces.of(context).card,
            ),
            borderRadius: radius,
          ),
          child: content,
        ),
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      child: DialogCard(
        highlighted: selected,
        muted: finished,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: _cardPadding,
              child: Opacity(opacity: paused ? 0.55 : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomRow(BuildContext context, TaskStatus status) {
    final t = AppText.of(context);
    final at = task.oneTimeAt;
    switch (status) {
      case TaskStatus.completed:
        final success = AppStatusColors.of(context).success;
        return Row(
          children: [
            Icon(Icons.check, size: 14, color: success),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Ran ${formatDayDateTime(task.lastRunAt!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.description.copyWith(
                  fontWeight: FontWeight.w600,
                  color: success,
                ),
              ),
            ),
          ],
        );
      case TaskStatus.notRun:
        return Text(
          'Not run, ${formatDayDateTime(at!)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.description,
        );
      case TaskStatus.active:
      case TaskStatus.paused:
        final next = nextRunOf(task, now);
        final String? trailing;
        if (isNew) {
          trailing = null;
        } else if (status == TaskStatus.paused) {
          trailing = 'Paused';
        } else {
          trailing = next == null ? null : nextRunShort(next, now);
        }
        final nextText = trailing == null
            ? null
            : Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: t.description,
              );
        if (task.scheduleType == ScheduleType.weekly) {
          return Row(
            children: [
              _DayDots(days: task.weekdays ?? const []),
              const SizedBox(width: 8),
              Expanded(child: nextText ?? const SizedBox.shrink()),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                scheduleLine(task),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.description,
              ),
            ),
            if (nextText != null) ...[
              const SizedBox(width: 8),
              Flexible(child: nextText),
            ],
          ],
        );
    }
  }
}

/// The card's time: the hero size, which the mockup gives it, at the
/// weight of a card title and with tabular figures so times line up.
TextStyle _timeStyle(AppText t) => t.hero.copyWith(
  fontWeight: FontWeight.w600,
  fontFeatures: const [FontFeature.tabularFigures()],
  height: 1.1,
);

/// The Active switch at list-card size.
class _SmallSwitch extends StatelessWidget {
  const _SmallSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: FittedBox(
        child: Switch(
          value: value,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Seven small day circles, the task's days filled.
class _DayDots extends StatelessWidget {
  const _DayDots({required this.days});

  final List<int> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final soft = DialogSurfaces.of(context).soft;
    return Semantics(
      label: weekdaysLabel(days),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var d = 1; d <= 7; d++) ...[
              if (d > 1) const SizedBox(width: 3),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: days.contains(d) ? cs.primary : soft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _dayLetters[d - 1],
                  style: t.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: days.contains(d) ? cs.onPrimary : t.tertiary,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
