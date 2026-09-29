import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alignment_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/workspace_provider.dart';
import 'add_projector_dialog.dart';
import 'alignment_banner.dart';
import 'manage_groups_dialog.dart';
import 'scheduled_tasks_dialog.dart';

class MainToolbar extends ConsumerWidget {
  const MainToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMonitoringView = ref.watch(
      appSettingsProvider.select((s) => s.isMonitoringView),
    );
    final alignmentActive = ref.watch(
      alignmentProvider.select((s) => s.active || s.busy),
    );
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left actions — scrollable so narrow windows never overflow
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      final existingIps = ref
                          .read(workspaceProvider)
                          .map((n) => n.ipAddress)
                          .toList();
                      showDialog(
                        context: context,
                        builder: (context) => AddProjectorDialog(
                          existingIps: existingIps,
                          onAddProjectors: (projectors) {
                            ref
                                .read(workspaceProvider.notifier)
                                .addProjectors(projectors);
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Projectors'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ManageGroupsDialog(),
                      );
                    },
                    icon: const Icon(Icons.workspaces_outlined, size: 18),
                    label: const Text('Manage Groups'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ScheduledTasksDialog(),
                      );
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Scheduled Tasks'),
                  ),
                  const SizedBox(width: 8),
                  alignmentActive
                      ? FilledButton.tonalIcon(
                          onPressed: () => toggleAlignmentMode(ref),
                          icon: const Icon(Icons.center_focus_strong, size: 18),
                          label: const Text('Alignment'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => toggleAlignmentMode(ref),
                          icon: const Icon(Icons.center_focus_strong, size: 18),
                          label: const Text('Alignment'),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.grid_view),
                label: Text('Controls'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.table_chart),
                label: Text('Monitoring'),
              ),
            ],
            selected: {isMonitoringView},
            showSelectedIcon: false,
            onSelectionChanged: (set) {
              settingsNotifier.setMonitoringView(set.first);
            },
          ),
        ],
      ),
    );
  }
}
