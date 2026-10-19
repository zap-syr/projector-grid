import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/scheduled_commands.dart';
import '../common/dialog_parts.dart';

IconData commandCategoryIcon(CommandCategory? category) => switch (category) {
  null => Icons.grid_view,
  CommandCategory.power => Icons.power_settings_new,
  CommandCategory.shutter => Icons.visibility_outlined,
  CommandCategory.input => Icons.input,
  CommandCategory.custom => Icons.code,
};

/// The closed command picker: the command's category tile and name, and a
/// chevron. Opens the panel under it.
class CommandField extends StatelessWidget {
  const CommandField({
    super.key,
    required this.command,
    required this.useCommandString,
    required this.open,
    required this.error,
    required this.onTap,
  });

  final ScheduledCommand? command;
  final bool useCommandString;
  final bool open;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final radius = BorderRadius.circular(10);
    final picked = command;
    final String label;
    final IconData icon;
    if (useCommandString) {
      label = 'Command string';
      icon = Icons.code;
    } else if (picked != null) {
      label = picked.label;
      icon = commandCategoryIcon(picked.category);
    } else {
      label = 'Select command';
      icon = Icons.bolt;
    }
    final empty = !useCommandString && picked == null;
    return Semantics(
      button: true,
      expanded: open,
      label: 'Command',
      child: Material(
        color: DialogSurfaces.of(context).field,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('command-field'),
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: dialogFieldHeight,
            padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
            // Painted over the field, so the 2 px open border doesn't move
            // the content.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: error
                    ? cs.error
                    : open
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.6),
                width: open || error ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                DialogIconTile(icon, size: 30, muted: empty),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(
                      fontWeight: empty ? null : FontWeight.w500,
                      color: empty ? t.tertiary : null,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: t.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
