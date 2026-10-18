import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/alert_rule.dart';
import '../../../domain/monitoring_format.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/projector_node.dart';
import '../../../domain/test_patterns.dart';
import '../common/status_pill.dart';
import 'monitoring_parts.dart';

/// What a table cell needs besides its column: the projector, how
/// Monitoring reads it, the groups and the temperature thresholds.
typedef MonitoringCellData = ({
  ProjectorNode node,
  MonitoringStatus status,
  Map<String, ProjectorGroup> groups,
  AlertSettings alerts,
});

/// The cell of column [id] for one row.
Widget monitoringCell(BuildContext context, String id, MonitoringCellData d) {
  final t = AppText.of(context);
  final n = d.node;
  return switch (id) {
    'projector' => _ProjectorCell(node: n),
    'group' => _GroupCell(group: d.groups[n.groupId]),
    'power' => PowerState(power: n.powerStatus),
    'shutter' => ShutterState(node: n),
    'inputSignal' => _TwoLines(
      first: TruncatedText(n.input),
      second: FitPill(child: SignalPill(node: n)),
    ),
    'temperature' => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        TemperatureLine(
          label: 'In',
          display: n.intakeTemp,
          threshold: d.alerts.intake,
          severity: d.status.intake,
        ),
        TemperatureLine(
          label: 'Ex',
          display: n.exhaustTemp,
          threshold: d.alerts.exhaust,
          severity: d.status.exhaust,
        ),
      ],
    ),
    'runtimes' => _TwoLines(
      first: TruncatedText(withUnit(n.runtime)),
      second: TruncatedText(
        'Light ${withUnit(n.lightRuntime)}',
        style: t.description,
      ),
    ),
    'voltage' => TruncatedText(withUnit(n.acVoltage)),
    // An offline projector's codes are the last ones it sent: not None.
    'errors' when d.status.level == ProblemLevel.offline => Text(
      'Unknown',
      style: t.body.copyWith(color: t.tertiary),
    ),
    'errors' => ProblemBadge(problems: projectorErrorsOf(d.status)),
    'connection' => ConnectionStatusBadge(status: n.connectionStatus),
    'serial' => TruncatedText(n.serialNumber),
    'testPattern' => TestPatternName(node: n),
    _ => const SizedBox.shrink(),
  };
}

/// The plain text of a cell, line by line, which auto-fit measures; the
/// extra width of its icons or pill padding is [monitoringCellIconPad].
List<String> monitoringCellTexts(String id, MonitoringCellData d) {
  final n = d.node;
  return switch (id) {
    'projector' => [n.ipAddress, '${n.name}, last seen 00:00'],
    'group' => [d.groups[n.groupId]?.name ?? 'None'],
    'power' => [powerLabel(n.powerStatus)],
    'shutter' => [shutterLabel(n.shutterStatus)],
    'inputSignal' => [n.input, n.signal],
    'temperature' => ['Ex 100 °C'],
    'runtimes' => [withUnit(n.runtime), 'Light ${withUnit(n.lightRuntime)}'],
    'voltage' => [withUnit(n.acVoltage)],
    'errors' => [projectorErrorsOf(d.status).firstOrNull?.badge ?? 'Unknown'],
    'connection' => ['Wrong login'],
    'serial' => [n.serialNumber],
    'testPattern' => [
      n.testPattern == null ? '-' : testPatternLabel(n.testPattern!),
    ],
    _ => const [],
  };
}

/// Room auto-fit adds for a cell's icons, dots and pill padding.
double monitoringCellIconPad(String id) => switch (id) {
  'projector' => 16,
  'group' => 18,
  'power' || 'shutter' => 22,
  'inputSignal' => 36,
  'temperature' => 60,
  'errors' => 60,
  'connection' => 40,
  'testPattern' => 26,
  _ => 0,
};

class _TwoLines extends StatelessWidget {
  const _TwoLines({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 3,
    children: [first, second],
  );
}

/// Status dot and IP; the model under it, with `last seen 16:41` while
/// offline.
class _ProjectorCell extends StatelessWidget {
  const _ProjectorCell({required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final seen = lastSeenLabel(node, DateTime.now());
    return _TwoLines(
      first: Row(
        children: [
          MonitoringStatusDot(status: node.connectionStatus),
          const SizedBox(width: 8),
          Expanded(
            child: TruncatedText(
              node.ipAddress,
              style: t.mono.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      second: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: TruncatedText(
          seen == null ? node.name : '${node.name}, $seen',
          style: t.description,
        ),
      ),
    );
  }
}

class _GroupCell extends StatelessWidget {
  const _GroupCell({required this.group});

  final ProjectorGroup? group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final t = AppText.of(context);
    if (g == null) {
      return Text('None', style: t.body.copyWith(color: t.tertiary));
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(g.color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: TruncatedText(g.name)),
      ],
    );
  }
}
