import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/event_log_request_provider.dart';
import 'alert_panel_parts.dart';
import 'alert_row.dart';
import 'alert_scroll_area.dart';

/// One projector's alerts, opened from its card badge: a compact popover,
/// not a second Active alerts panel (owner, 2026-10-20). A 40 px header
/// with the model, IP, severity pills and two icon buttons (Acknowledge
/// all while something is unacknowledged, Show in event log), the rows of
/// the Active alerts panel, acknowledged ones folded at the bottom. No
/// filter row, grouping controls or footer.
class ProjectorAlertPanel extends ConsumerStatefulWidget {
  const ProjectorAlertPanel({super.key, required this.node});

  static const double width = 320;

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
    final settings = ref.watch(appSettingsProvider.select((s) => s.alerts));
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
          child: const _CompactNote('All acknowledged'),
          height: _CompactNote.height,
          counts: false,
        ),
      for (final a in active)
        (
          child: AlertRow(
            alert: a,
            now: now,
            limit: alertLimit(a, settings),
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
          SizedBox(
            key: const ValueKey('projector-alerts-header'),
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              child: Row(
                spacing: 6,
                children: [
                  // The model gives way when pills and buttons need the room;
                  // the IP, the projector's identity, stays whole.
                  Expanded(
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(node.ipAddress, maxLines: 1, style: t.monoSmall),
                      ],
                    ),
                  ),
                  AlertCountPills(all),
                  // Before Event log, so that one keeps its place when this
                  // goes with nothing left to acknowledge.
                  if (active.isNotEmpty)
                    AlertPanelIconButton(
                      key: const ValueKey('alerts-acknowledge-all'),
                      icon: Icons.done_all,
                      label: 'Acknowledge all',
                      onPressed: () => notifier.acknowledgeAll(nodeId: node.id),
                    ),
                  AlertPanelIconButton(
                    key: const ValueKey('alerts-event-log'),
                    icon: Icons.list,
                    label: 'Show in event log',
                    onPressed: () => ref
                        .read(eventLogRequestProvider.notifier)
                        .show(query: node.ipAddress),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            const _CompactNote('No active alerts', divided: true)
          else
            Flexible(
              child: AlertPanelList(
                entries: entries,
                maxHeight: ProjectorAlertPanel.maxListHeight,
              ),
            ),
        ],
      ),
    );
  }

  static const double _headerHeight = 40;
}

/// One quiet line in place of the big notices: the popover stays small.
class _CompactNote extends StatelessWidget {
  const _CompactNote(this.text, {this.divided = false});

  static const double height = 36;

  final String text;

  /// With the hairline the list would draw above it.
  final bool divided;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: divided
        ? BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          )
        : null,
    child: Text(text, style: AppText.of(context).description),
  );
}
