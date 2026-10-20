import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/event_log_request_provider.dart';
import '../providers/workspace_provider.dart';
import 'alert_panel_parts.dart';
import 'alert_row.dart';
import 'alert_scroll_area.dart';
import 'common/bar_chip.dart';
import 'common/segmented_tabs.dart';
import 'common/severity_pill.dart';
import 'custom_tooltip.dart';

/// Every active alert in the project, opened from the status bar (plan
/// §7m): grouped by projector (optionally inside the project's groups) or
/// by alert, filterable by severity, acknowledged ones folded at the
/// bottom, Acknowledge all in the footer. It only holds conditions true
/// right now, so it stays bounded; history is in the event log.
class ActiveAlertsPanel extends ConsumerStatefulWidget {
  const ActiveAlertsPanel({super.key});

  static const double width = 420;

  /// Less when the window is shorter: the list takes what the panel's
  /// constraints leave.
  static const double maxListHeight = 520;

  /// Groups start folded past this many.
  static const int foldAbove = 4;

  @override
  ConsumerState<ActiveAlertsPanel> createState() => _ActiveAlertsPanelState();
}

class _ActiveAlertsPanelState extends ConsumerState<ActiveAlertsPanel> {
  /// Indent of the rows under their group header.
  static const double _rowIndent = 12;

  /// Indent of the groups inside a project-group section.
  static const double _sectionIndent = 14;

  late final Timer _tick;
  AlertSeverity? _filter;

  /// Folded / unfolded by hand, keyed by grouping and group key; groups not
  /// in here follow the default.
  final _open = <String, bool>{};
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

