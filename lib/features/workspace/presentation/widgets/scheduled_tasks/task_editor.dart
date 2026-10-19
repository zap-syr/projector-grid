import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/schedule_labels.dart';
import '../../../domain/schedule_status.dart';
import '../../../domain/scheduled_commands.dart';
import '../../../domain/scheduled_task.dart';
import '../../../domain/task_draft.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';
import 'command_section.dart';
import 'target_section.dart';
import 'task_parts.dart';
import 'when_section.dart';

enum TaskEditorMode {
  /// A new task, not in the list yet: *Discard* / *Create task*.
  creating,

  /// An active or paused task: *Delete*, *Revert* / *Save changes*.
  editing,

  /// A completed or not-run one-time task: *Delete*, *Duplicate* /
  /// *Schedule again*.
  finished,
}

/// The right-hand card: a header with the task's name, its run pill and
/// (for a saved task) the Active switch; the numbered Command, Target and
/// When sections, scrolling when they don't fit; and the footer.
class TaskEditor extends StatelessWidget {
  const TaskEditor({
    super.key,
    required this.mode,
    required this.draft,
    required this.dirty,
    required this.task,
    required this.now,
    required this.catalog,
    required this.groups,
    required this.projectorCount,
    required this.membersByGroup,
    required this.showErrors,
    required this.generation,
    required this.onChanged,
    required this.onPrimary,
    required this.onSecondary,
    this.onDelete,
  });

  final TaskEditorMode mode;
  final TaskDraft draft;
  final bool dirty;

  /// The saved task, null while creating.
  final ScheduledTask? task;
  final DateTime now;
  final List<ScheduledCommand> catalog;
  final List<ProjectorGroup> groups;
  final int projectorCount;
  final Map<String, int> membersByGroup;

  /// Errors show only after a save was tried.
  final bool showErrors;

  /// Bumped to rebuild the fields from [draft] (another task, Revert).
  final int generation;
  final DraftEdit onChanged;

  /// Create task, Save changes or Schedule again.
  final VoidCallback onPrimary;

  /// Discard, Revert or Duplicate.
  final VoidCallback onSecondary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final errors = draft.errors(now);
    final shown = showErrors ? errors.toSet() : const <DraftError>{};
    final finished = mode == TaskEditorMode.finished;
    final status = task == null ? null : taskStatusOf(task!, now);

    return DialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: mode == TaskEditorMode.creating
                ? 'New task'
                : _title(draft, groups),
            pill: _pill(context, status),
            activeSwitch: mode == TaskEditorMode.editing
                ? Switch(
                    key: const ValueKey('editor-active'),
                    value: draft.enabled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => onChanged((d) => d.copyWith(enabled: v)),
                  )
                : null,
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.6),
          ),
          Expanded(
            child: DialogScrollBody(
              key: ValueKey('editor-body-$generation'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (finished) ...[
                    _Note(
                      status == TaskStatus.completed
                          ? 'This one-time task has run. Pick a new date to '
                                'schedule it again.'
                          : 'This one-time task did not run at its time. '
                                'Pick a new date to schedule it again.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  CommandSection(
                    draft: draft,
                    catalog: catalog,
                    errors: shown,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 20),
                  TargetSection(
                    draft: draft,
                    groups: groups,
                    projectorCount: projectorCount,
                    membersByGroup: membersByGroup,
                    errors: shown,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 20),
                  WhenSection(
                    draft: draft,
                    errors: shown,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
          _footer(context, shown.isEmpty ? null : errors.first, errors),
        ],
      ),
    );
  }

  static String _title(TaskDraft draft, List<ProjectorGroup> groups) {
    final command = draft.commandLabel;
    final target = targetLabel(draft.target, draft.groupIds, groups);
    return command == null || command.isEmpty ? target : '$command, $target';
  }

  Widget? _pill(BuildContext context, TaskStatus? status) {
    final t = AppText.of(context);
    final success = AppStatusColors.of(context).success;
    switch (mode) {
      case TaskEditorMode.finished:
        final saved = task!;
        return status == TaskStatus.completed
            ? StatusPill(
                label: 'Ran ${formatDayDateTime(saved.lastRunAt!)}',
                color: success,
                icon: Icons.check,
              )
            : StatusPill(
                label: 'Not run, ${formatDayDateTime(saved.oneTimeAt!)}',
                color: t.secondary,
                icon: Icons.schedule,
              );
      case TaskEditorMode.editing when !draft.enabled:
        return StatusPill(
          label: 'Paused',
          color: t.secondary,
          icon: Icons.pause,
        );
      case TaskEditorMode.editing:
      case TaskEditorMode.creating:
        final next = draft.nextRun(now);
        if (next == null) return null;
        final lead = mode == TaskEditorMode.creating ? 'Runs' : 'Next run';
        return StatusPill(
          label: '$lead ${formatDayDateTime(next)}',
          color: success,
          icon: Icons.schedule,
        );
    }
  }

  Widget _footer(
    BuildContext context,
    DraftError? error,
    List<DraftError> errors,
  ) {
    final (secondary, primary, primaryEnabled) = switch (mode) {
      TaskEditorMode.creating => ('Discard', 'Create task', true),
      TaskEditorMode.editing => ('Revert', 'Save changes', dirty),
      TaskEditorMode.finished => (
        'Duplicate',
        'Schedule again',
        errors.isEmpty,
      ),
    };
    final secondaryEnabled = mode != TaskEditorMode.editing || dirty;
    return _EditorFooter(
      error: error?.message,
      onDelete: onDelete,
      secondary: TextButton(
        key: const ValueKey('editor-secondary'),
        onPressed: secondaryEnabled ? onSecondary : null,
        child: _WidestLabel(secondary, widest: _widestSecondary),
      ),
      primary: FilledButton(
        key: const ValueKey('editor-primary'),
        onPressed: primaryEnabled ? onPrimary : null,
        child: _WidestLabel(primary, widest: _widestPrimary),
      ),
    );
  }
}

