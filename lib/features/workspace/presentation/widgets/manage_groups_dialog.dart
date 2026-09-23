import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_group.dart';
import '../providers/scheduled_tasks_provider.dart';
import '../providers/workspace_provider.dart';
import 'dialog_title_bar.dart';

/// 8 hues x 3 tones, flattened tone-major (row 0 = lightest tone of every
/// hue, row 1 = mid, row 2 = deepest) so a `crossAxisCount: 8` grid renders
/// one hue per column, light-to-dark top to bottom.
const List<Color> _curatedPalette = [
  Color(0xFFF87171),
  Color(0xFFFB923C),
  Color(0xFFFBBF24),
  Color(0xFF4ADE80),
  Color(0xFF2DD4BF),
  Color(0xFF60A5FA),
  Color(0xFFA78BFA),
  Color(0xFFF472B6),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFF22C55E),
  Color(0xFF14B8A6),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFB91C1C),
  Color(0xFFC2410C),
  Color(0xFFB45309),
  Color(0xFF15803D),
  Color(0xFF0F766E),
  Color(0xFF1D4ED8),
  Color(0xFF6D28D9),
  Color(0xFFBE185D),
];

/// The readable text/icon color to paint on top of [background] — mirrors
/// how the group's card chip picks its own text color (see ProjectorCard).
Color contrastOn(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.light
      ? const Color(0xFF15171B)
      : Colors.white;
}

/// Shows the New / Edit Group dialog. Returns the created/updated group, or null.
/// Can be called standalone (from context menu "New Group...") or from ManageGroupsDialog.
Future<ProjectorGroup?> showGroupEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  ProjectorGroup? existing,
}) {
  return showDialog<ProjectorGroup>(
    context: context,
    builder: (_) => _GroupEditorDialog(ref: ref, existing: existing),
  );
}

// A real State (rather than the StatefulBuilder this used to be built with)
// so its TextEditingController has a dispose() to actually get called —
// StatefulBuilder has no lifecycle hook to free one, leaking a controller
// and its listeners on every New/Edit Group open.
class _GroupEditorDialog extends StatefulWidget {
  const _GroupEditorDialog({required this.ref, this.existing});

  final WidgetRef ref;
  final ProjectorGroup? existing;

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

/// Soft cap on group names — long names get ellipsized on the ~120px-wide
/// card chip anyway, and this keeps the generated OSC address reasonable.
const int _maxGroupNameLength = 24;

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Color _selectedColor = widget.existing != null
      ? Color(widget.existing!.color)
      : _curatedPalette[0];
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogTitleBar(
              title: existing != null ? 'Edit Group' : 'New Group',
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: _maxGroupNameLength,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: const OutlineInputBorder(),
                      errorText: _nameError,
                      labelStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      floatingLabelStyle: WidgetStateTextStyle.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.error)) {
                          return TextStyle(color: cs.error);
                        }
                        return TextStyle(color: cs.primary);
                      }),
                    ),
                    autofocus: true,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Color', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _curatedPalette.map((color) {
                      final isSelected =
                          color.toARGB32() == _selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: cs.onSurface,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: theme.dialogTheme.backgroundColor!,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 15,
                                  color: contrastOn(color),
                                )
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            setState(
                              () => _nameError = 'Group name is required',
                            );
                            return;
                          }

                          // Check for duplicate name or OSC address collision
                          final notifier = widget.ref.read(
                            workspaceProvider.notifier,
                          );
                          final existingGroups = notifier.groups;
                          final oscAddress =
                              '/group/${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
                          final isDuplicate = existingGroups.any(
                            (g) =>
                                g.id != existing?.id &&
                                (g.name.toLowerCase() == name.toLowerCase() ||
                                    g.oscAddress == oscAddress),
                          );
                          if (isDuplicate) {
                            setState(
                              () => _nameError =
                                  'A group with this name already exists',
                            );
                            return;
                          }
                          ProjectorGroup result;
                          if (existing != null) {
                            result = existing.copyWith(
                              name: name,
                              color: _selectedColor.toARGB32(),
                              oscAddress: oscAddress,
                            );
                            notifier.updateGroup(result);
                          } else {
                            final id =
                                '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';
                            result = ProjectorGroup(
                              id: id,
                              name: name,
                              color: _selectedColor.toARGB32(),
                              oscAddress: oscAddress,
                            );
                            notifier.addGroup(result);
                          }
                          Navigator.pop(context, result);
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
  }
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
    // Deleting a group doesn't touch scheduled tasks that target it — such
    // a task would keep "running" on schedule but silently match zero
    // projectors afterward, so warn about that here rather than let it
    // happen invisibly.
    final taskCount = ref
        .read(scheduledTasksProvider)
        .where((t) => t.targetGroupId == group.id)
        .length;

    final warnings = <String>[
      if (memberCount > 0) '$memberCount projector(s) will be unassigned.',
      if (taskCount > 0)
        '$taskCount scheduled task(s) target this group and will stop doing anything once it\'s deleted.',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          warnings.isEmpty
              ? 'Are you sure you want to delete "${group.name}"?'
              : 'Are you sure you want to delete "${group.name}"?\n${warnings.join('\n')}',
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
        height: 480,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(title: 'Manage Groups'),
            // Content
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'No groups created yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final memberCount = nodes
                            .where((n) => n.groupId == group.id)
                            .length;
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
                                  await showGroupEditorDialog(
                                    context,
                                    ref,
                                    existing: group,
                                  );
                                  setState(() {});
                                },
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                onPressed: () => _confirmDeleteGroup(group),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
          ],
        ),
      ),
    );
  }
}
