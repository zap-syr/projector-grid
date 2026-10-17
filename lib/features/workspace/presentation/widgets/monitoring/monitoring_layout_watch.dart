import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/monitoring_layout.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';

/// The sorted, sectioned projectors the table and the cards lay out. A
/// `select`, so a poll rebuilds the caller only when the order or the
/// sections change; group edits come through the workspace's own state
/// change.
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
  final notifier = ref.read(workspaceProvider.notifier);
  return ref.watch(
    workspaceProvider.select(
      (nodes) => monitoringLayout(
        nodes,
        notifier.groups,
        columnId: sortId,
        ascending: ascending,
        byGroup: byGroup,
      ),
    ),
  );
}
