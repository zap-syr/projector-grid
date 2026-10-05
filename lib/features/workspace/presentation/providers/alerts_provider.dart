import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/log_event.dart';
import '../../domain/projector_node.dart';
import 'app_settings_provider.dart';
import 'event_log_provider.dart';
import 'signal_watch_provider.dart';
import 'workspace_provider.dart';

part 'alerts_provider.g.dart';

/// The active alerts, rebuilt from every workspace change. In memory only:
/// after a restart, conditions that still hold come back as new.
///
/// Every change is logged here and published on [events], which OSC (and
/// desktop notifications) subscribe to, so this provider knows nothing of
/// them.
@Riverpod(keepAlive: true)
class AlertsNotifier extends _$AlertsNotifier {
  /// Last known name and IP per projector, so an alert of a just-deleted
  /// projector can still be named when it clears.
  final Map<String, ProjectorNode> _nodes = {};

  final _events = StreamController<AlertEvent>.broadcast();

  /// Raised, cleared and acknowledged alerts, one event each, as they
  /// happen.
  Stream<AlertEvent> get events => _events.stream;

  @override
  Map<AlertKey, ActiveAlert> build() {
    ref.onDispose(_events.close);
    ref.listen(workspaceProvider, (_, nodes) => _reconcile(nodes));
    ref.listen(
      appSettingsProvider.select((s) => s.alerts),
      (_, _) => _reconcile(ref.read(workspaceProvider)),
    );
    ref.listen(
      signalWatchProvider,
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
      signalLoss: ref.read(signalWatchProvider),
    );
    for (final n in nodes) {
      _nodes[n.id] = n;
    }
    // Telemetry ticks mostly change nothing here; skipping the assignment
    // keeps every watcher from rebuilding on them.
    if (result.transitions.isNotEmpty || !mapEquals(result.active, state)) {
      state = result.active;
      for (final t in result.transitions) {
        _publish(t.change, t.alert);
      }
      // A cleared Signal lost is done with: without this its dropout would
      // raise it again on the next reconcile.
      for (final t in result.transitions) {
        if (t.change == AlertChange.cleared &&
            t.alert.rule == AlertRule.signalLost) {
          ref.read(signalWatchProvider.notifier).dismiss(t.alert.nodeId);
        }
      }
    }
    final ids = {for (final n in nodes) n.id};
    _nodes.removeWhere((id, _) => !ids.contains(id));
  }

  void acknowledge(AlertKey key) {
    final alert = state[key];
    if (alert == null || alert.acknowledged) return;
    state = {...state, key: alert.copyWith(acknowledged: true)};
    _publish(AlertChange.acknowledged, alert);
    _clearRestoredSignalLost([alert]);
  }

  /// A Signal lost whose signal is back clears on acknowledge.
  void _clearRestoredSignalLost(List<ActiveAlert> acknowledged) {
    if (acknowledged.any((a) => a.rule == AlertRule.signalLost)) {
      _reconcile(ref.read(workspaceProvider));
    }
  }

  /// Every unacknowledged alert, or only [nodeId]'s.
  void acknowledgeAll({String? nodeId}) =>
      acknowledgeWhere((a) => nodeId == null || a.nodeId == nodeId);

  /// Every unacknowledged alert that passes [test] (a group of the Active
  /// alerts panel).
  void acknowledgeWhere(bool Function(ActiveAlert) test) {
    final hits = [
      for (final a in state.values)
        if (!a.acknowledged && test(a)) a,
    ];
    if (hits.isEmpty) return;
    state = {
      for (final e in state.entries)
        e.key: hits.contains(e.value)
            ? e.value.copyWith(acknowledged: true)
            : e.value,
    };
    for (final a in hits) {
      _publish(AlertChange.acknowledged, a);
    }
    _clearRestoredSignalLost(hits);
  }

  void _publish(AlertChange change, ActiveAlert a) {
    final node = _nodes[a.nodeId];
    ref
        .read(eventLogProvider.notifier)
        .log(
          LogEvent(
            severity: switch (change) {
              AlertChange.raised =>
                a.severity == AlertSeverity.critical
                    ? LogSeverity.error
                    : LogSeverity.warning,
              AlertChange.recovered ||
              AlertChange.cleared => LogSeverity.success,
              AlertChange.acknowledged => LogSeverity.info,
            },
            type: LogEventType.alert,
            message: switch (change) {
              AlertChange.raised =>
                '${a.rule.label}: ${a.value} (${a.severity.name})',
              AlertChange.recovered => '${a.rule.label}: ${a.displayValue}',
              AlertChange.cleared => '${a.rule.label} cleared',
              AlertChange.acknowledged => '${a.rule.label} acknowledged',
            },
            projectorIp: node?.ipAddress,
            projectorName: node?.name,
          ),
        );
    _events.add((
      change: change,
      alert: a,
      projector: node?.name ?? '',
      ip: node?.ipAddress ?? '',
    ));
  }
}
