import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Every active alert in the project, opened from the status bar: grouped by
/// projector (optionally inside the project's groups) or by rule,
/// filterable by severity, acknowledged ones folded at the bottom. It only
/// holds conditions true right now, so it stays bounded; history is in the
/// event log.
class ActiveAlertsPanel extends ConsumerStatefulWidget {
  const ActiveAlertsPanel({super.key});

  static const double width = 404;

  /// Less when the window is shorter: the list takes what the panel's
  /// constraints leave.
  static const double maxListHeight = 520;

  /// Groups start folded past this many.
  static const int foldAbove = 4;

  @override
  ConsumerState<ActiveAlertsPanel> createState() => _ActiveAlertsPanelState();
}

class _ActiveAlertsPanelState extends ConsumerState<ActiveAlertsPanel> {
  /// Indent of the projector groups inside a project-group section.
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
    final theme = Theme.of(context);
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
    final canSection = byProjector && projectGroups.isNotEmpty;
    final sectioned = canSection && settings.byProjectGroups;

    // A severity filter is for what is still wrong; recovered ones show
    // under All only.
    bool passes(ActiveAlert a) =>
        _filter == null || (a.severity == _filter && !a.recovered);
    final unacked = [
      for (final a in alerts)
        if (!a.acknowledged) a,
    ];
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
    final allOpen = groups.isNotEmpty && groups.every(isOpen);
    final ackedOpen = _ackedOpen ?? acked.length <= 3;

    String nameOf(String nodeId) => nodes[nodeId]?.name ?? 'Removed projector';

    void acknowledgeGroups(Iterable<AlertGroup> gs) {
      final keys = {
        for (final g in gs)
          for (final a in g.alerts) a.key,
      };
      notifier.acknowledgeWhere((a) => keys.contains(a.key));
    }

