import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projector_group.dart';
import '../../../domain/schedule_labels.dart';
import '../../../domain/schedule_next_run.dart';
import '../../../domain/schedule_status.dart';
import '../../../domain/scheduled_commands.dart';
import '../../../domain/scheduled_task.dart';
import '../../../domain/task_draft.dart';
import '../../providers/custom_commands_provider.dart';
import '../../providers/scheduled_tasks_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/confirm_dialog.dart';
import '../common/dialog_parts.dart';
import '../dialog_title_bar.dart';
import 'editor_placeholder.dart';
import 'task_editor.dart';
import 'task_list.dart';

/// Scheduled Tasks: the task list on the left and the editor of the
/// selected task on the right, in one dialog. Nothing is selected on open.
/// Unsaved edits are confirmed before another task, a new one or closing
/// takes their place.
class ScheduledTasksDialog extends ConsumerStatefulWidget {
  const ScheduledTasksDialog({super.key});

  @override
  ConsumerState<ScheduledTasksDialog> createState() =>
      _ScheduledTasksDialogState();
}

class _ScheduledTasksDialogState extends ConsumerState<ScheduledTasksDialog> {
  String? _selectedId;
  bool _creating = false;

  /// The editor's fields, and what they were when loaded or last saved.
  TaskDraft? _draft;
  TaskDraft? _baseline;
  bool _showErrors = false;
  int _generation = 0;
  bool _completedOpen = false;

  /// Statuses follow the clock (a one-time task becomes not run, *Next:
  /// today* becomes *tomorrow*), so the dialog redraws each minute.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  bool get _dirty => _draft != null && _draft != _baseline;

  List<ProjectorGroup> get _groups =>
      ref.read(workspaceProvider.notifier).groups;

  List<ScheduledCommand> get _catalog =>
      scheduledCommandCatalog(ref.read(customCommandsProvider));

  ScheduledTask? _taskById(String? id) => id == null
      ? null
      : ref.read(scheduledTasksProvider).where((t) => t.id == id).firstOrNull;

  /// True when there is nothing unsaved, or the user lets it go.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final task = _taskById(_selectedId);
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog<bool>(
        icon: Icons.edit_off_outlined,
        title: _creating || task == null
            ? 'Discard the new task?'
            : 'Discard changes to “${taskShortLabel(task)}”?',
        subtitle: 'What you changed in the editor is not saved.',
        destructive: true,
        actions: const [
          ConfirmAction(label: 'Keep editing', value: false),
          ConfirmAction(
            label: 'Discard',
            value: true,
            kind: ConfirmActionKind.destructive,
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  void _load(ScheduledTask task) {
    final draft = TaskDraft.fromTask(task, _catalog, _groups);
    setState(() {
      _selectedId = task.id;
      _creating = false;
      _draft = draft;
      _baseline = draft;
      _showErrors = false;
      _generation++;
    });
  }

  void _clearSelection() => setState(() {
    _selectedId = null;
    _creating = false;
    _draft = null;
    _baseline = null;
    _showErrors = false;
  });

  Future<void> _select(String id) async {
    if (id == _selectedId && !_creating) return;
    if (!await _confirmLeave() || !mounted) return;
    final task = _taskById(id);
    if (task != null) _load(task);
  }

  Future<void> _startNew() async {
    if (!await _confirmLeave() || !mounted) return;
    _openNew(const TaskDraft.blank());
  }

  void _openNew(TaskDraft draft) => setState(() {
    _selectedId = null;
    _creating = true;
    _draft = draft;
    _baseline = draft;
    _showErrors = false;
    _generation++;
  });

  Future<void> _close() async {
    if (!await _confirmLeave() || !mounted) return;
    // A direct pop: PopScope holds back only the Esc and barrier ones.
    Navigator.of(context).pop();
  }

  /// True when the draft can be saved; otherwise its errors show from now
  /// on, following each edit.
  bool _validate() {
    if (_draft!.errors(DateTime.now()).isEmpty) return true;
    setState(() => _showErrors = true);
    return false;
  }

  void _create() {
    if (!_validate()) return;
    final task = _draft!.toTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      groups: _groups,
    );
    ref.read(scheduledTasksProvider.notifier).add(task);
    _load(task);
  }

  void _save() {
    final previous = _taskById(_selectedId)!;
    if (!_validate()) return;
    final task = _draft!.toTask(
      id: previous.id,
      groups: _groups,
      previous: previous,
    );
    ref.read(scheduledTasksProvider.notifier).update(task);
    // The fields keep their focus and text; only the baseline moves.
    final saved = TaskDraft.fromTask(task, _catalog, _groups);
    setState(() {
      _draft = saved;
      _baseline = saved;
      _showErrors = false;
    });
  }

  void _scheduleAgain() {
    final previous = _taskById(_selectedId)!;
    final task = _draft!
        .copyWith(enabled: true)
        .toTask(id: previous.id, groups: _groups);
    ref.read(scheduledTasksProvider.notifier).update(task);
    _load(task);
  }

  void _revert() => setState(() {
    _draft = _baseline;
    _showErrors = false;
    _generation++;
  });

  Future<void> _delete() async {
    final task = _taskById(_selectedId)!;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete “${taskShortLabel(task)}”?',
      subtitle: 'The task is removed from this project and won’t run again.',
      confirmLabel: 'Delete task',
    );
    if (!confirmed || !mounted) return;
    ref.read(scheduledTasksProvider.notifier).remove(task.id);
    _clearSelection();
  }

  Future<void> _clearCompleted() async {
    final now = DateTime.now();
    final count = ref
        .read(scheduledTasksProvider)
        .where((t) => isTaskFinished(t, now))
        .length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Clear completed tasks?',
      subtitle:
          '$count one-time task${count == 1 ? ' is' : 's are'} removed from '
          'this project.',
      confirmLabel: 'Clear',
    );
    if (!confirmed || !mounted) return;
    final selected = _taskById(_selectedId);
    ref.read(scheduledTasksProvider.notifier).clearFinished(now);
    if (selected != null && isTaskFinished(selected, now)) _clearSelection();
  }

