import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import 'add_projector_dialog.dart';

class MainToolbar extends ConsumerWidget {
  final bool isMonitoringView;
  final ValueChanged<bool> onViewChanged;

  const MainToolbar({
    super.key,
    required this.isMonitoringView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          FilledButton.icon(
            onPressed: () {
              final existingIps = ref.read(workspaceProvider).map((n) => n.ipAddress).toList();
              showDialog(
                context: context,
                builder: (context) => AddProjectorDialog(
                  existingIps: existingIps,
                  onAddProjectors: (projectors) {
                    ref.read(workspaceProvider.notifier).addProjectors(projectors);
                  },
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Projectors'),
          ),
          const Spacer(),
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
            onSelectionChanged: (set) {
              onViewChanged(set.first);
            },
          ),
        ],
      ),
    );
  }
}
