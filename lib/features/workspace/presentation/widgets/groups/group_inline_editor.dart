import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/group_naming.dart';
import '../../../domain/projector_group.dart';
import '../../providers/workspace_provider.dart';
import '../common/dialog_parts.dart';
import 'group_color_palette.dart';
import 'group_name_field.dart';

/// The editor a group row opens into: name, palette, *Delete group* on the
/// left and *Cancel* / *Save* on the right. [onClose] collapses the row.
class GroupInlineEditor extends ConsumerStatefulWidget {
  const GroupInlineEditor({
    super.key,
    required this.group,
    required this.onClose,
  });

  final ProjectorGroup group;
  final VoidCallback onClose;

  @override
  ConsumerState<GroupInlineEditor> createState() => _GroupInlineEditorState();
}

class _GroupInlineEditorState extends ConsumerState<GroupInlineEditor> {
  late final _name = TextEditingController(text: widget.group.name);
  late int _color = widget.group.color;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(workspaceProvider.notifier);
    final error = groupNameError(
      _name.text,
      notifier.groups,
      exceptId: widget.group.id,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final name = _name.text.trim();
    notifier.updateGroup(
      widget.group.copyWith(
        name: name,
        color: _color,
        oscAddress: groupOscAddress(name),
      ),
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final background = DialogSurfaces.of(context).editor;
    final used = {
      for (final g in ref.watch(workspaceProvider.notifier).groups)
        if (g.id != widget.group.id) g.color,
    };
    return Container(
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GroupNameField(
            controller: _name,
            label: 'Name',
            errorText: _error,
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          GroupColorPalette(
            selected: _color,
            usedColors: used,
            background: background,
            onSelected: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
