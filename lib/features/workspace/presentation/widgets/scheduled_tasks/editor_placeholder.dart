import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';

/// The editor's place while no task is selected: a summary of the tasks,
/// or, in a project without any, what tasks are for and *New task*.
class EditorPlaceholder extends StatelessWidget {
  const EditorPlaceholder.summary({
    super.key,
    required this.active,
    required this.paused,
    required this.nextRun,
  }) : onNewTask = null;

  const EditorPlaceholder.empty({super.key, required this.onNewTask})
    : active = 0,
      paused = 0,
      nextRun = null;

  final int active;
  final int paused;

  /// `Tue 13 Oct, 08:00`; null while no task is active.
  final String? nextRun;

  /// Set for the empty project.
  final VoidCallback? onNewTask;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final onNewTask = this.onNewTask;
    final nextRun = this.nextRun;
    return DialogCard(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 40, color: t.secondary),
              const SizedBox(height: 12),
              if (onNewTask != null) ...[
                Text('No scheduled tasks', style: t.cardTitle),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    'Send a command to all projectors or to groups at a set '
                    'time: once, daily or weekly.',
                    textAlign: TextAlign.center,
                    style: t.description,
                  ),
                ),
                const SizedBox(height: 16),
                // The list's New task is tonal, so this is the one filled
                // button.
                FilledButton.icon(
                  key: const ValueKey('empty-new-task'),
                  onPressed: onNewTask,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New task'),
                ),
              ] else ...[
                Text('$active active, $paused paused', style: t.cardTitle),
                if (nextRun != null) ...[
                  const SizedBox(height: 4),
                  Text('Next run $nextRun', style: t.description),
                ],
                const SizedBox(height: 4),
                Text('Select a task to edit it.', style: t.description),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
