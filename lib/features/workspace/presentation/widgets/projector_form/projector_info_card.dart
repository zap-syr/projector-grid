import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_node.dart';
import '../../providers/workspace_provider.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';

/// The projector Edit Projector is editing: model, its current `IP : port`,
/// group and connection badge. Unlike the other per-projector dialogs it
/// keeps a card in the body, because the address under edit is the point.
///
/// Group and status stay live (the projector can drop offline while the
/// dialog is open); the address stays what it was when the dialog opened.
class ProjectorInfoCard extends ConsumerWidget {
  const ProjectorInfoCard({super.key, required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppText.of(context);
    final notifier = ref.read(workspaceProvider.notifier);
    final live = ref.watch(
      workspaceProvider.select((nodes) {
        final n = nodes.where((n) => n.id == node.id).firstOrNull;
        if (n == null) return null;
        final group = notifier.groups
            .where((g) => g.id == n.groupId)
            .firstOrNull;
        return (
          status: n.connectionStatus,
          groupName: group?.name,
          groupColor: group?.color,
        );
      }),
    );
    final status = live?.status ?? node.connectionStatus;
    final modelKnown = node.name.isNotEmpty && node.name != node.ipAddress;
    return DialogCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const DialogIconTile(Icons.videocam_outlined, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelKnown ? node.name : 'Model not read yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: modelKnown
                      ? t.cardTitle
                      : t.cardTitle.copyWith(color: t.secondary),
                ),
                Text('${node.ipAddress} : ${node.port}', style: t.monoSmall),
              ],
            ),
          ),
          if (live?.groupName != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: GroupPill(
                name: live!.groupName!,
                color: Color(live.groupColor!),
              ),
            ),
          ],
          const SizedBox(width: 8),
          ConnectionStatusBadge(status: status),
        ],
      ),
    );
  }
}