    List<AlertScrollEntry> groupEntries(AlertGroup g, double indent) {
      Widget indented(Widget child) => indent == 0
          ? child
          : Padding(
              padding: EdgeInsets.only(left: indent),
              child: child,
            );
      final open = isOpen(g);
      return [
        (
          child: indented(
            _GroupHeader(
              group: g,
              node: byProjector ? nodes[g.key] : null,
              byRule: !byProjector,
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
          for (final a in g.alerts)
            (
              child: indented(
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: AlertRow(
                    alert: a,
                    now: now,
                    title: byProjector ? null : nameOf(a.nodeId),
                    titleNote: byProjector ? null : nodes[a.nodeId]?.ipAddress,
                    onAcknowledge: () => notifier.acknowledge(a.key),
                  ),
                ),
              ),
              height: AlertRow.height,
              counts: true,
            ),
      ];
    }

    final entries = <AlertScrollEntry>[
      if (sectioned)
        for (final s in sectionByProjectGroup(
          groups,
          (id) => nodes[id]?.groupId,
          [for (final g in projectGroups) g.id],
        )) ...[
          (
            child: _SectionHeader(
              group: projectGroups.where((g) => g.id == s.groupId).firstOrNull,
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
              prefix: nameOf(a.nodeId),
            ),
            height: AcknowledgedAlertLine.height,
            counts: true,
          ),
    ];

    return AlertPanelSurface(
      width: ActiveAlertsPanel.width,
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
                    title: 'Active alerts',
                    note: alerts.isEmpty ? null : '${alerts.length} total',
                  ),
                ),
                if (groups.length > 1)
                  AlertPanelIconButton(
                    icon: allOpen ? Icons.unfold_less : Icons.unfold_more,
                    label: allOpen ? 'Fold all' : 'Unfold all',
                    onPressed: () => setState(() {
                      for (final g in groups) {
                        _open[openKey(g.key)] = !allOpen;
                      }
                    }),
                  ),
                if (unacked.isNotEmpty)
                  AlertPanelIconButton(
                    icon: Icons.done_all,
                    label: 'Acknowledge all',
                    onPressed: notifier.acknowledgeAll,
                  ),
                AlertPanelIconButton(
                  icon: Icons.receipt_long,
                  label: 'Open event log',
                  onPressed: () => ref
                      .read(eventLogRequestProvider.notifier)
                      .show(alertsOnly: true),
                ),
              ],
            ),
          ),
          if (alerts.isEmpty)
            const _EmptyState(
              icon: Icons.check_circle,
              title: 'No active alerts',
              text:
                  'Everything is within limits. Past alerts are in the '
                  'event log.',
            )
          else ...[
            _Toolbar(
              filter: _filter,
              counts: counts,
              grouping: grouping,
              byProjectGroups: canSection ? settings.byProjectGroups : null,
              onFilter: (f) => setState(() => _filter = f),
              onGrouping: (g) =>
                  _saveAlertSettings((s) => s.copyWith(grouping: g)),
              onByProjectGroups: (on) =>
                  _saveAlertSettings((s) => s.copyWith(byProjectGroups: on)),
            ),
            if (unacked.isEmpty)
              const _EmptyState(
                icon: Icons.done_all,
                title: 'All acknowledged',
                text:
                    'These alerts are still active; they leave the list when '
                    'the condition clears.',
              ),
            if (entries.isNotEmpty)
              Flexible(
                child: AlertScrollArea(
                  entries: entries,
                  maxHeight: ActiveAlertsPanel.maxListHeight,
                ),
              ),
            if (entries.isEmpty && unacked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nothing at this severity',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A projector's or a rule's group: one line, the same folded and unfolded.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.node,
    required this.byRule,
    required this.open,
    required this.now,
    required this.onToggle,
    required this.onAcknowledge,
  });

  static const double height = 34;

  final AlertGroup group;

  /// The group's projector when grouped by projector (null if removed).
  final ProjectorNode? node;
  final bool byRule;
  final bool open;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = group.alerts;
    final counts = countAlerts(alerts);
    final top = alerts.first.severity;
    // Sorted problems first: the first one being over means all are.
    final allBack = alerts.first.recovered;
    final topColor = allBack
        ? AlertPalette.recoveredIcon
        : AlertPalette.icon(top);

    final String title;
    final String? note;
    if (byRule) {
      final projectors = {for (final a in alerts) a.nodeId}.length;
      final earliest = alerts
          .map((a) => a.since)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      title = alerts.first.rule.label;
      note =
          '$projectors ${projectors == 1 ? 'projector' : 'projectors'}, '
          'since ${formatAlertStart(earliest, now)}';
    } else {
      title = node?.name ?? 'Removed projector';
      note = node?.ipAddress;
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                spacing: 8,
                children: [
                  _Chevron(open: open),
                  if (byRule)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: topColor.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        allBack
                            ? Icons.check_circle
                            : AlertPalette.iconData(top),
                        size: 14,
                        color: topColor,
                      ),
                    ),
                  Expanded(
                    child: AlertPanelTitle(title: title, note: note),
                  ),
                  if (byRule)
                    Text(
                      '${alerts.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: allBack
                            ? AlertPalette.of(context).recovered
                            : AlertPalette.of(context).text(top),
                      ),
                    )
                  else ...[
                    if (counts.critical > 0)
                      AlertSeverityCount(
                        AlertSeverity.critical,
                        counts.critical,
                      ),
                    if (counts.warning > 0)
                      AlertSeverityCount(AlertSeverity.warning, counts.warning),
                    if (counts.recovered > 0)
                      AlertRecoveredCount(counts.recovered),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AcknowledgeButton(
            icon: Icons.done_all,
            label: byRule ? 'Acknowledge alert group' : 'Acknowledge projector',
            onPressed: onAcknowledge,
          ),
        ),
      ],
    );
  }
}

