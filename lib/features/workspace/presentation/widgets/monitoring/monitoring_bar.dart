import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/monitoring_table_columns.dart';
import '../../../domain/monitoring_view_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../common/menu_check_gutter.dart';
import '../common/segmented_tabs.dart';
import '../custom_tooltip.dart';

/// The 56 px bar above the data (§7i.1). Its controls sit on the right, so
/// search and filters can come in on the left later without moving them:
/// Group by, then a slot that holds the column chooser in Table and the
/// density switch in Cards (as wide as the wider of the two, so nothing
/// right of it moves), then Table / Cards.
class MonitoringBar extends ConsumerWidget {
  const MonitoringBar({super.key});

  static const double height = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(monitoringViewProvider.select((s) => s.mode));
    final density = ref.watch(
      monitoringViewProvider.select((s) => s.cardDensity),
    );
    final notifier = ref.read(monitoringViewProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, c) => _row(context, notifier, mode, density, c),
      ),
    );
  }

  /// Below [_narrow] the view switch drops its words for its icons, so the
  /// bar fits the smallest window (800 wide).
  static const double _narrow = 860;

  Widget _row(
    BuildContext context,
    MonitoringViewNotifier notifier,
    MonitoringViewMode mode,
    MonitoringCardDensity density,
    BoxConstraints c,
  ) {
    final narrow = c.maxWidth < _narrow;
    return Row(
      children: [
        const Spacer(),
        const _GroupByButton(),
        const SizedBox(width: 12),
        IndexedStack(
          key: const ValueKey('monitoring-bar-slot'),
          alignment: Alignment.centerRight,
          index: mode == MonitoringViewMode.table ? 0 : 1,
          children: [
            const _ColumnsButton(),
            SegmentedTabs<MonitoringCardDensity>(
              expand: false,
              tabs: const [
                SegmentedTab(
                  value: MonitoringCardDensity.compact,
                  label: 'Compact',
                ),
                SegmentedTab(
                  value: MonitoringCardDensity.extended,
                  label: 'Extended',
                ),
              ],
              selected: density,
              onChanged: notifier.setCardDensity,
            ),
          ],
        ),
        const SizedBox(width: 12),
        SegmentedTabs<MonitoringViewMode>(
          key: const ValueKey('monitoring-view-switch'),
          expand: false,
          tabs: [
            SegmentedTab(
              value: MonitoringViewMode.table,
              label: narrow ? '' : 'Table',
              icon: Icons.table_rows_outlined,
            ),
            SegmentedTab(
              value: MonitoringViewMode.cards,
              label: narrow ? '' : 'Cards',
              icon: Icons.grid_view_outlined,
            ),
          ],
          selected: mode,
          onChanged: notifier.setMode,
        ),
      ],
    );
  }
}

class _GroupByButton extends ConsumerWidget {
  const _GroupByButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byGroup = ref.watch(
      monitoringViewProvider.select((s) => s.groupByGroup),
    );
    final notifier = ref.read(monitoringViewProvider.notifier);
    final t = AppText.of(context);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: byGroup),
          onPressed: () => notifier.setGroupByGroup(true),
          child: const Text('Group'),
        ),
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: !byGroup),
          onPressed: () => notifier.setGroupByGroup(false),
          child: const Text('None'),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.only(left: 14, right: 8),
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              byGroup ? 'Group by: group' : 'Group by: none',
              style: t.body.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 20, color: t.secondary),
          ],
        ),
      ),
    );
  }
}

/// The column chooser: a checkbox per column, then *Show all columns* and
/// *Fit columns to window*. The menu stays open while columns are toggled.
class _ColumnsButton extends ConsumerWidget {
  const _ColumnsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(monitoringViewProvider.select((s) => s.columns));
    final fit = ref.watch(
      appSettingsProvider.select((s) => s.monitoringFitToWidth),
    );
    final visible = resolveMonitoringTableColumns(saved);
    final notifier = ref.read(monitoringViewProvider.notifier);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final c in kMonitoringTableColumns)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: MenuCheckGutter(checked: visible.contains(c.id)),
            onPressed: () => notifier.toggleColumn(c.id),
            child: SizedBox(width: 180, child: Text(c.label)),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const MenuCheckGutter(),
          onPressed: () => notifier.setColumns([
            for (final c in kMonitoringTableColumns) c.id,
          ]),
          child: const Text('Show all columns'),
        ),
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: fit),
          onPressed: () => ref
              .read(appSettingsProvider.notifier)
              .setMonitoringFitToWidth(!fit),
          child: const Text('Fit columns to window'),
        ),
      ],
      builder: (context, controller, _) => CustomTooltip(
        message: 'Columns',
        child: IconButton(
          icon: const Icon(Icons.view_column_outlined, size: 20),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
