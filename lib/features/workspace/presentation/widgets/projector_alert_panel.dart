import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import '../providers/event_log_request_provider.dart';
import 'alert_panel_parts.dart';
import 'alert_row.dart';
import 'alert_scroll_area.dart';

/// One projector's alerts, opened from its card badge. Header with counts
/// and actions on top (never scrolls), active alerts below, acknowledged
/// ones folded at the bottom.
class ProjectorAlertPanel extends ConsumerStatefulWidget {
  const ProjectorAlertPanel({super.key, required this.node});

  static const double width = 320;

  /// List height before it scrolls, about eight rows. Less when the window
  /// is shorter: the list takes what the panel's constraints leave.
  static const double maxListHeight = 436;

  final ProjectorNode node;

  @override
  ConsumerState<ProjectorAlertPanel> createState() =>
      _ProjectorAlertPanelState();
}

class _ProjectorAlertPanelState extends ConsumerState<ProjectorAlertPanel> {
  /// Durations count up while the panel is open.
  late final Timer _tick;
  bool? _ackedOpen;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = widget.node;
    final all = sortAlerts(
      ref.watch(alertsProvider).values.where((a) => a.nodeId == node.id),
    );
    final active = [
      for (final a in all)
        if (!a.acknowledged) a,
    ];
    final acked = [
      for (final a in all)
        if (a.acknowledged) a,
    ];
    final now = DateTime.now();
    final notifier = ref.read(alertsProvider.notifier);
    final ackedOpen = _ackedOpen ?? acked.length <= 3;

    final entries = <AlertScrollEntry>[
      for (final a in active)
        (
          child: AlertRow(
            alert: a,
            now: now,
            onAcknowledge: () => notifier.acknowledge(a.key),
          ),
          height: AlertRow.height,
          counts: true,
        ),
      if (acked.isNotEmpty)
        (
          child: AcknowledgedHeader(
            count: acked.length,
            open: ackedOpen,
            onTap: () => setState(() => _ackedOpen = !ackedOpen),
          ),
          height: AcknowledgedHeader.height,
          counts: false,
        ),
      if (ackedOpen)
        for (final a in acked)
          (
            child: AcknowledgedAlertLine(alert: a, now: now),
            height: AcknowledgedAlertLine.height,
            counts: true,
          ),
    ];

    final counts = countAlerts(active);

    return AlertPanelSurface(
      width: ProjectorAlertPanel.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: AlertPanelTitle(
                    title: node.name,
                    note: node.ipAddress,
                  ),
                ),
                if (active.length > 1) ...[
                  if (counts.critical > 0)
                    AlertSeverityCount(AlertSeverity.critical, counts.critical),
                  if (counts.warning > 0)
                    AlertSeverityCount(AlertSeverity.warning, counts.warning),
                  const SizedBox(width: 4),
                ],
                if (active.isNotEmpty)
                  AlertPanelIconButton(
                    icon: Icons.done_all,
                    label: 'Acknowledge all',
                    onPressed: () => notifier.acknowledgeAll(nodeId: node.id),
                  ),
                AlertPanelIconButton(
                  icon: Icons.receipt_long,
                  label: 'Show in event log',
                  onPressed: () => ref
                      .read(eventLogRequestProvider.notifier)
                      .show(query: node.ipAddress),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No active alerts',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            Flexible(
              child: AlertScrollArea(
                entries: entries,
                maxHeight: ProjectorAlertPanel.maxListHeight,
              ),
            ),
        ],
      ),
    );
  }
}
