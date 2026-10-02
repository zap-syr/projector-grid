import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/log_event.dart';
import '../../domain/projector_node.dart';
import 'app_settings_provider.dart';
import 'event_log_provider.dart';
import 'workspace_provider.dart';

part 'alerts_provider.g.dart';

/// The active alerts, rebuilt from every workspace change. In memory only:
/// after a restart, conditions that still hold come back as new.
@Riverpod(keepAlive: true)
class AlertsNotifier extends _$AlertsNotifier {
  /// Last known name and IP per projector, so an alert of a just-deleted
  /// projector can still be logged by name when it clears.
  final Map<String, ProjectorNode> _nodes = {};

  @override
  Map<AlertKey, ActiveAlert> build() {
    ref.listen(workspaceProvider, (_, nodes) => _reconcile(nodes));
    ref.listen(
      appSettingsProvider.select((s) => s.alerts),
      (_, _) => _reconcile(ref.read(workspaceProvider)),
    );
    // Another provider's state can't change during build, and the event log
    // is one.
    Future.microtask(() => _reconcile(ref.read(workspaceProvider)));
    return const {};
  }

  void _reconcile(List<ProjectorNode> nodes) {
    final result = reconcileAlerts(
      previous: state,
      nodes: nodes,
      settings: ref.read(appSettingsProvider).alerts,
      now: DateTime.now(),
    );
    for (final n in nodes) {
      _nodes[n.id] = n;
    }
    // Telemetry ticks mostly change nothing here; skipping the assignment
    // keeps every watcher from rebuilding on them.
    if (result.transitions.isNotEmpty || !mapEquals(result.active, state)) {
      state = result.active;
      for (final t in result.transitions) {
        _log(t);
      }
    }
    final ids = {for (final n in nodes) n.id};
    _nodes.removeWhere((id, _) => !ids.contains(id));
  }

  void acknowledge(AlertKey key) {
    final alert = state[key];
    if (alert == null || alert.acknowledged) return;
    state = {...state, key: alert.copyWith(acknowledged: true)};
    _logAcknowledged([alert]);
  }

  /// Every unacknowledged alert, or only [nodeId]'s.
  void acknowledgeAll({String? nodeId}) {
    final hits = [
      for (final a in state.values)
        if (!a.acknowledged && (nodeId == null || a.nodeId == nodeId)) a,
    ];
    if (hits.isEmpty) return;
    state = {
      for (final e in state.entries)
        e.key: hits.contains(e.value)
            ? e.value.copyWith(acknowledged: true)
            : e.value,
    };
    _logAcknowledged(hits);
  }

  void _log(AlertTransition t) {
    final a = t.alert;
    final raised = t.change == AlertChange.raised;
    _write(
      a,
      severity: !raised
          ? LogSeverity.success
          : a.severity == AlertSeverity.critical
          ? LogSeverity.error
          : LogSeverity.warning,
      message: raised
          ? '${a.rule.label}: ${a.value} (${a.severity.name})'
          : '${a.rule.label} cleared',
    );
  }

  void _logAcknowledged(List<ActiveAlert> alerts) {
    for (final a in alerts) {
      _write(
        a,
        severity: LogSeverity.info,
        message: '${a.rule.label} acknowledged',
      );
    }
  }

  void _write(
    ActiveAlert a, {
    required LogSeverity severity,
    required String message,
  }) {
    final node = _nodes[a.nodeId];
    ref
        .read(eventLogProvider.notifier)
        .log(
          LogEvent(
            severity: severity,
            type: LogEventType.alert,
            message: message,
            projectorIp: node?.ipAddress,
            projectorName: node?.name,
          ),
        );
  }
}