  void _saveAlertSettings(AlertSettings Function(AlertSettings) change) {
    final settings = ref.read(appSettingsProvider);
    ref
        .read(appSettingsProvider.notifier)
        .setAlertSettings(change(settings.alerts));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final alerts = ref.watch(alertsProvider).values.toList();
    final settings = ref.watch(appSettingsProvider.select((s) => s.alerts));
    final grouping = settings.grouping;
    // Watching the nodes also rebuilds on group edits: the workspace bumps
    // its state for those.
    final nodes = {for (final n in ref.watch(workspaceProvider)) n.id: n};
    final projectGroups = ref.read(workspaceProvider.notifier).groups;
    final notifier = ref.read(alertsProvider.notifier);
    final now = DateTime.now();

    final byProjector = grouping == AlertGrouping.projector;
    // Offered in both groupings, so switching them doesn't move the header:
    // projector groups go into sections, an alert's rows into subsections.
    final canSection = projectGroups.isNotEmpty;
    final sectioned = canSection && settings.byProjectGroups;
    final groupOrder = [for (final g in projectGroups) g.id];
    String? groupOf(String nodeId) => nodes[nodeId]?.groupId;
    ProjectorGroup? projectGroup(String? id) =>
        projectGroups.where((g) => g.id == id).firstOrNull;

    final unacked = [
      for (final a in alerts)
        if (!a.acknowledged) a,
    ];
    // The filter row is for what is still to acknowledge: with nothing left
    // it is hidden (three chips at 0 over the acknowledged list read as
    // broken), and so is its effect.
    final showFilters = unacked.isNotEmpty;
    final filter = showFilters ? _filter : null;
    // A severity filter is for what is still wrong; recovered ones show
    // under All only.
    bool passes(ActiveAlert a) =>
        filter == null || (a.severity == filter && !a.recovered);
    final counts = countAlerts(unacked);
    final groups = groupAlerts(
      unacked.where(passes),
      grouping,
      ipOf: (id) => nodes[id]?.ipAddress,
    );
    final acked = sortAlerts(alerts.where((a) => a.acknowledged && passes(a)));

    String openKey(String key) => '${grouping.name}|$key';
    bool isOpen(AlertGroup g) =>
        _open[openKey(g.key)] ?? groups.length <= ActiveAlertsPanel.foldAbove;
    bool sectionOpen(String? id) => _open['section|$id'] ?? true;
    bool subsectionOpen(String rule, String? id) =>
        _open['sub|$rule|$id'] ?? true;
    // Everything Fold all / Unfold all reaches, in both groupings: the groups,
    // and the project-group sections or an alert's subsections.
    final foldable = <(String, bool)>[
      for (final g in groups) (openKey(g.key), isOpen(g)),
      if (sectioned && byProjector)
        for (final s in sectionByProjectGroup(groups, groupOf, groupOrder))
          ('section|${s.groupId}', sectionOpen(s.groupId)),
      if (sectioned && !byProjector)
        for (final g in groups)
          for (final s in subsectionByProjectGroup(
            g.alerts,
            groupOf,
            groupOrder,
          ))
            ('sub|${g.key}|${s.groupId}', subsectionOpen(g.key, s.groupId)),
    ];
    final allOpen = foldable.isNotEmpty && foldable.every((f) => f.$2);
    // With nothing left to acknowledge the acknowledged lines are the list.
    final ackedOpen = _ackedOpen ?? (unacked.isEmpty || acked.length <= 3);

    void acknowledgeAlerts(Iterable<ActiveAlert> alerts) {
      final keys = {for (final a in alerts) a.key};
      notifier.acknowledgeWhere((a) => keys.contains(a.key));
    }

    void acknowledgeGroups(Iterable<AlertGroup> gs) =>
        acknowledgeAlerts([for (final g in gs) ...g.alerts]);

    Widget indent(double by, Widget child) => by == 0
        ? child
        : Padding(
            padding: EdgeInsets.only(left: by),
            child: child,
          );

    const listWidth = ActiveAlertsPanel.width - AlertPanelList.inset;

    List<AlertScrollEntry> rowEntries(
      Iterable<ActiveAlert> alerts,
      double by,
    ) => [
      for (final a in alerts)
        (
          child: indent(
            by,
            AlertRow(
              alert: a,
              now: now,
              ip: byProjector ? null : nodes[a.nodeId]?.ipAddress,
              model: byProjector
                  ? null
                  : nodes[a.nodeId]?.name ?? 'Removed projector',
              limit: alertLimit(a, settings),
              onAcknowledge: () => notifier.acknowledge(a.key),
            ),
          ),
          height: AlertRow.heightFor(
            context,
            alert: a,
            now: now,
            width: listWidth - by,
            withProjector: !byProjector,
          ),
          counts: true,
        ),
    ];

    /// An alert group's rows, split by project group when sectioned.
    List<AlertScrollEntry> ruleRowEntries(AlertGroup g) {
      if (!sectioned) return rowEntries(g.alerts, _rowIndent);
      return [
        for (final s in subsectionByProjectGroup(
          g.alerts,
          groupOf,
          groupOrder,
        )) ...[
          (
            child: indent(
              _rowIndent,
              _SectionHeader(
                group: projectGroup(s.groupId),
                projectors: {for (final a in s.alerts) a.nodeId}.length,
                alerts: s.alerts,
                open: subsectionOpen(g.key, s.groupId),
                onToggle: () => setState(
                  () => _open['sub|${g.key}|${s.groupId}'] = !subsectionOpen(
                    g.key,
                    s.groupId,
                  ),
                ),
                onAcknowledge: () => acknowledgeAlerts(s.alerts),
              ),
            ),
            height: _SectionHeader.height,
            counts: false,
          ),
          if (subsectionOpen(g.key, s.groupId))
            ...rowEntries(s.alerts, _rowIndent + _sectionIndent),
        ],
      ];
    }

    List<AlertScrollEntry> groupEntries(AlertGroup g, double by) {
      final open = isOpen(g);
      return [
        (
          child: indent(
            by,
            _GroupHeader(
              group: g,
              node: byProjector ? nodes[g.key] : null,
              byAlert: !byProjector,
              open: open,
              now: now,
              onToggle: () => setState(() => _open[openKey(g.key)] = !open),
              onAcknowledge: () => acknowledgeGroups([g]),
            ),
          ),
          height: _GroupHeader.height,
          counts: !open,
        ),
        if (open)
          ...(byProjector
              ? rowEntries(g.alerts, by + _rowIndent)
              : ruleRowEntries(g)),
      ];
    }

    final entries = <AlertScrollEntry>[
      if (unacked.isEmpty)
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
        )
      else if (groups.isEmpty && filter != null)
        (
          child: AlertPanelNotice(
            title: alertFilterEmptyTitle(filter),
            text: alertsHiddenByFilter(unacked, filter),
            action: TextButton(
              onPressed: () => setState(() => _filter = null),
              child: const Text('Show all'),
            ),
          ),
          height: AlertPanelNotice.height,
          counts: false,
        ),
      if (sectioned && byProjector)
        for (final s in sectionByProjectGroup(groups, groupOf, groupOrder)) ...[
          (
            child: _SectionHeader(
              group: projectGroup(s.groupId),
              projectors: s.groups.length,
              alerts: [for (final g in s.groups) ...g.alerts],
              open: sectionOpen(s.groupId),
              onToggle: () => setState(
                () => _open['section|${s.groupId}'] = !sectionOpen(s.groupId),
              ),
              onAcknowledge: () => acknowledgeGroups(s.groups),
            ),
            height: _SectionHeader.height,
            counts: false,
          ),
          if (sectionOpen(s.groupId))
            for (final g in s.groups) ...groupEntries(g, _sectionIndent),
        ]
      else
        for (final g in groups) ...groupEntries(g, 0),
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
            child: AcknowledgedAlertLine(
              alert: a,
              now: now,
              ip: nodes[a.nodeId]?.ipAddress,
            ),
            height: AcknowledgedAlertLine.height,
            counts: true,
          ),
    ];

    final String? note = alerts.isEmpty
        ? null
        : unacked.isEmpty
        ? '${alerts.length} acknowledged'
        : '${unacked.length} active';

    return AlertPanelSurface(
      width: ActiveAlertsPanel.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertPanelHeader(
            title: 'Active alerts',
            note: note == null
                ? null
                : Text(
                    note,
                    key: const ValueKey('alerts-header-note'),
                    style: t.description,
                  ),
            actions: [
              if (alerts.isNotEmpty) ...[
                if (canSection)
                  AlertPanelIconButton(
                    icon: Icons.layers_outlined,
                    label: 'Sort into project groups',
                    selected: sectioned,
                    onPressed: () => _saveAlertSettings(
                      (s) => s.copyWith(byProjectGroups: !s.byProjectGroups),
                    ),
                  ),
                SegmentedTabs<AlertGrouping>(
                  iconOnly: true,
                  expand: false,
                  selected: grouping,
                  onChanged: (g) =>
                      _saveAlertSettings((s) => s.copyWith(grouping: g)),
                  tabs: const [
                    SegmentedTab(
                      value: AlertGrouping.projector,
                      label: 'By projector',
                      icon: Icons.videocam_outlined,
                    ),
                    SegmentedTab(
                      value: AlertGrouping.alert,
                      label: 'By alert',
                      icon: Icons.notifications_none,
                    ),
                  ],
                ),
                AlertPanelIconButton(
                  icon: allOpen ? Icons.unfold_less : Icons.unfold_more,
                  label: allOpen ? 'Fold all' : 'Unfold all',
                  onPressed: foldable.isEmpty
                      ? null
                      : () => setState(() {
                          for (final (key, _) in foldable) {
                            _open[key] = !allOpen;
                          }
                        }),
                ),
              ],
            ],
          ),
          if (alerts.isEmpty)
            const AlertPanelNothingActive()
          else ...[
            if (showFilters)
              _Filters(
                filter: filter,
                counts: counts,
                onFilter: (f) => setState(() => _filter = f),
              ),
            Flexible(
              child: AlertPanelList(
                entries: entries,
                maxHeight: ActiveAlertsPanel.maxListHeight,
              ),
            ),
          ],
          AlertPanelFooter(
            onEventLog: () => ref
                .read(eventLogRequestProvider.notifier)
                .show(alertsOnly: true),
            // Everything, also what the filter hides (owner, 2026-10-20).
            onAcknowledgeAll: unacked.isEmpty ? null : notifier.acknowledgeAll,
          ),
        ],
      ),
    );
  }
}

