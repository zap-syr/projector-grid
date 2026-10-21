import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/monitoring_table_columns.dart';
import '../../domain/monitoring_view_settings.dart';
import '../providers/monitoring_panel_provider.dart';
import '../providers/monitoring_view_provider.dart';
import 'monitoring/monitoring_bar.dart';
import 'monitoring/monitoring_cards.dart';
import 'monitoring/monitoring_data_table.dart';
import 'monitoring/projector_panel.dart';

/// The Monitoring view (§7i of the redesign plan): the bar, the Table or
/// the Cards, and the projector panel over them. The panel never takes room
/// from the content, so columns and cards don't move when it opens.
class MonitoringTable extends ConsumerWidget {
  const MonitoringTable({super.key});

  // ── Column catalogue, for the View ▸ Monitoring Table menu ─────────────

  static List<String> get allColumnIds => [
    for (final c in kMonitoringTableColumns) c.id,
  ];

  static String labelFor(String id) => monitoringTableColumn(id)?.label ?? id;

  static List<String> resolveVisible(List<String> saved) =>
      resolveMonitoringTableColumns(saved);

  static List<String>? toggledColumn(List<String> saved, String id) =>
      toggleMonitoringTableColumn(saved, id);

  static const Map<String, List<String>> presets = kMonitoringTablePresets;

  static List<String> get showAllColumns => allColumnIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(monitoringViewProvider.select((s) => s.mode));
    final panelId = ref.watch(monitoringPanelProvider);
    return ColoredBox(
      color: AppTheme.windowBackground(Theme.of(context).colorScheme),
      child: Column(
        children: [
          const MonitoringBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: mode == MonitoringViewMode.table
                        ? const MonitoringDataTable()
                        : const MonitoringCards(),
                  ),
                  if (panelId != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: constraints.maxWidth < kProjectorPanelWidth
                          ? constraints.maxWidth
                          : kProjectorPanelWidth,
                      child: ProjectorPanel(
                        key: ValueKey(panelId),
                        nodeId: panelId,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
