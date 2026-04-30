import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/projector_node.dart';
import '../providers/workspace_provider.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(workspaceProvider);
    final total = nodes.length;
    final online = nodes
        .where((n) =>
          n.connectionStatus == ConnectionStatus.connected ||
          n.connectionStatus == ConnectionStatus.unprotected)
        .length;
    final offline = nodes
        .where((n) => n.connectionStatus == ConnectionStatus.offline)
        .length;
    final warnings = nodes
        .where((n) => n.errors != 'NO ERRORS' && n.errors != '-')
        .length;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _StatusItem(
            label: 'Projectors',
            count: total,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 16),
          _StatusItem(label: 'Online', count: online, color: Colors.green),
          const SizedBox(width: 16),
          _StatusItem(label: 'Offline', count: offline, color: Colors.grey),
          const SizedBox(width: 16),
          _StatusItem(label: 'Warning', count: warnings, color: Colors.orange),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $count', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
