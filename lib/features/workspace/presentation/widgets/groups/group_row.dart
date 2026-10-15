import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_group.dart';
import '../common/dialog_parts.dart';
import 'group_actions.dart';
import 'group_inline_editor.dart';

/// One group in Manage Groups: swatch, name, member count, its OSC address
/// as a read-only chip, an edit button that opens the editor in place and
/// a red delete button.
class GroupRow extends ConsumerWidget {
  const GroupRow({
    super.key,
    required this.group,
    required this.memberCount,
    required this.expanded,
    required this.onToggle,
    this.first = false,
    this.highlighted = false,
  });

  final ProjectorGroup group;
  final int memberCount;
  final bool expanded;
  final VoidCallback onToggle;

  /// No divider above the first row.
  final bool first;

  /// Brief tint for a group that was just created.
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final surfaces = DialogSurfaces.of(context);
    final rowColor = highlighted
        ? cs.primaryContainer.withValues(alpha: 0.55)
        : expanded
        ? surfaces.editor
        : surfaces.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          color: rowColor,
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(group.color),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // One line: wrapping beside the OSC chip and unwrapping
                    // when the editor hides it moved the row's buttons.
                    Text(
                      '$memberCount projector${memberCount == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!expanded && group.oscAddress.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(
                  // Fits the longest address a 24-character name gives; the
                  // cap only bites in a narrow window, where it ellipsizes.
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group.oscAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.mono(
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              IconButton(
                onPressed: onToggle,
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                tooltip: expanded ? 'Collapse' : 'Edit ${group.name}',
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.edit_outlined,
                  color: cs.onSurfaceVariant,
                ),
              ),
              // In the row, not the editor, and shown either way, so the
              // edit button never moves when the row opens.
              IconButton(
                key: ValueKey('delete-group-${group.id}'),
                onPressed: () => confirmDeleteGroup(context, ref, group),
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete ${group.name}',
                icon: Icon(Icons.delete_outline, color: cs.error),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? GroupInlineEditor(group: group, onClose: onToggle)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
