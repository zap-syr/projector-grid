import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import 'add_projector_dialog.dart';

class MainToolbar extends ConsumerWidget {
  const MainToolbar({super.key});

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
              showDialog(
                context: context,
                builder: (context) => AddProjectorDialog(
                  onAddProjectors: (projectors) {
                    ref.read(workspaceProvider.notifier).addProjectors(projectors);
                  },
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Projectors'),
          ),
          // Additional tools can go here
        ],
      ),
    );
  }
}
