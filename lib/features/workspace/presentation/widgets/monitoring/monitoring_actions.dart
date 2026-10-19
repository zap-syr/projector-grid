import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/external_links.dart';
import '../../../domain/monitoring_filter.dart';
import '../../../domain/projector_node.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/canvas_reveal_provider.dart';
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_panel_provider.dart';
import '../../providers/monitoring_reveal_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/menu_check_gutter.dart';
import '../custom_tooltip.dart';
import '../remote_preview_dialog.dart';

/// The actions the projector panel and the row actions share.

void openMonitoringPreview(
  BuildContext context,
  WidgetRef ref,
  ProjectorNode node,
) {
  final groups = ref.read(workspaceProvider.notifier).groups;
  showRemotePreviewDialog(
    context,
    [node],
    groups: {for (final g in groups) g.id: g},
  );
}

void openProjectorWebUi(ProjectorNode node) =>
    openInBrowser('http://${node.ipAddress}');

/// Jumps [controller] so an item at [top] with [extent] sits in the middle
/// of the viewport, as far as the scroll range allows.
void centerScrollOn(ScrollController controller, double top, double extent) {
  if (!controller.hasClients) return;
  final p = controller.position;
  controller.jumpTo(
    (top - (p.viewportDimension - extent) / 2).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    ),
  );
}

/// Switches to Controls with only [nodeId] selected and its card scrolled
/// into view. Takes the container, not a WidgetRef: a menu item runs its
/// action a frame after the menu closes, when the row's hover actions (and
/// their ref) may already be gone.
void findOnCanvas(ProviderContainer container, String nodeId) {
  container.read(selectionProvider.notifier).selectOnly(nodeId);
  container.read(appSettingsProvider.notifier).setMonitoringView(false);
  container.read(canvasRevealProvider.notifier).reveal(nodeId);
}

/// Switches to Monitoring with [node]'s panel open and its row or card
/// scrolled into view. A search or quick filter that hides the projector
/// is cleared and its collapsed group expanded, so the row is there to
/// highlight beside the panel.
void showInMonitoring(ProviderContainer container, ProjectorNode node) {
  final filter = container.read(monitoringFilterProvider);
  final passes =
      (filter.quick == MonitoringQuickFilter.all ||
          quickFilterIds(
            container.read(monitoringStatusProvider),
            filter.quick,
          ).contains(node.id)) &&
      matchesSearch(node, filter.query);
  if (!passes) container.read(monitoringFilterProvider.notifier).clear();
  // The section key: the group's id, or '' for Ungrouped (a node whose
  // group is gone sits there too).
  final grouped = container
      .read(workspaceProvider.notifier)
      .groups
      .any((g) => g.id == node.groupId);
  container
      .read(monitoringViewProvider.notifier)
      .expand(grouped ? node.groupId! : '');
  container.read(monitoringPanelProvider.notifier).open(node.id);
  container.read(monitoringRevealProvider.notifier).reveal(node.id);
  container.read(appSettingsProvider.notifier).setMonitoringView(true);
}

/// A table row's actions, shown on hover: Remote Preview and a ⋮ menu.
/// [onMenuOpenChanged] keeps them shown while the menu is open, after the
/// pointer has left the row for it.
class MonitoringRowActions extends ConsumerWidget {
  const MonitoringRowActions({
    super.key,
    required this.node,
    required this.onMenuOpenChanged,
  });

  final ProjectorNode node;
  final ValueChanged<bool> onMenuOpenChanged;

  /// 32 px buttons, so two fit the 76 px actions cell on every platform.
  static const _compact = ButtonStyle(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    const constraints = BoxConstraints.tightFor(width: 32, height: 32);
    // The menu items run a frame after the menu closes; by then the pointer
    // has left the row and these actions are unmounted, so the items must
    // not touch `ref` or `context`.
    final container = ProviderScope.containerOf(context, listen: false);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        CustomTooltip(
          message: 'Remote Preview',
          child: IconButton(
            icon: const Icon(Icons.monitor_outlined, size: 18),
            color: cs.onSurfaceVariant,
            padding: EdgeInsets.zero,
            constraints: constraints,
            style: _compact,
            onPressed: () => openMonitoringPreview(context, ref, node),
          ),
        ),
        MenuAnchor(
          alignmentOffset: const Offset(0, 4),
          onOpen: () => onMenuOpenChanged(true),
          onClose: () => onMenuOpenChanged(false),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const MenuCheckGutter(),
              onPressed: () => container
                  .read(monitoringPanelProvider.notifier)
                  .open(node.id),
              child: const Text('Show details'),
            ),
            MenuItemButton(
              leadingIcon: const MenuCheckGutter(),
              onPressed: () => openProjectorWebUi(node),
              child: const Text('Open Web UI'),
            ),
            MenuItemButton(
              leadingIcon: const MenuCheckGutter(),
              onPressed: () => findOnCanvas(container, node.id),
              child: const Text('Find on canvas'),
            ),
          ],
          builder: (context, controller, _) => IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            color: cs.onSurfaceVariant,
            padding: EdgeInsets.zero,
            constraints: constraints,
            style: _compact,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ],
    );
  }
}