const _widestSecondary = 'Duplicate';
const _widestPrimary = 'Schedule again';

/// The editor card's footer: *Delete* (or the validation message of a new
/// task) on the left, the two buttons on the right. Tighter than
/// [DialogFooter], as it sits inside a card. In a narrow editor *Delete*
/// steps down to its icon; the buttons keep their labels.
class _EditorFooter extends StatelessWidget {
  const _EditorFooter({
    required this.error,
    required this.onDelete,
    required this.secondary,
    required this.primary,
  });

  final String? error;
  final VoidCallback? onDelete;
  final Widget secondary;
  final Widget primary;

  static const _padding = EdgeInsets.fromLTRB(12, 10, 16, 10);
  static const _iconDelete = 40.0;

  /// Width a button's [label] needs: its text in the button font plus
  /// [extra] for padding and icon. Only used to pick the layout.
  static double _buttonWidth(BuildContext context, String label, double extra) {
    final style = DefaultTextStyle.of(context).style
        .merge(Theme.of(context).textTheme.labelLarge);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + extra;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final error = this.error;
    final onDelete = this.onDelete;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).card,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      padding: _padding,
      child: LayoutBuilder(
        builder: (context, box) {
          // Text button: 12 + 12 padding; filled: 24 + 24; Delete adds its
          // icon and gap. The widest labels, since the buttons keep them.
          final buttons =
              _buttonWidth(context, _widestSecondary, 24) +
              8 +
              _buttonWidth(context, _widestPrimary, 48);
          final fullDelete = _buttonWidth(context, 'Delete', 54);
          final roomy = box.maxWidth - buttons - 12 >= fullDelete;
          final Widget? delete = onDelete == null
              ? null
              : roomy
              ? TextButton.icon(
                  key: const ValueKey('editor-delete'),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                )
              : IconButton(
                  key: const ValueKey('editor-delete'),
                  tooltip: 'Delete',
                  color: cs.error,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _iconDelete,
                    height: _iconDelete,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                );
          return Row(
            children: [
              ?delete,
              // What Delete leaves: the message, then the buttons.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, rest) => Row(
                    children: [
                      Expanded(
                        child: error == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.only(
                                  left: delete == null ? 8 : 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: cs.error,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        error,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.of(context).description
                                            .copyWith(color: cs.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      // Scales down only where the labels can't fit at all
                      // (a much wider font than the app's), instead of
                      // overflowing.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (rest.maxWidth - 8).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              secondary,
                              const SizedBox(width: 8),
                              primary,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// [label] in the width of [widest], so switching between tasks of
/// different kinds never moves the footer buttons.
class _WidestLabel extends StatelessWidget {
  const _WidestLabel(this.label, {required this.widest});

  final String label;
  final String widest;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text(widest),
        ),
        Text(label),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.pill, this.activeSwitch});

  final String title;
  final Widget? pill;
  final Widget? activeSwitch;

  /// Below this the pill goes under the title, in the same 64 px.
  static const _stackBelow = 520.0;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final pill = this.pill;
    final activeSwitch = this.activeSwitch;
    final titleText = Text(
      title,
      key: const ValueKey('editor-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.cardTitle,
    );
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, box) {
            final stacked = box.maxWidth < _stackBelow;
            return Row(
              children: [
                Expanded(
                  child: stacked
                      // The pill's line is kept while there is no pill, so
                      // the title doesn't move when one comes.
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleText,
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 22,
                              child: pill == null
                                  ? null
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: pill,
                                    ),
                            ),
                          ],
                        )
                      : titleText,
                ),
                // Flush right, not Flexible: next to the Expanded title it
                // would be stranded mid-row.
                if (!stacked && pill != null) ...[
                  const SizedBox(width: 12),
                  pill,
                ],
                if (activeSwitch != null) ...[
                  const SizedBox(width: 16),
                  Text('Active', style: t.description),
                  const SizedBox(width: 8),
                  activeSwitch,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: t.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: t.description.copyWith(color: t.primary)),
          ),
        ],
      ),
    );
  }
}
