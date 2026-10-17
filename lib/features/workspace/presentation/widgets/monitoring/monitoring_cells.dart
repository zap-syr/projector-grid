import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/alert_rule.dart';
import '../../../domain/monitoring_format.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/projector_errors.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/projector_node.dart';
import '../../../domain/test_patterns.dart';
import '../common/status_pill.dart';
import '../custom_tooltip.dart';
import '../monitoring_errors_cell.dart';
import '../remote_preview_dialog.dart';
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
    'shutter' => ShutterState(shutter: n.shutterStatus),
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
    'errors' => ProblemBadge(problems: d.status.problems),
    'connection' => ConnectionStatusBadge(status: n.connectionStatus),
    'model' => TruncatedText(n.name),
    'serial' => TruncatedText(n.serialNumber),
    'ip' => TruncatedText(n.ipAddress, style: t.mono),
    'input' => TruncatedText(n.input),
    'signal' => FitPill(child: SignalPill(node: n)),
    'testPattern' => _TestPatternCell(node: n),
    'runtime' => TruncatedText(withUnit(n.runtime)),
    'lightRuntime' => TruncatedText(withUnit(n.lightRuntime)),
    'intake' => TruncatedText(
      withUnit(n.intakeTemp),
      style: t.body.copyWith(color: temperatureColor(context, d.status.intake)),
    ),
    'exhaust' => TruncatedText(
      withUnit(n.exhaustTemp),
      style: t.body.copyWith(
        color: temperatureColor(context, d.status.exhaust),
      ),
    ),
    'errorCodes' =>
      decodeProjectorErrors(n.errors).isEmpty
          ? Text('None', style: t.body.copyWith(color: t.tertiary))
          : MonitoringErrorsCell(node: n),
    'preview' => CustomTooltip(
      message: 'Remote Preview',
      child: IconButton(
        icon: const Icon(Icons.cast, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () =>
            showRemotePreviewDialog(context, [n], groups: d.groups),
      ),
    ),
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
    'errors' => [d.status.problems.firstOrNull?.badge ?? 'None'],
    'connection' => ['Wrong login'],
    'model' => [n.name],
    'serial' => [n.serialNumber],
    'ip' => [n.ipAddress],
    'input' => [n.input],
    'signal' => [n.signal],
    'testPattern' => [
      n.testPattern == null ? '-' : testPatternLabel(n.testPattern!),
    ],
    'runtime' => [withUnit(n.runtime)],
    'lightRuntime' => [withUnit(n.lightRuntime)],
    'intake' => [withUnit(n.intakeTemp)],
    'exhaust' => [withUnit(n.exhaustTemp)],
    'errorCodes' => [n.errors],
    _ => const [],
  };
}

/// Room auto-fit adds for a cell's icons, dots and pill padding.
double monitoringCellIconPad(String id) => switch (id) {
  'projector' => 16,
  'group' => 18,
  'power' || 'shutter' => 22,
  'inputSignal' || 'signal' => 36,
  'temperature' => 60,
  'errors' => 60,
  'connection' => 40,
  'testPattern' => 24,
  'preview' => 32,
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

/// The pattern's name with the same thumbnail as the control bar; Off and
/// not yet polled show the text alone.
class _TestPatternCell extends StatelessWidget {
  const _TestPatternCell({required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context) {
    final code = node.testPattern;
    final label = code == null ? '-' : testPatternLabel(code);
    if (!isTestPatternActive(code)) return TruncatedText(label);
    final cs = Theme.of(context).colorScheme;
    final icon = kTestPatternIcons[code];
    return Row(
      children: [
        Container(
          width: 18,
          height: 12,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
          child: icon != null
              ? SvgPicture.asset(icon, fit: BoxFit.cover)
              : Icon(Icons.grid_on, size: 10, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(child: TruncatedText(label)),
      ],
    );
  }
}
