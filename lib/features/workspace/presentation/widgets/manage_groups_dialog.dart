import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/projector_group.dart';
import '../providers/workspace_provider.dart';

const List<Color> _presetColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
];

/// Shows the New / Edit Group dialog. Returns the created/updated group, or null.
/// Can be called standalone (from context menu "New Group...") or from ManageGroupsDialog.
Future<ProjectorGroup?> showGroupEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  ProjectorGroup? existing,
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  var selectedColor = existing != null ? Color(existing.color) : _presetColors[0];
  String? nameError;

  return showDialog<ProjectorGroup>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = Theme.of(ctx);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar
                Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Text(
                    existing != null ? 'Edit Group' : 'New Group',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Group Name',
                          border: const OutlineInputBorder(),
                          errorText: nameError,
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          if (nameError != null) {
                            setDialogState(() => nameError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Color', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _presetColors.map((color) {
                          final isSelected = color.toARGB32() == selectedColor.toARGB32();
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = color),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                setDialogState(() => nameError = 'Group name is required');
                                return;
                              }

                              // Check for duplicate name or OSC address collision
                              final notifier = ref.read(workspaceProvider.notifier);
                              final existingGroups = notifier.groups;
                              final oscAddress = '/group/${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
                              final isDuplicate = existingGroups.any((g) =>
                                  g.id != existing?.id &&
                                  (g.name.toLowerCase() == name.toLowerCase() ||
                                   g.oscAddress == oscAddress));
                              if (isDuplicate) {
                                setDialogState(() => nameError = 'A group with this name already exists');
                                return;
                              }
                              ProjectorGroup result;
                              if (existing != null) {
                                result = existing.copyWith(
                                  name: name,
                                  color: selectedColor.toARGB32(),
                                  oscAddress: oscAddress,
                                );
                                notifier.updateGroup(result);
                              } else {
                                final id = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';
                                result = ProjectorGroup(
                                  id: id,
                                  name: name,
                                  color: selectedColor.toARGB32(),
                                  oscAddress: oscAddress,
                                );
                                notifier.addGroup(result);
                              }
                              Navigator.pop(ctx, result);
                            },
                            child: Text(existing != null ? 'Save' : 'Create'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ManageGroupsDialog extends ConsumerStatefulWidget {
  const ManageGroupsDialog({super.key});

  @override
  ConsumerState<ManageGroupsDialog> createState() => _ManageGroupsDialogState();
}

class _ManageGroupsDialogState extends ConsumerState<ManageGroupsDialog> {
  void _confirmDeleteGroup(ProjectorGroup group) {
    final nodes = ref.read(workspaceProvider);
    final memberCount = nodes.where((n) => n.groupId == group.id).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          memberCount > 0
              ? 'Are you sure you want to delete "${group.name}"?\n$memberCount projector(s) will be unassigned.'
              : 'Are you sure you want to delete "${group.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(workspaceProvider.notifier).deleteGroup(group.id);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(workspaceProvider.notifier).groups;
    final nodes = ref.watch(workspaceProvider);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Text('Manage Groups', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      await showGroupEditorDialog(context, ref);
                      setState(() {});
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Group'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No groups created yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final memberCount = nodes.where((n) => n.groupId == group.id).length;
                    return ListTile(
                      leading: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(group.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        [
                          '$memberCount projector${memberCount != 1 ? 's' : ''}',
                          if (group.oscAddress.isNotEmpty) group.oscAddress,
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () async {
                              await showGroupEditorDialog(context, ref, existing: group);
                              setState(() {});
                            },
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _confirmDeleteGroup(group),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
