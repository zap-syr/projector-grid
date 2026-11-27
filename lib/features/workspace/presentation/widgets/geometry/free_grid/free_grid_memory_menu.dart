import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../domain/free_grid_view.dart';
import '../../common/confirm_dialog.dart';
import 'free_grid_parts.dart';

/// What the memory menu offers, and what each entry says.
class FreeGridMemoryMenu extends StatelessWidget {
  const FreeGridMemoryMenu({
    super.key,
    required this.slotLabel,
    required this.enabled,
    required this.backupTakenAt,
    required this.onRestoreBackup,
    required this.onDiscardChanges,
    required this.onReset,
  });

  /// `PC-1`.
  final String slotLabel;

  /// False while a read or a write runs: the button is disabled.
  final bool enabled;

  /// When the memory's backup was taken (UTC); null: there is none.
  final DateTime? backupTakenAt;
  final VoidCallback onRestoreBackup;

  /// Null while there is nothing to discard.
  final VoidCallback? onDiscardChanges;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final taken = backupTakenAt;
    return MenuAnchor(
      alignmentOffset: const Offset(-272, 4),
      menuChildren: [
        _Item(
          key: const ValueKey('free-grid-menu-restore'),
          icon: Icons.history,
          title: 'Restore backup',
          description: taken == null
              ? 'No backup on this computer yet'
              : 'Backup of ${freeGridTimeLabel(taken)}, saved on this computer',
          onPressed: taken == null ? null : onRestoreBackup,
        ),
        _Item(
          key: const ValueKey('free-grid-menu-discard'),
          icon: Icons.undo,
          title: 'Discard changes',
          description: 'Go back to $slotLabel as last stored',
          onPressed: onDiscardChanges,
        ),
        const Divider(height: 9),
        _Item(
          key: const ValueKey('free-grid-menu-reset'),
          icon: Icons.restart_alt,
          title: 'Reset $slotLabel to neutral',
          description: 'Stores a flat table, no correction',
          onPressed: onReset,
          destructive: true,
        ),
      ],
      builder: (context, controller, _) => FreeGridIconButton(
        key: const ValueKey('free-grid-memory-more'),
        icon: FreeGridIcons.moreMemory,
        tooltip: 'More memory actions',
        size: 28,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final titleColor = !enabled
        ? t.disabled
        : destructive
        ? cs.error
        : t.primary;
    return MenuItemButton(
      onPressed: onPressed,
      style: MenuItemButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 268),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? t.disabled
                    : destructive
                    ? cs.error
                    : t.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    description,
                    style: t.description.copyWith(
                      color: enabled ? t.secondary : t.disabled,
                    ),
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

// ---------------------------------------------------------------- confirms

/// Asks before the memory is written flat. True when confirmed.
///
/// [backupDue] is whether this write is the first one to the memory in this
/// session, so it saves the table as a backup first; [backupTakenAt] names
/// the backup that stays otherwise.
Future<bool> confirmFreeGridReset(
  BuildContext context, {
  required String slotLabel,
  required String projector,
  required bool backupDue,
  required DateTime? backupTakenAt,
  bool unstoredChanges = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog<bool>(
      icon: Icons.restart_alt,
      title: 'Reset $slotLabel to neutral?',
      subtitle: projector,
      monoSubtitle: true,
      destructive: true,
      changes: [
        ConfirmChange(
          icon: Icons.border_all,
          lead: '$slotLabel is stored flat',
          rest: ', the image shows with no correction',
        ),
        if (backupDue)
          ConfirmChange(
            icon: Icons.save_outlined,
            lead: 'The current $slotLabel table is saved as a backup',
            rest: 'on this computer, Restore backup brings it back',
          )
        else
          ConfirmChange(
            icon: Icons.save_outlined,
            lead: backupTakenAt == null
                ? 'The backup stays'
                : 'The backup of ${freeGridTimeLabel(backupTakenAt)} stays',
            rest: ', Restore backup brings it back',
          ),
        if (unstoredChanges)
          const ConfirmChange(
            icon: Icons.error_outline,
            lead: 'Changes not stored yet',
            rest: 'are discarded',
          ),
      ],
      actions: [
        const ConfirmAction(label: 'Cancel', value: false),
        ConfirmAction(
          label: 'Reset $slotLabel',
          value: true,
          kind: ConfirmActionKind.destructive,
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks before the memory's backup is written back. True when confirmed.
Future<bool> confirmFreeGridRestore(
  BuildContext context, {
  required String slotLabel,
  required String projector,
  required DateTime backupTakenAt,
  bool unstoredChanges = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog<bool>(
      icon: Icons.history,
      title: 'Restore the $slotLabel backup?',
      subtitle: projector,
      monoSubtitle: true,
      changes: [
        ConfirmChange(
          icon: Icons.history,
          lead:
              '$slotLabel is stored as it was on '
              '${freeGridTimeLabel(backupTakenAt)}',
          rest: ', from the backup on this computer',
        ),
        if (unstoredChanges)
          const ConfirmChange(
            icon: Icons.error_outline,
            lead: 'Changes not stored yet',
            rest: 'are discarded',
          ),
      ],
      actions: [
        const ConfirmAction(label: 'Cancel', value: false),
        ConfirmAction(
          label: 'Restore $slotLabel',
          value: true,
          kind: ConfirmActionKind.filled,
        ),
      ],
    ),
  );
  return result ?? false;
}
