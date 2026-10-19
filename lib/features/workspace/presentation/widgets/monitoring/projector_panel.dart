import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/status_thresholds.dart';
import '../../../domain/alert_rule.dart';
import '../../../domain/alerts.dart';
import '../../../domain/monitoring_format.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/projector_node.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/monitoring_panel_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';
import '../custom_tooltip.dart';
import 'monitoring_actions.dart';
import 'monitoring_parts.dart';

/// The projector panel's width; it opens over the content, so the table
/// and the cards keep their layout.
const double kProjectorPanelWidth = 380;

/// One projector in detail (§7i.4): the header, what needs attention and
/// since when, Status, Temperature with the threshold mark, Runtime and
/// power, and Preview / Web UI / Locate (find on canvas).
class ProjectorPanel extends ConsumerWidget {
  const ProjectorPanel({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(
      workspaceProvider.select(
        (nodes) => nodes.where((n) => n.id == nodeId).firstOrNull,
      ),
    );
    if (node == null) return const SizedBox.shrink();
    final status = ref.watch(
      monitoringStatusProvider.select(
        (m) => m[nodeId] ?? const MonitoringStatus(),
      ),
    );
    final alerts = ref.watch(appSettingsProvider.select((s) => s.alerts));
    final notifier = ref.read(workspaceProvider.notifier);
    // Through the workspace's state, which a group edit also changes.
    final groupName = ref.watch(
      workspaceProvider.select(
        (_) => notifier.groups.where((g) => g.id == node.groupId).firstOrNull,
      ),
    );
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final surfaces = DialogSurfaces.of(context);
    final now = DateTime.now();

    return Material(
      color: surfaces.body,
      elevation: 12,
      shadowColor: Colors.black,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: MonitoringStatusDot(status: node.connectionStatus),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          node.ipAddress,
                          style: t.cardTitle.merge(AppTheme.monoStyle),
                        ),
                        Text(
                          node.serialNumber == '-'
                              ? node.name
                              : '${node.name}, serial ${node.serialNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.description,
                        ),
                        if (groupName != null)
                          GroupPill(
                            name: groupName.name,
                            color: Color(groupName.color),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: null,
                    icon: Icon(Icons.close, size: 20, color: t.secondary),
                    onPressed: () =>
                        ref.read(monitoringPanelProvider.notifier).close(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: DialogScrollBody(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    if (status.problems.isNotEmpty)
                      _AttentionSection(node: node, status: status, now: now),
                    _Section(
                      title: 'Status',
                      children: [
                        _Row('Power', PowerState(power: node.powerStatus)),
                        _Row('Shutter', ShutterState(node: node)),
                        _Row.text(context, 'Input', node.input),
                        _Row('Signal', FitPill(child: SignalPill(node: node))),
                        _Row(
                          'Test pattern',
                          TestPatternName(
                            node: node,
                            style: t.body.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Temperature',
                      children: [
                        _Gauge(
                          label: 'Intake',
                          display: node.intakeTemp,
                          threshold: alerts.intake,
                          severity: status.intake,
                        ),
                        _Gauge(
                          label: 'Exhaust',
                          display: node.exhaustTemp,
                          threshold: alerts.exhaust,
                          severity: status.exhaust,
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Runtime and power',
                      children: [
                        _Row.text(context, 'Projector', withUnit(node.runtime)),
                        _Row.text(
                          context,
                          'Light source',
                          withUnit(node.lightRuntime),
                        ),
                        // No Errors row: the codes are in the section above.
                        _Row.text(
                          context,
                          'AC voltage',
                          withUnit(node.acVoltage),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                spacing: 6,
                children: [
                  _Action(
                    icon: Icons.monitor_outlined,
                    label: 'Preview',
                    onPressed: () => openMonitoringPreview(context, ref, node),
                  ),
                  _Action(
                    icon: Icons.open_in_browser,
                    label: 'Web UI',
                    onPressed: () => openProjectorWebUi(node),
                  ),
                  // Short, so the three labels fit the 380 px panel.
                  _Action(
                    icon: Icons.my_location,
                    label: 'Locate',
                    tooltip: 'Find on canvas',
                    onPressed: () => findOnCanvas(
                      ProviderScope.containerOf(context, listen: false),
                      node.id,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tonal (owner, 2026-10-17); the label stays on one line and the three
/// share the row by their own widths.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.tonalIcon(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Flexible(
      child: tooltip == null
          ? button
          : CustomTooltip(message: tooltip!, child: button),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.color,
    this.borderColor,
  });

  final String title;
  final List<Widget> children;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return DialogCard(
      borderColor: borderColor,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.label.copyWith(color: color)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  _Row.text(BuildContext context, this.label, String text, {Color? color})
    : value = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.of(context).body.copyWith(
          fontWeight: FontWeight.w500,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: Row(
      children: [
        Text(label, style: AppText.of(context).description),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    ),
  );
}

/// Needs attention (warnings) or Error: each problem with its value, then
/// since when the worst one has been going on; offline, when it was last
/// seen.
class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.node,
    required this.status,
    required this.now,
  });

  final ProjectorNode node;
  final MonitoringStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final color = problemColor(context, status.level)!;
    // Not "Error": a hot reading or a lost signal is an alert, not a fault
    // of the projector. Each row says what it is.
    final title = switch (status.level) {
      ProblemLevel.error => 'Alert',
      ProblemLevel.offline => 'Offline',
      _ => 'Needs attention',
    };
    final since = status.problems.first.since;
    final lastSeen = node.lastSeen;
    return _Section(
      title: title,
      color: status.level == ProblemLevel.offline ? null : color,
      borderColor: color.withValues(alpha: 0.6),
      children: [
        for (final p in status.problems)
          _Row.text(
            context,
            p.title,
            p.value,
            color: problemColor(context, p.level),
          ),
        if (since != null)
          _Row.text(context, 'Since', formatAlertStart(since, now)),
        if (status.level == ProblemLevel.offline && lastSeen != null)
          _Row.text(context, 'Last seen', formatAlertStart(lastSeen, now)),
      ],
    );
  }
}

/// A temperature with its bar and a tick at the warning threshold.
class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.display,
    required this.threshold,
    required this.severity,
  });

  final String label;
  final String display;
  final TempThreshold threshold;
  final AlertSeverity? severity;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            children: [
              Text(label, style: t.description),
              const Spacer(),
              Text(
                withUnit(display),
                style: t.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: temperatureColor(context, severity),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          TemperatureBar(
            key: ValueKey('gauge-$label'),
            fraction: temperatureFraction(display, threshold),
            severity: severity,
            height: 6,
            mark: thresholdFraction(threshold),
          ),
        ],
      ),
    );
  }
}
