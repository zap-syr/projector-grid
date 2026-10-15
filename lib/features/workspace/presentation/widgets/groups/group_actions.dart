import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/group_naming.dart';
import '../../../domain/projector_group.dart';
import '../../providers/scheduled_tasks_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/confirm_dialog.dart';

/// Adds a group named [name] (already validated) and returns it.
ProjectorGroup createGroup(WidgetRef ref, String name, int color) {
  final trimmed = name.trim();
  final group = ProjectorGroup(
    id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}',
    name: trimmed,
    color: color,
    oscAddress: groupOscAddress(trimmed),
  );
  ref.read(workspaceProvider.notifier).addGroup(group);
  return group;
}

/// Asks before deleting [group], listing what changes, and deletes it on
/// confirm. True when the group was deleted.
Future<bool> confirmDeleteGroup(
  BuildContext context,
  WidgetRef ref,
  ProjectorGroup group,
) async {
  final memberCount = ref
      .read(workspaceProvider)
      .where((n) => n.groupId == group.id)
      .length;
  final tasks = ref
      .read(scheduledTasksProvider)
      .where((t) => t.targetGroupId == group.id)
      .toList();

  final confirmed = await confirmDestructive(
    context,
    title: 'Delete “${group.name}”?',
    subtitle: 'The group is removed from this project.',
    confirmLabel: 'Delete group',
    changes: [
      if (memberCount > 0)
        ConfirmChange(
          icon: Icons.videocam_outlined,
          lead: '$memberCount projector${memberCount == 1 ? '' : 's'}',
          rest: 'stay in the project, ungrouped',
        ),
      for (final t in tasks)
        ConfirmChange(icon: Icons.schedule, lead: t.name, rest: 'is paused'),
      if (group.oscAddress.isNotEmpty)
        ConfirmChange(
          icon: Icons.sensors,
          lead: group.oscAddress,
          rest: 'no longer answers',
          monoLead: true,
        ),
    ],
  );
  if (!confirmed) return false;
  ref.read(workspaceProvider.notifier).deleteGroup(group.id);
  return true;
}
