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
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_panel_provider.dart';
import '../../providers/monitoring_reveal_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';
import '../projector_status_style.dart';
import 'monitoring_actions.dart';
import 'monitoring_data_table.dart';
import 'monitoring_group_header.dart';
import 'monitoring_layout_watch.dart';
import 'monitoring_no_matches.dart';
import 'monitoring_parts.dart';

/// Extended cards keep one height so a row of cards never jumps when a
/// problem badge comes or goes.
const double kExtendedCardHeight = 302;
const double _kExtendedCardMinWidth = 260;
const Size kCompactTileSize = Size(176, 96);
const double _kGap = 12;

/// The cards sit on the window, which in dark mode is the dialog body's
/// tone, so they take one step more than a dialog card to lift off it, and
/// the input block inside one step more again.
({Color card, Color inset}) _cardSurfaces(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final surfaces = DialogSurfaces.of(context);
  return cs.brightness == Brightness.light
      ? (card: surfaces.card, inset: surfaces.editor)
      : (card: cs.surfaceContainerHigh, inset: cs.surfaceContainerHighest);
}

/// The Cards view (§7i.3): Extended cards or Compact tiles, grouped like the
/// table. A click opens the projector panel.
class MonitoringCards extends ConsumerStatefulWidget {
  const MonitoringCards({super.key});

  @override
  ConsumerState<MonitoringCards> createState() => _MonitoringCardsState();
}

class _MonitoringCardsState extends ConsumerState<MonitoringCards> {
  final _scroll = ScrollController();

  // The last build's sections and sizes, for scrolling a projector into
  // view (*Show in Monitoring*).
  MonitoringLayout? _layout;
  Set<String> _collapsed = const {};
  bool _compact = false;
  double _groupHeight = 0;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    // A request made before this view was built (the mode switched to
    // Cards with it pending).
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the requested projector's card to the middle, then clears the
  /// request. Every card in a section has one size, so its place follows
  /// from its index, the cards per row and the paddings of the build.
  void _reveal() {
    if (!mounted) return;
    final id = ref.read(monitoringRevealProvider);
    final layout = _layout;
    if (id == null || layout == null) return;
    ref.read(monitoringRevealProvider.notifier).consume();
    final inner = _width - 32;
    final ({double height, double gap, int perRow}) grid = _compact
        ? (
            height: kCompactTileSize.height,
            gap: 8,
            perRow: ((inner + 8) / (kCompactTileSize.width + 8)).floor().clamp(
              1,
              999,
            ),
          )
        : (
            height: kExtendedCardHeight,
            gap: _kGap,
            perRow: _extendedPerRow(_width),
          );
    var top = 0.0;
    for (final s in layout.sections) {
      if (!s.flat) top += _groupHeight;
      if (!s.flat && _collapsed.contains(s.key)) continue;
      top += s.flat ? 16 : 12;
      final index = s.nodeIds.indexOf(id);
      if (index >= 0) {
        top += (index ~/ grid.perRow) * (grid.height + grid.gap);
        centerScrollOn(_scroll, top, grid.height);
        return;
      }
      final rows = (s.nodeIds.length + grid.perRow - 1) ~/ grid.perRow;
      top += rows * (grid.height + grid.gap) - grid.gap + 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    // After the frame, so the cards of an expanded group or a cleared
    // filter are laid out and counted in the scroll range.
    ref.listen(monitoringRevealProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
      }
    });
    final layout = watchMonitoringLayout(ref);
    final density = ref.watch(
      monitoringViewProvider.select((s) => s.cardDensity),
    );
    final collapsed = ref.watch(
      monitoringViewProvider.select((s) => s.collapsed),
    );
    final groupHeight = monitoringGroupRowHeight(
      ref.watch(appSettingsProvider.select((s) => s.monitoringDensity)),
    );
    final filtering = ref.watch(
      monitoringFilterProvider.select((f) => f.active),
    );
    final groups = layout.groupsById;
    final compact = density == MonitoringCardDensity.compact;
    _layout = layout;
    _collapsed = collapsed;
    _compact = compact;
    _groupHeight = groupHeight;
    if (filtering && layout.sections.every((s) => s.nodeIds.isEmpty)) {
      return const MonitoringNoMatches();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final perRow = _extendedPerRow(constraints.maxWidth);

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
                // Edge to edge and filled, like the table's group rows.
                if (!s.flat)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: groupHeight,
                      child: MonitoringGroupHeader(
                        key: ValueKey('group-${s.key}'),
                        section: s,
                        collapsed: collapsed.contains(s.key),
                      ),
                    ),
                  ),
                if (s.flat || !collapsed.contains(s.key))
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, s.flat ? 16 : 12, 16, 16),
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

/// Extended cards per row in a view [width] wide (16 px side padding).
int _extendedPerRow(double width) =>
    ((width - 32 + _kGap) / (_kExtendedCardMinWidth + _kGap)).floor().clamp(
      1,
      99,
    );

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

    final surfaces = _cardSurfaces(context);
    final card = DialogCard(
      color: surfaces.card,
      highlighted: selected,
      borderColor: border,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The group pill's height whether or not there is one, so grouped
          // and ungrouped cards line up.
          SizedBox(
            height: 22,
            child: Row(
              children: [
                MonitoringStatusDot(status: node.connectionStatus),
                const SizedBox(width: 8),
                Expanded(
                  child: TruncatedText(
                    node.ipAddress,
                    style: t.mono.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                // A named pill, not a bare dot: a coloured dot in the corner
                // read as a status needing attention. Capped rather than
                // Flexible, so it sits at the right edge and leaves the IP
                // its room in the narrowest card.
                if (group != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: GroupPill(
                      key: const ValueKey('card-group-pill'),
                      name: group.name,
                      color: Color(group.color),
                    ),
                  ),
                ],
              ],
            ),
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
              StateChip(child: ShutterState(node: node)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: surfaces.inset,
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
          const SizedBox(height: 10),
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
              // AC rather than light hours, which the panel and the table
              // still show: a sagging supply matters more at a glance.
              Expanded(
                child: _Metric(label: 'AC', value: withUnit(node.acVoltage)),
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

/// A 176×96 tile for big rigs: the full IP, the power and shutter icons,
/// the input and the signal. Warnings tint it amber with the reason in the corner, errors
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
    final style = ProjectorStatusStyle.of(context);
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
              // In the table's and the canvas card's colours.
              if (!offline) ...[
                Icon(
                  Icons.power_settings_new,
                  key: const ValueKey('compact-power'),
                  size: 14,
                  color: style.powerColor(node.powerStatus),
                ),
                const SizedBox(width: 4),
                Icon(
                  node.shutterStatus == ShutterStatus.open
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  key: const ValueKey('compact-shutter'),
                  size: 14,
                  color: style.shutterColor(node),
                ),
              ],
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
                  ? _cardSurfaces(context).card
                  : Color.alphaBlend(
                      tone.withValues(alpha: 0.10),
                      _cardSurfaces(context).card,
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
