import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/custom_command.dart';
import '../../providers/custom_commands_provider.dart';
import '../common/confirm_dialog.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import '../custom_command_dialog.dart';
import 'control_bar_parts.dart';
import 'control_bar_scroll.dart';

/// The user's commands in one card (drag to reorder, Run, ⋮ with Edit and
/// Delete), a dashed Add command button and the OSC hint.
class CustomTab extends ConsumerWidget {
  const CustomTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = watchHasSelection(ref);
    final commands = ref.watch(customCommandsProvider);
    final notifier = ref.read(customCommandsProvider.notifier);
    final t = AppText.of(context);

    return ControlBarScroll(
      children: [
        ControlBarCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: commands.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No custom commands yet',
                    textAlign: TextAlign.center,
                    style: t.description,
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: commands.length,
                  onReorderItem: notifier.reorder,
                  itemBuilder: (context, index) {
                    final cmd = commands[index];
                    return _CommandRow(
                      key: ValueKey(cmd.id),
                      index: index,
                      command: cmd,
                      showDivider: index > 0,
                      onRun: enabled
                          ? () => sendToSelected(ref, cmd.command)
                          : null,
                      onEdit: () => showDialog<void>(
                        context: context,
                        builder: (_) => CustomCommandDialog(existing: cmd),
                      ),
                      onDelete: () async {
                        final confirmed = await confirmDestructive(
                          context,
                          title: 'Delete “${cmd.name}”?',
                          subtitle: 'The command is removed from this app.',
                          confirmLabel: 'Delete',
                          changes: [
                            ConfirmChange(
                              icon: Icons.sensors,
                              lead: '/pgrid/all/custom/${cmd.oscSlug}',
                              rest: 'no longer answers',
                              monoLead: true,
                            ),
                          ],
                        );
                        if (confirmed) notifier.remove(cmd.id);
                      },
                    );
                  },
                ),
        ),
        const _AddCommandButton(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Each command also answers on OSC at '),
                TextSpan(text: '/pgrid/all/custom/<name>', style: t.monoSmall),
                const TextSpan(text: '. Edit or delete it from its ⋮ menu.'),
              ],
            ),
            style: t.description,
          ),
        ),
      ],
    );
  }
}

class _AddCommandButton extends StatelessWidget {
  const _AddCommandButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return DashedBorder(
      radius: 10,
      color: t.tertiary,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('add-custom-command'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const CustomCommandDialog(),
          ),
          child: SizedBox(
            height: ControlBarMetrics.commandButtonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Add command',
                  style: t.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    super.key,
    required this.index,
    required this.command,
    required this.showDivider,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final CustomCommand command;
  final bool showDivider;
  final VoidCallback? onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        // Filled, so the row lifted while dragging isn't see-through.
        color: DialogSurfaces.of(context).card,
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                width: 28,
                height: 36,
                child: Icon(Icons.drag_indicator, size: 16, color: t.tertiary),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  command.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  command.command,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.monoSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CommandButton(
            key: ValueKey('run-${command.id}'),
            label: 'Run',
            icon: Icons.play_arrow,
            onPressed: onRun,
          ),
          const SizedBox(width: 2),
          _MoreMenu(
            key: ValueKey('more-${command.id}'),
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

/// The ⋮ menu of a command row: Edit and Delete.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({super.key, required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(Icons.edit_outlined, size: 18, color: t.secondary),
          onPressed: onEdit,
          child: const Text('Edit'),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline, size: 18, color: cs.error),
          onPressed: onDelete,
          child: Text('Delete', style: TextStyle(color: cs.error)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        color: t.secondary,
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
