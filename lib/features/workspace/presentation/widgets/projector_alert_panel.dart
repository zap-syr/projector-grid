import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import '../providers/event_log_request_provider.dart';
import 'alert_panel_parts.dart';
import 'alert_row.dart';
import 'alert_scroll_area.dart';

/// One projector's alerts, opened from its card badge (plan §7m.1): a
/// header with the model, IP and severity pills, its active alerts,
/// acknowledged ones folded at the bottom and the footer. No filter row and
/// no grouping controls.
class ProjectorAlertPanel extends ConsumerStatefulWidget {
  const ProjectorAlertPanel({super.key, required this.node});

  static const double width = 340;

  /// List height before it scrolls. Less when the window is shorter: the
  /// list takes what the panel's constraints leave.
  static const double maxListHeight = 436;

  final ProjectorNode node;

  @override
  ConsumerState<ProjectorAlertPanel> createState() =>
      _ProjectorAlertPanelState();
}

class _ProjectorAlertPanelState extends ConsumerState<ProjectorAlertPanel> {
  /// Start times' tooltips count up while the panel is open.
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
    final t = AppText.of(context);
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
    final ackedOpen = _ackedOpen ?? (active.isEmpty || acked.length <= 3);
    const rowWidth = ProjectorAlertPanel.width - AlertPanelList.inset;

    final entries = <AlertScrollEntry>[
      if (active.isEmpty && acked.isNotEmpty)
        (
          child: const AlertPanelNotice(
            icon: Icons.done_all,
            title: 'All acknowledged',
            text:
                'These alerts are still active and leave the list when the '
                'condition clears',
          ),
          height: AlertPanelNotice.height,
          counts: false,
        ),
      for (final a in active)
        (
          child: AlertRow(
            alert: a,
            now: now,
            onAcknowledge: () => notifier.acknowledge(a.key),
          ),
          height: AlertRow.heightFor(
            context,
            alert: a,
            now: now,
            width: rowWidth,
          ),
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

    return AlertPanelSurface(
      width: ProjectorAlertPanel.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertPanelHeader(
            title: node.name,
            note: Text(node.ipAddress, style: t.monoSmall),
            actions: [AlertCountPills(all)],
          ),
          if (entries.isEmpty)
            const AlertPanelNothingActive()
          else
            Flexible(
              child: AlertPanelList(
                entries: entries,
                maxHeight: ProjectorAlertPanel.maxListHeight,
              ),
            ),
          AlertPanelFooter(
            onEventLog: () => ref
                .read(eventLogRequestProvider.notifier)
                .show(query: node.ipAddress),
            onAcknowledgeAll: active.isEmpty
                ? null
                : () => notifier.acknowledgeAll(nodeId: node.id),
          ),
        ],
      ),
    );
  }
}
