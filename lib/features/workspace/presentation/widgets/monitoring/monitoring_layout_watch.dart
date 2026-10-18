import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/monitoring_filter.dart';
import '../../../domain/monitoring_layout.dart';
import '../../../domain/projector_node.dart';
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';

/// Whether the bar's search and quick filter let a projector through. The
/// quick filter's ids come through a `select`, so a poll that moves nobody
/// in or out rebuilds nothing.
bool Function(ProjectorNode) watchMonitoringFilter(WidgetRef ref) {
  final filter = ref.watch(monitoringFilterProvider);
  final passing = filter.quick == MonitoringQuickFilter.all
      ? null
      : ref.watch(
          monitoringStatusProvider.select(
            (m) => quickFilterIds(m, filter.quick),
          ),
        );
  return (n) =>
      (passing?.contains(n.id) ?? true) && matchesSearch(n, filter.query);
}

/// The sorted, sectioned projectors the table and the cards lay out, after
/// the bar's filter. A `select`, so a poll rebuilds the caller only when the
/// order or the sections change; group edits come through the workspace's
/// own state change.
MonitoringLayout watchMonitoringLayout(WidgetRef ref) {
  final sortId = ref.watch(
    monitoringViewProvider.select((s) => s.sortColumnId),
  );
  final ascending = ref.watch(
    monitoringViewProvider.select((s) => s.sortAscending),
  );
  final byGroup = ref.watch(
    monitoringViewProvider.select((s) => s.groupByGroup),
  );
  final shows = watchMonitoringFilter(ref);
  final notifier = ref.read(workspaceProvider.notifier);
  return ref.watch(
    workspaceProvider.select(
      (nodes) => monitoringLayout(
        nodes.where(shows).toList(),
        notifier.groups,
        columnId: sortId,
        ascending: ascending,
        byGroup: byGroup,
      ),
    ),
  );
}