/// One of the project's groups (or Ungrouped) above its projectors.
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = countAlerts(alerts);
    final name = group?.name ?? 'Ungrouped';
    final muted = colors.onSurfaceVariant.withValues(alpha: 0.75);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                spacing: 8,
                children: [
                  _Chevron(open: open),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: group == null ? muted : Color(group!.color),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: name.toUpperCase()),
                          TextSpan(
                            text:
                                '   $projectors '
                                '${projectors == 1 ? 'projector' : 'projectors'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (counts.critical > 0)
                    AlertSeverityCount(AlertSeverity.critical, counts.critical),
                  if (counts.warning > 0)
                    AlertSeverityCount(AlertSeverity.warning, counts.warning),
                  if (counts.recovered > 0)
                    AlertRecoveredCount(counts.recovered),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AcknowledgeButton(
            icon: Icons.done_all,
            label: 'Acknowledge $name',
            onPressed: onAcknowledge,
          ),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.25 : 0,
    duration: const Duration(milliseconds: 120),
    child: Icon(
      Icons.chevron_right,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant
          .withValues(alpha: 0.75),
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.counts,
    required this.grouping,
    required this.byProjectGroups,
    required this.onFilter,
    required this.onGrouping,
    required this.onByProjectGroups,
  });

  final AlertSeverity? filter;
  final AlertCounts counts;
  final AlertGrouping grouping;

  /// The project-groups toggle's state; null hides it (rule grouping, or a
  /// project without groups).
  final bool? byProjectGroups;
  final ValueChanged<AlertSeverity?> onFilter;
  final ValueChanged<AlertGrouping> onGrouping;
  final ValueChanged<bool> onByProjectGroups;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 2, 4),
    // Wraps rather than overflows if the chips' counts grow wide.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            _Chip(
              label: 'All',
              count: counts.critical + counts.warning + counts.recovered,
              selected: filter == null,
              onTap: () => onFilter(null),
            ),
            for (final s in [AlertSeverity.critical, AlertSeverity.warning])
              _Chip(
                severity: s,
                count: s == AlertSeverity.critical
                    ? counts.critical
                    : counts.warning,
                selected: filter == s,
                onTap: () => onFilter(s),
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (byProjectGroups case final on?)
              _ProjectGroupsToggle(
                on: on,
                onChanged: () => onByProjectGroups(!on),
              ),
            _GroupingToggle(value: grouping, onChanged: onGrouping),
          ],
        ),
      ],
    ),
  );
}

/// An icon button that reads as pressed while the projectors are sorted
/// into the project's groups.
class _ProjectGroupsToggle extends StatelessWidget {
  const _ProjectGroupsToggle({required this.on, required this.onChanged});

  final bool on;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // No Tooltip, like the other alert-panel buttons; the semantics label
    // carries the name.
    return Semantics(
      button: true,
      toggled: on,
      label: 'Sort into project groups',
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: on ? colors.secondaryContainer : null,
            border: on ? null : Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.workspaces_outlined,
            size: 15,
            color: on ? colors.onSecondaryContainer : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A 24px filter chip; the M3 chips are too tall for this toolbar.
class _Chip extends StatelessWidget {
  const _Chip({
    this.label,
    this.severity,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String? label;
  final AlertSeverity? severity;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall;
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? severity?.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : null,
            border: selected ? null : Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              if (severity case final s?)
                Icon(
                  AlertPalette.iconData(s),
                  size: 13,
                  color: AlertPalette.icon(s),
                ),
              if (label case final l?)
                Text(
                  l,
                  style: style?.copyWith(
                    color: selected ? colors.onSecondaryContainer : null,
                  ),
                ),
              Text(
                '$count',
                style: style?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: selected
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({required this.value, required this.onChanged});

  final AlertGrouping value;
  final ValueChanged<AlertGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget segment(AlertGrouping g, IconData icon, String label) {
      final selected = g == value;
      return Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => onChanged(g),
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: selected ? colors.secondaryContainer : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? colors.onSecondaryContainer : null,
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: selected ? colors.onSecondaryContainer : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            AlertGrouping.projector,
            Icons.videocam_outlined,
            'Projector',
          ),
          Container(width: 1, height: 22, color: colors.outlineVariant),
          segment(AlertGrouping.alert, Icons.category_outlined, 'Alert'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
      child: Column(
        spacing: 6,
        children: [
          Icon(icon, size: 30, color: Colors.green),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
