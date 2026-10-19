import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/schedule_status.dart';
import '../../../domain/scheduled_task.dart';
import '../common/scroll_fade.dart';
import 'task_card.dart';

/// The left column: summary and *New task*, the scrolling cards (the New
/// card first, then active, paused and the collapsible *Completed*
/// section), and the footnote that tasks need the app open.
class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.tasks,
    required this.groups,
    required this.now,
    required this.selectedId,
    required this.creating,
    required this.completedOpen,
    required this.onSelect,
    required this.onToggleEnabled,
    required this.onNewTask,
    required this.onCompletedOpenChanged,
    required this.onClearCompleted,
  });

  final List<ScheduledTask> tasks;
  final List<ProjectorGroup> groups;
  final DateTime now;
  final String? selectedId;

  /// The task being created, shown as the dashed New card.
  final ScheduledTask? creating;
  final bool completedOpen;
  final ValueChanged<String> onSelect;
  final void Function(String id, bool enabled) onToggleEnabled;

  /// Null disables *New task* (the editor's filled button is live).
  final VoidCallback? onNewTask;
  final ValueChanged<bool> onCompletedOpenChanged;
  final VoidCallback onClearCompleted;

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskList old) {
    super.didUpdateWidget(old);
    // The New card goes in at the top, which may be scrolled away.
    if (old.creating == null && widget.creating != null && _scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final (:open, :finished) = orderTaskList(widget.tasks, widget.now);
    final active = open
        .where((x) => taskStatusOf(x, widget.now) == TaskStatus.active)
        .length;
    final summary = widget.tasks.isEmpty
        ? ''
        : '${open.length} task${open.length == 1 ? '' : 's'}, $active active';

    Widget card(ScheduledTask task) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TaskCard(
        key: ValueKey('task-card-${task.id}'),
        task: task,
        groups: widget.groups,
        now: widget.now,
        selected: task.id == widget.selectedId,
        onTap: () => widget.onSelect(task.id),
        onToggle: (v) => widget.onToggleEnabled(task.id, v),
      ),
    );

    final creating = widget.creating;
    final empty = widget.tasks.isEmpty && creating == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.description,
                ),
              ),
              const SizedBox(width: 8),
              // Filled, as Manage Groups' New group; the dialog disables it
              // while the editor's own filled button can be pressed.
              FilledButton.icon(
                key: const ValueKey('new-task'),
                onPressed: widget.onNewTask,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New task'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: empty
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'No tasks yet',
                    textAlign: TextAlign.center,
                    style: t.description,
                  ),
                )
              : Scrollbar(
                  controller: _scroll,
                  child: ScrollFade(
                    extent: 36,
                    child: ListView(
                      controller: _scroll,
                      // Room for the scrollbar, and for the selected card's
                      // border.
                      padding: const EdgeInsets.fromLTRB(0, 0, 12, 4),
                      children: [
                        if (creating != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskCard.creating(
                              key: const ValueKey('task-card-new'),
                              task: creating,
                              groups: widget.groups,
                              now: widget.now,
                            ),
                          ),
                        for (final task in open) card(task),
                        if (finished.isNotEmpty) ...[
                          _CompletedHeader(
                            count: finished.length,
                            open: widget.completedOpen,
                            onOpenChanged: widget.onCompletedOpenChanged,
                            onClear: widget.onClearCompleted,
                          ),
                          if (widget.completedOpen) ...[
                            const SizedBox(height: 6),
                            for (final task in finished) card(task),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: t.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Runs only while the app is open',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.description,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `> Completed 2`, and *Clear* while it is open.
class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({
    required this.count,
    required this.open,
    required this.onOpenChanged,
    required this.onClear,
  });

  final int count;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpenChanged(!open),
              child: Semantics(
                expanded: open,
                button: true,
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: t.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text('Completed', style: t.label),
                    const SizedBox(width: 8),
                    Text('$count', style: t.caption),
                  ],
                ),
              ),
            ),
          ),
          // Kept in place while collapsed, so opening the section doesn't
          // move the header.
          Visibility(
            visible: open,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: TextButton(onPressed: onClear, child: const Text('Clear')),
          ),
        ],
      ),
    );
  }
}
