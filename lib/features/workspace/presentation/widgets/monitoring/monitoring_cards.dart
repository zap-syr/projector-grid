import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/monitoring_format.dart';
import '../../../domain/monitoring_layout.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/monitoring_view_settings.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/projector_node.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/monitoring_panel_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';
import 'monitoring_group_header.dart';
import 'monitoring_layout_watch.dart';
import 'monitoring_parts.dart';

/// Extended cards keep one height so a row of cards never jumps when a
/// problem badge comes or goes.
const double kExtendedCardHeight = 288;
const double _kExtendedCardMinWidth = 260;
const Size kCompactTileSize = Size(176, 96);
const double _kGap = 12;

/// The Cards view (§7i.3): Extended cards or Compact tiles, grouped like the
/// table. A click opens the projector panel.
class MonitoringCards extends ConsumerStatefulWidget {
  const MonitoringCards({super.key});

  @override
  ConsumerState<MonitoringCards> createState() => _MonitoringCardsState();
}

class _MonitoringCardsState extends ConsumerState<MonitoringCards> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = watchMonitoringLayout(ref);
    final density = ref.watch(
      monitoringViewProvider.select((s) => s.cardDensity),
    );
    final collapsed = ref.watch(
      monitoringViewProvider.select((s) => s.collapsed),
    );
    final groups = layout.groupsById;
    final compact = density == MonitoringCardDensity.compact;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - 32;
        final perRow = ((inner + _kGap) / (_kExtendedCardMinWidth + _kGap))
            .floor()
            .clamp(1, 99);

        Widget body(MonitoringSection s) => compact
            ? SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in s.nodeIds)
                      _CompactTile(key: ValueKey(id), nodeId: id),
                  ],
                ),
              )
            : SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: perRow,
                  mainAxisExtent: kExtendedCardHeight,
                  crossAxisSpacing: _kGap,
                  mainAxisSpacing: _kGap,
                ),
                delegate: SliverChildListDelegate([
                  for (final id in s.nodeIds)
                    _ExtendedCard(
                      key: ValueKey(id),
                      nodeId: id,
                      groups: groups,
                    ),
                ]),
              );

        return Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              for (final s in layout.sections) ...[
                if (!s.flat)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(
                        height: 36,
                        child: MonitoringGroupHeader(
                          section: s,
                          collapsed: collapsed.contains(s.key),
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                if (s.flat || !collapsed.contains(s.key))
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, s.flat ? 16 : 4, 16, 12),
                    sliver: body(s),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The node, its status and whether its panel is open, each through a
/// `select`, so a poll rebuilds only the cards it changed.
({ProjectorNode? node, MonitoringStatus status, bool selected}) _watchCard(
  WidgetRef ref,
  String id,
) => (
  node: ref.watch(
    workspaceProvider.select(
      (nodes) => nodes.where((n) => n.id == id).firstOrNull,
    ),
  ),
  status: ref.watch(
    monitoringStatusProvider.select((m) => m[id] ?? const MonitoringStatus()),
  ),
  selected: ref.watch(monitoringPanelProvider.select((p) => p == id)),
);

void _togglePanel(WidgetRef ref, String id, bool selected) {
  final panel = ref.read(monitoringPanelProvider.notifier);
  selected ? panel.close() : panel.open(id);
}

class _ExtendedCard extends ConsumerWidget {
  const _ExtendedCard({super.key, required this.nodeId, required this.groups});

  final String nodeId;
  final Map<String, ProjectorGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:node, :status, :selected) = _watchCard(ref, nodeId);
    if (node == null) return const SizedBox.shrink();
    final alerts = ref.watch(appSettingsProvider.select((s) => s.alerts));
    final t = AppText.of(context);
    final group = groups[node.groupId];
    final level = status.level;
    final border = switch (level) {
      ProblemLevel.warning || ProblemLevel.error => problemColor(
        context,
        level,
      )!.withValues(alpha: 0.6),
      _ => null,
    };

    final card = DialogCard(
      highlighted: selected,
      borderColor: border,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MonitoringStatusDot(status: node.connectionStatus),
              const SizedBox(width: 8),
              Expanded(
                child: TruncatedText(
                  node.ipAddress,
                  style: t.mono.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (group != null)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Color(group.color),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TruncatedText(switch (lastSeenLabel(node, DateTime.now())) {
              final seen? => '${node.name}, $seen',
              null => node.name,
            }, style: t.description),
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 6,
            children: [
              StateChip(child: PowerState(power: node.powerStatus)),
              StateChip(child: ShutterState(shutter: node.shutterStatus)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: DialogSurfaces.of(context).editor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Text('Input', style: t.caption),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TruncatedText(node.input, style: t.cardTitle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 3,
                  child: FitPill(child: SignalPill(node: node)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: status.problems.isEmpty
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: ProblemBadge(problems: status.problems),
                  ),
          ),
          const Spacer(),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _Metric(
                  label: 'Intake',
                  value: withUnit(node.intakeTemp),
                  color: temperatureColor(context, status.intake),
                  bar: TemperatureBar(
                    fraction: temperatureFraction(
                      node.intakeTemp,
                      alerts.intake,
                    ),
                    severity: status.intake,
                  ),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Exhaust',
                  value: withUnit(node.exhaustTemp),
                  color: temperatureColor(context, status.exhaust),
                  bar: TemperatureBar(
                    fraction: temperatureFraction(
                      node.exhaustTemp,
                      alerts.exhaust,
                    ),
                    severity: status.exhaust,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _Metric(label: 'Runtime', value: withUnit(node.runtime)),
              ),
              Expanded(
                child: _Metric(
                  label: 'Light',
                  value: withUnit(node.lightRuntime),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _togglePanel(ref, nodeId, selected),
        child: Opacity(
          opacity: level == ProblemLevel.offline ? 0.62 : 1,
          child: card,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.color,
    this.bar,
  });

  final String label;
  final String value;
  final Color? color;
  final Widget? bar;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label, style: t.caption),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        ?bar,
      ],
    );
  }
}

/// A 176×96 tile for big rigs: the full IP, the power icon, the input and
/// the signal. Warnings tint it amber with the reason in the corner, errors
/// red with the code; offline tiles are dashed.
class _CompactTile extends ConsumerWidget {
  const _CompactTile({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:node, :status, :selected) = _watchCard(ref, nodeId);
    if (node == null) return const SizedBox.shrink();
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final level = status.level;
    final offline = level == ProblemLevel.offline;
    final tone = switch (level) {
      ProblemLevel.warning ||
      ProblemLevel.error => problemColor(context, level),
      _ => null,
    };
    final power = switch (node.powerStatus) {
      PowerStatus.on => AppStatusColors.of(context).success,
      PowerStatus.turningOn ||
      PowerStatus.cooling => AppStatusColors.of(context).warning,
      PowerStatus.standby => t.secondary,
    };
    final radius = BorderRadius.circular(12);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.ipAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.mono.copyWith(
                    fontWeight: FontWeight.w600,
                    color: offline ? t.tertiary : null,
                  ),
                ),
              ),
              if (tone != null) ...[
                Text(
                  status.problems.first.flag,
                  style: t.caption.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (!offline)
                Icon(Icons.power_settings_new, size: 14, color: power),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node.input,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.description.copyWith(
              fontWeight: FontWeight.w600,
              color: offline ? t.tertiary : null,
            ),
          ),
          const Spacer(),
          FitPill(
            child: offline
                ? StatusPill(label: 'Offline', color: t.tertiary, dot: true)
                : SignalPill(node: node),
          ),
        ],
      ),
    );

    final Widget tile = offline
        ? DashedBorder(
            radius: 12,
            color: cs.outline,
            child: SizedBox.fromSize(size: kCompactTileSize, child: content),
          )
        : Container(
            width: kCompactTileSize.width,
            height: kCompactTileSize.height,
            decoration: BoxDecoration(
              color: tone == null
                  ? DialogSurfaces.of(context).card
                  : Color.alphaBlend(
                      tone.withValues(alpha: 0.10),
                      DialogSurfaces.of(context).card,
                    ),
              borderRadius: radius,
              border: Border.all(
                color: tone?.withValues(alpha: 0.65) ?? cs.outlineVariant,
              ),
            ),
            child: content,
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _togglePanel(ref, nodeId, selected),
        child: Container(
          key: const ValueKey('compact-tile'),
          foregroundDecoration: selected
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: cs.primary, width: 2),
                )
              : null,
          child: tile,
        ),
      ),
    );
  }
}