  /// The card's switch applies at once. On the open task it moves the
  /// editor's switch and baseline with it, so it doesn't read as an edit.
  void _toggleEnabled(String id, bool enabled) {
    ref.read(scheduledTasksProvider.notifier).toggleEnabled(id);
    final draft = _draft;
    if (id != _selectedId || draft == null) return;
    setState(() {
      _draft = draft.copyWith(enabled: enabled);
      _baseline = _baseline!.copyWith(enabled: enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(scheduledTasksProvider);
    ref.watch(customCommandsProvider);
    final membership = ref.watch(
      workspaceProvider.select(
        (nodes) => _Membership.of(nodes.map((n) => n.groupId)),
      ),
    );
    final groups = _groups;
    final now = DateTime.now();
    final selected = _taskById(_selectedId);
    // The selected task can go away under the editor (the scheduler, a
    // Clear); the editor goes with it.
    final draft = _creating || selected != null ? _draft : null;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 660),
        child: SizedBox.expand(
          child: PopScope(
            canPop: !_dirty,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _close();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DialogTitleBar(
                  icon: Icons.schedule,
                  title: 'Scheduled Tasks',
                  onClose: _close,
                ),
                Expanded(
                  child: ColoredBox(
                    color: DialogSurfaces.of(context).body,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          // A small window takes the room from the list, so
                          // the editor's rows still fit.
                          final listWidth = box.maxWidth < 860 ? 280.0 : 330.0;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: listWidth,
                                child: TaskList(
                                  tasks: tasks,
                                  groups: groups,
                                  now: now,
                                  selectedId: _creating ? null : _selectedId,
                                  creating: _creating
                                      ? draft!.preview(groups)
                                      : null,
                                  completedOpen: _completedOpen,
                                  onSelect: _select,
                                  onToggleEnabled: _toggleEnabled,
                                  onNewTask: _creating ? null : _startNew,
                                  onCompletedOpenChanged: (v) =>
                                      setState(() => _completedOpen = v),
                                  onClearCompleted: _clearCompleted,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _editor(
                                  draft,
                                  selected,
                                  tasks,
                                  groups,
                                  membership,
                                  now,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editor(
    TaskDraft? draft,
    ScheduledTask? selected,
    List<ScheduledTask> tasks,
    List<ProjectorGroup> groups,
    _Membership membership,
    DateTime now,
  ) {
    if (draft == null) {
      if (tasks.isEmpty) return EditorPlaceholder.empty(onNewTask: _startNew);
      final statuses = tasks.map((t) => taskStatusOf(t, now)).toList();
      final next = nextScheduledRun(
        tasks.where((t) => taskStatusOf(t, now) == TaskStatus.active),
        now,
      );
      return EditorPlaceholder.summary(
        active: statuses.where((s) => s == TaskStatus.active).length,
        paused: statuses.where((s) => s == TaskStatus.paused).length,
        nextRun: next == null ? null : formatDayDateTime(next),
      );
    }
    final mode = _creating
        ? TaskEditorMode.creating
        : isTaskFinished(selected!, now)
        ? TaskEditorMode.finished
        : TaskEditorMode.editing;
    return TaskEditor(
      mode: mode,
      draft: draft,
      dirty: _dirty,
      task: selected,
      now: now,
      catalog: _catalog,
      groups: groups,
      projectorCount: membership.total,
      membersByGroup: membership.byGroup,
      showErrors: _showErrors,
      generation: _generation,
      onChanged: (update) => setState(() => _draft = update(_draft!)),
      onPrimary: switch (mode) {
        TaskEditorMode.creating => _create,
        TaskEditorMode.editing => _save,
        TaskEditorMode.finished => _scheduleAgain,
      },
      onSecondary: switch (mode) {
        TaskEditorMode.creating => _clearSelection,
        TaskEditorMode.editing => _revert,
        TaskEditorMode.finished => () => _openNew(
          draft.copyWith(enabled: true),
        ),
      },
      onDelete: mode == TaskEditorMode.creating ? null : _delete,
    );
  }
}

/// Projectors per group and in all, compared by value so a polling tick
/// that changes only telemetry doesn't rebuild the dialog.
@immutable
class _Membership {
  const _Membership(this.total, this.byGroup);

  factory _Membership.of(Iterable<String?> groupIds) {
    var total = 0;
    final byGroup = <String, int>{};
    for (final id in groupIds) {
      total++;
      if (id != null) byGroup[id] = (byGroup[id] ?? 0) + 1;
    }
    return _Membership(total, byGroup);
  }

  final int total;
  final Map<String, int> byGroup;

  @override
  bool operator ==(Object other) =>
      other is _Membership &&
      other.total == total &&
      mapEquals(other.byGroup, byGroup);

  @override
  int get hashCode => Object.hash(total, byGroup.length);
}
