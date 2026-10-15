import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/group_naming.dart';
import '../../../domain/group_palette.dart';
import '../../../domain/ip_sort.dart';
import '../../../domain/projector_group.dart';
import '../../providers/workspace_provider.dart';
import '../common/dialog_parts.dart';
import '../common/ip_chips.dart';
import '../dialog_title_bar.dart';
import 'group_actions.dart';
import 'group_color_palette.dart';
import 'group_name_field.dart';

/// The compact New Group dialog of the card context menu. Returns the
/// created group, or null; the caller assigns [projectorIds] to it.
Future<ProjectorGroup?> showNewGroupDialog(
  BuildContext context, {
  required List<String> projectorIds,
}) {
  return showDialog<ProjectorGroup>(
    context: context,
    builder: (_) => NewGroupDialog(projectorIds: projectorIds),
  );
}

class NewGroupDialog extends ConsumerStatefulWidget {
  const NewGroupDialog({super.key, required this.projectorIds});

  /// The projectors that join the group once it is created.
  final List<String> projectorIds;

  @override
  ConsumerState<NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends ConsumerState<NewGroupDialog> {
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
    Navigator.pop(context, createGroup(ref, _name.text, _color));
  }

  @override
  Widget build(BuildContext context) {
    final background = DialogSurfaces.of(context).body;
    final used = {
      for (final g in ref.watch(workspaceProvider.notifier).groups) g.color,
    };
    final ids = widget.projectorIds.toSet();
    final ips = [
      for (final n in ref.read(workspaceProvider))
        if (ids.contains(n.id)) n.ipAddress,
    ];
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(icon: Icons.layers, title: 'New Group'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GroupNameField(
                      controller: _name,
                      label: 'Name',
                      previewColor: Color(_color),
                      errorText: _error,
                      autofocus: true,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _create(),
                    ),
                    const SizedBox(height: 16),
                    GroupColorPalette(
                      selected: _color,
                      usedColors: used,
                      background: background,
                      onSelected: (c) => setState(() => _color = c),
                    ),
                    const SizedBox(height: 16),
                    _JoinsBox(ips: ips),
                  ],
                ),
              ),
            ),
            DialogFooter(
              actionLabel: 'Create group',
              actionIcon: Icons.add,
              onAction: _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 selected projectors will join this group", and the projectors by IP
/// under it: a comma list for a few, collapsed range chips for many. Always
/// two lines high.
class _JoinsBox extends StatelessWidget {
  const _JoinsBox({required this.ips});

  final List<String> ips;

  /// Up to this many read fine as a plain list on one line.
  static const int _listLimit = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = ips.length;
    final sorted = [...ips]
      ..sort((a, b) => ipSortKey(a).compareTo(ipSortKey(b)));
    final body = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface);
    return DialogCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const DialogIconTile(Icons.videocam_outlined, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    style: body,
                    children: [
                      TextSpan(
                        text:
                            '$count selected projector${count == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' will join this group'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 22,
                  child: count <= _listLimit
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            sorted.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.mono(
                              TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: IpChips(ips: sorted, maxChips: 2),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
