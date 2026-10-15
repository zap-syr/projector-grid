import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/group_naming.dart';
import '../../../domain/group_palette.dart';
import '../../../domain/projector_group.dart';
import '../../providers/workspace_provider.dart';
import 'group_actions.dart';
import 'group_card.dart';
import 'group_color_palette.dart';
import 'group_name_field.dart';

/// The New group form at the top of Manage Groups: colour preview, name,
/// palette (first unused colour preselected), *Cancel* / *Create group*.
class NewGroupCard extends ConsumerStatefulWidget {
  const NewGroupCard({
    super.key,
    required this.onCancel,
    required this.onCreated,
  });

  final VoidCallback onCancel;
  final ValueChanged<ProjectorGroup> onCreated;

  @override
  ConsumerState<NewGroupCard> createState() => _NewGroupCardState();
}

class _NewGroupCardState extends ConsumerState<NewGroupCard> {
  final _name = TextEditingController();
  late int _color = firstUnusedGroupColor(
    ref.read(workspaceProvider.notifier).groups.map((g) => g.color),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final error = groupNameError(
      _name.text,
      ref.read(workspaceProvider.notifier).groups,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onCreated(createGroup(ref, _name.text, _color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final background = GroupSurfaces.editor(cs);
    final used = {
      for (final g in ref.watch(workspaceProvider.notifier).groups) g.color,
    };
    return GroupCard(
      highlighted: true,
      child: Container(
        color: background,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GroupNameField(
              controller: _name,
              label: 'New group name',
              previewColor: Color(_color),
              errorText: _error,
              autofocus: true,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            GroupColorPalette(
              selected: _color,
              usedColors: used,
              background: background,
              onSelected: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign projectors via the grid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create group'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