/// The severity filter on its own row (plan §7m.1): outlined 30 px chips
/// with words, a chip at 0 dimmed in place.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.counts,
    required this.onFilter,
  });

  static const double height = 40;

  final AlertSeverity? filter;
  final AlertCounts counts;
  final ValueChanged<AlertSeverity?> onFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    Widget chip({
      required String key,
      required String label,
      required int count,
      required bool selected,
      required VoidCallback onTap,
      AlertSeverity? severity,
    }) {
      final fg = selected ? cs.onPrimaryContainer : t.secondary;
      return Semantics(
        label: label,
        selected: selected,
        button: true,
        container: true,
        excludeSemantics: true,
        child: BarChip(
          key: ValueKey('alerts-filter-$key'),
          height: 30,
          padding: 11,
          selected: selected,
          onPressed: count == 0 ? null : onTap,
          children: [
            if (severity != null)
              Icon(
                AlertPalette.iconData(severity),
                size: 14,
                color: SeverityPill.colorOf(
                  context,
                  SeverityPillKind.of(severity),
                ),
              ),
            Text(
              label,
              style: t.description.copyWith(
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            Text(
              '$count',
              style: t.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: selected ? cs.onPrimaryContainer : t.tertiary,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          spacing: 6,
          children: [
            chip(
              key: 'all',
              label: 'All',
              count: counts.critical + counts.warning + counts.recovered,
              selected: filter == null,
              onTap: () => onFilter(null),
            ),
            chip(
              key: 'critical',
              label: 'Critical',
              severity: AlertSeverity.critical,
              count: counts.critical,
              selected: filter == AlertSeverity.critical,
              onTap: () => onFilter(AlertSeverity.critical),
            ),
            chip(
              key: 'warning',
              label: 'Warning',
              severity: AlertSeverity.warning,
              count: counts.warning,
              selected: filter == AlertSeverity.warning,
              onTap: () => onFilter(AlertSeverity.warning),
            ),
          ],
        ),
      ),
    );
  }
}

/// A projector's or an alert's group (plan §7m.3): one 36 px line, the same
/// folded and unfolded.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.node,
    required this.byAlert,
    required this.open,
    required this.now,
    required this.onToggle,
    required this.onAcknowledge,
  });

  static const double height = 36;

  final AlertGroup group;

  /// The group's projector when grouped by projector (null if removed).
  final ProjectorNode? node;
  final bool byAlert;
  final bool open;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final alerts = group.alerts;
    final first = alerts.first;

    final List<Widget> title;
    if (byAlert) {
      final projectors = {for (final a in alerts) a.nodeId}.length;
      final earliest = alerts
          .map((a) => a.since)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      // Sorted problems first: the first one being over means all are.
      final over = first.recovered ? ', over' : '';
      title = [
        Icon(
          AlertPalette.iconOf(first),
          size: 16,
          color: AlertPalette.colorOf(context, first),
        ),
        // The rule's name keeps its words (they're short); the count gives
        // way first, so pills no longer cut it to *Intake temperat...*.
        Text(
          first.rule.label,
          maxLines: 1,
          style: t.body.copyWith(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: CustomTooltip(
            message: 'Earliest start ${formatAlertStart(earliest, now)}',
            child: Text(
              '$projectors ${projectors == 1 ? 'projector' : 'projectors'}'
              '$over',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description,
            ),
          ),
        ),
      ];
    } else {
      final node = this.node;
      title = [
        if (node == null)
          Text('Removed projector', style: t.description)
        else ...[
          Text(node.ipAddress, style: t.mono),
          Flexible(
            child: Text(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description,
            ),
          ),
        ],
      ];
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(9),
            // The header's full height, so the hover fill isn't a strip the
            // height of the text.
            child: Container(
              height: height,
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: Row(
                spacing: 8,
                children: [
                  AlertChevron(open: open),
                  Expanded(
                    // On one baseline: the mono IP and the model sat at
                    // different heights when each was centred.
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: title,
                    ),
                  ),
                  AlertCountPills(alerts),
                ],
              ),
            ),
          ),
        ),
        AcknowledgeButton(
          icon: Icons.done_all,
          label: byAlert ? 'Acknowledge alert group' : 'Acknowledge projector',
          onPressed: onAcknowledge,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// One of the project's groups (or Ungrouped) above its projectors or an
/// alert's rows (plan §7m.3): 30 px, the group's colour and its name in
/// sentence case.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.group,
    required this.projectors,
    required this.alerts,
    required this.open,
    required this.onToggle,
    required this.onAcknowledge,
  });

  static const double height = 30;

  /// Null for Ungrouped.
  final ProjectorGroup? group;
  final int projectors;
  final List<ActiveAlert> alerts;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final name = group?.name ?? 'Ungrouped';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            // The section's full height for the hover fill.
            child: Container(
              height: height,
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: Row(
                spacing: 8,
                children: [
                  AlertChevron(open: open),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: group == null ? t.tertiary : Color(group!.color),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.label,
                          ),
                        ),
                        Text(
                          '$projectors '
                          '${projectors == 1 ? 'projector' : 'projectors'}',
                          style: t.caption,
                        ),
                      ],
                    ),
                  ),
                  AlertCountPills(alerts),
                ],
              ),
            ),
          ),
        ),
        AcknowledgeButton(
          icon: Icons.done_all,
          label: 'Acknowledge $name',
          onPressed: onAcknowledge,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
