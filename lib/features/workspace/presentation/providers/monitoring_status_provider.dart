import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/alerts.dart';
import '../../domain/monitoring_status.dart';
import 'alerts_provider.dart';
import 'app_settings_provider.dart';
import 'workspace_provider.dart';

part 'monitoring_status_provider.g.dart';

/// Every projector's [MonitoringStatus] by node id. Rows, cards and group
/// rows `select` their own entry or summary out of it, and the statuses
/// compare by value, so a poll that changes nothing they show rebuilds
/// none of them.
@riverpod
Map<String, MonitoringStatus> monitoringStatus(Ref ref) {
  final nodes = ref.watch(workspaceProvider);
  final alerts = ref.watch(alertsProvider);
  final settings = ref.watch(appSettingsProvider.select((s) => s.alerts));
  final byNode = <String, List<ActiveAlert>>{};
  for (final a in alerts.values) {
    (byNode[a.nodeId] ??= []).add(a);
  }
  return {
    for (final n in nodes)
      n.id: monitoringStatusOf(n, byNode[n.id] ?? const [], settings),
  };
}
