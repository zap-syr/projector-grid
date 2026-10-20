import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/monitoring_filter.dart';
import '../../../domain/monitoring_table_columns.dart';
import '../../../domain/monitoring_view_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/bar_chip.dart';
import '../common/dialog_parts.dart';
import '../common/menu_check_gutter.dart';
import '../common/segmented_tabs.dart';
import '../custom_tooltip.dart';
import 'monitoring_layout_watch.dart';

/// How much the bar spells out; each step is tried in turn until the
/// search keeps a usable width.
enum _BarStep {
  /// Everything in words.
  full,

  /// The quick filters drop their names (kept in a tooltip) for an icon
  /// and the count.
  iconFilters,

  /// Also Group by, the density and the view switch go to icons.
  compact,
}

/// The 56 px bar above the data (§7i.1). On the left what picks the
/// projectors: search, the quick filters with their counts, Group by. On
/// the right what lays them out: the column chooser in Table or the density
/// switch in Cards, then Table / Cards.
class MonitoringBar extends ConsumerStatefulWidget {
  const MonitoringBar({super.key});

  static const double height = 56;

  @override
  ConsumerState<MonitoringBar> createState() => _MonitoringBarState();
}

class _MonitoringBarState extends ConsumerState<MonitoringBar> {
  /// Between the bar's blocks, and between the chips.
  static const double _gap = 8;
  static const double _chipGap = 6;
  static const double _maxSearch = 260;

  late final _search = TextEditingController(
    text: ref.read(monitoringFilterProvider).query,
  );
  late final _searchFocus = FocusNode(
    debugLabel: 'monitoring-search',
    onKeyEvent: _onSearchKey,
  );

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Esc empties a search first; on an empty one it goes on up, where it
  /// closes the projector panel.
  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        _search.text.isEmpty) {
      return KeyEventResult.ignored;
    }
    _setQuery('');
    return KeyEventResult.handled;
  }

  void _setQuery(String query) {
    if (_search.text != query) _search.text = query;
    ref.read(monitoringFilterProvider.notifier).setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    // Show all (in the empty view) clears the search from outside.
    ref.listen(monitoringFilterProvider.select((f) => f.query), (_, query) {
      if (_search.text != query) _search.text = query;
    });
    ref.listen(monitoringSearchFocusProvider, (_, _) {
      _searchFocus.requestFocus();
      _search.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _search.text.length,
      );
    });
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MonitoringBar.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth)),
    );
  }

  /// The first step that leaves the search its room, from estimates of
  /// each block's width in the style its text is drawn with.
  _BarStep _stepFor(
    BuildContext context,
    double width,
    QuickFilterCounts counts,
    bool byGroup,
  ) {
    for (final step in _BarStep.values) {
      final iconFilters = step != _BarStep.full;
      final compact = step == _BarStep.compact;
      var chips = 0.0;
      for (final f in MonitoringQuickFilter.values) {
        chips += _FilterChip.estimateWidth(
          context,
          f,
          counts[f],
          iconOnly: iconFilters,
        );
      }
      chips += _chipGap * (MonitoringQuickFilter.values.length - 1);
      final rest =
          chips +
          _GroupByButton.estimateWidth(context, byGroup, iconOnly: compact) +
          _densityWidth(context, compact) +
          _viewWidth(context, compact) +
          5 * _gap;
      final room = width - rest;
      final enough = switch (step) {
        _BarStep.full => 220.0,
        _BarStep.iconFilters => 160.0,
        _BarStep.compact => double.negativeInfinity,
      };
      if (room >= enough) return step;
    }
    return _BarStep.compact;
  }

  Widget _row(BuildContext context, double width) {
    final mode = ref.watch(monitoringViewProvider.select((s) => s.mode));
    final density = ref.watch(
      monitoringViewProvider.select((s) => s.cardDensity),
    );
    final byGroup = ref.watch(
      monitoringViewProvider.select((s) => s.groupByGroup),
    );
    final view = ref.read(monitoringViewProvider.notifier);
    final filter = ref.watch(monitoringFilterProvider);
    final counts = ref.watch(
      monitoringStatusProvider.select((m) => quickFilterCounts(m.values)),
    );
    final step = _stepFor(context, width, counts, byGroup);
    final iconFilters = step != _BarStep.full;
    final compact = step == _BarStep.compact;
    final setQuick = ref.read(monitoringFilterProvider.notifier).setQuick;

    return Row(
      children: [
        // The search gives way first, so the chips and Group by never
        // overflow; what is left over sits before the right-hand controls.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxSearch),
                  child: _SearchField(
                    controller: _search,
                    focusNode: _searchFocus,
                    hint: compact ? 'Search' : 'Search IP, model, serial',
                    count: filter.active ? _ShownCount(filter: filter) : null,
                    onChanged: _setQuery,
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Row(
                key: const ValueKey('monitoring-quick-filters'),
                spacing: _chipGap,
                children: [
                  for (final f in MonitoringQuickFilter.values)
                    _FilterChip(
                      filter: f,
                      count: counts[f],
                      selected: filter.quick == f,
                      iconOnly: iconFilters,
                      onPressed: () => setQuick(f),
                    ),
                ],
              ),
              const SizedBox(width: _gap),
              _GroupByButton(byGroup: byGroup, iconOnly: compact),
            ],
          ),
        ),
        const SizedBox(width: _gap),
        IndexedStack(
          key: const ValueKey('monitoring-bar-slot'),
          alignment: Alignment.centerRight,
          index: mode == MonitoringViewMode.table ? 0 : 1,
          children: [
            const _ColumnsButton(),
            SegmentedTabs<MonitoringCardDensity>(
              expand: false,
              tabs: [
                SegmentedTab(
                  value: MonitoringCardDensity.compact,
                  label: compact ? '' : 'Compact',
                  icon: compact ? Icons.view_comfy_outlined : null,
                ),
                SegmentedTab(
                  value: MonitoringCardDensity.extended,
                  label: compact ? '' : 'Extended',
                  icon: compact ? Icons.view_module_outlined : null,
                ),
              ],
              selected: density,
              onChanged: view.setCardDensity,
            ),
          ],
        ),
        const SizedBox(width: _gap),
        SegmentedTabs<MonitoringViewMode>(
          key: const ValueKey('monitoring-view-switch'),
          expand: false,
          tabs: [
            SegmentedTab(
              value: MonitoringViewMode.table,
              label: compact ? '' : 'Table',
              icon: Icons.table_rows_outlined,
            ),
            SegmentedTab(
              value: MonitoringViewMode.cards,
              label: compact ? '' : 'Cards',
              icon: Icons.grid_view_outlined,
            ),
          ],
          selected: mode,
          onChanged: view.setMode,
        ),
      ],
    );
  }

  // `SegmentedTabs` sizes itself; these mirror its metrics (12 px padding
  // and a 1 px border per tab, a 16 px icon and a 6 px gap, 3 px padding
  // and a 1 px border around the strip) only to pick a step.

  static double _tabsWidth(
    BuildContext context,
    List<String> labels, {
    required bool icons,
  }) {
    final style = AppText.of(context).body
        .copyWith(fontWeight: FontWeight.w600);
    var w = 8.0;
    for (final label in labels) {
      w += 26 + (icons ? 22 : 0) + _textWidth(context, label, style);
    }
    return w;
  }

  static double _densityWidth(BuildContext context, bool compact) {
    final strip = compact
        ? _tabsWidth(context, const ['', ''], icons: true)
        : _tabsWidth(context, const ['Compact', 'Extended'], icons: false);
    // The column chooser shares the slot; the slot is the wider of the two.
    return strip > 48 ? strip : 48;
  }

  static double _viewWidth(BuildContext context, bool compact) => _tabsWidth(
    context,
    compact ? const ['', ''] : const ['Table', 'Cards'],
    icons: true,
  );
}

/// The width [text] takes in [style] as a `Text` draws it: merged into the
/// ambient default style, which carries the app's font family. Measured
/// without that merge, the estimate is of the fallback font and comes out
/// too narrow.
double _textWidth(BuildContext context, String text, TextStyle style) {
  if (text.isEmpty) return 0;
  final p = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.iconOnly,
    required this.onPressed,
  });

  final MonitoringQuickFilter filter;
  final int count;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onPressed;

  static const double _mark = 14;

  static String labelOf(MonitoringQuickFilter f) => switch (f) {
    MonitoringQuickFilter.all => 'All',
    MonitoringQuickFilter.online => 'Online',
    MonitoringQuickFilter.attention => 'Attention',
    MonitoringQuickFilter.offline => 'Offline',
    MonitoringQuickFilter.standby => 'Standby',
  };

  static TextStyle _labelStyle(BuildContext context) =>
      AppText.of(context).description.copyWith(fontWeight: FontWeight.w500);

  static TextStyle _countStyle(BuildContext context) => AppText.of(context)
      .caption
      .copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// All has no mark beside its name, as in the mockup; on its own (icon
  /// only) it needs one.
  static bool _hasMark(MonitoringQuickFilter f, bool iconOnly) =>
      iconOnly || f != MonitoringQuickFilter.all;

  static double estimateWidth(
    BuildContext context,
    MonitoringQuickFilter f,
    int count, {
    required bool iconOnly,
  }) {
    final parts = [
      if (_hasMark(f, iconOnly)) _mark,
      if (!iconOnly) _textWidth(context, labelOf(f), _labelStyle(context)),
      _textWidth(context, '$count', _countStyle(context)),
    ];
    return 2 * BarChip.defaultPadding +
        parts.fold<double>(0, (a, b) => a + b) +
        BarChip.gap * (parts.length - 1);
  }

  /// A dot in the colour the table and the status bar use, or the icon of
  /// the mockup (standby's moon).
  Widget _mark14(BuildContext context, Color fg) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    Widget dot(Color color) => SizedBox.square(
      dimension: _mark,
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
    return switch (filter) {
      MonitoringQuickFilter.all => Icon(Icons.apps, size: _mark, color: fg),
      MonitoringQuickFilter.online => dot(sc.success),
      MonitoringQuickFilter.attention => dot(sc.warning),
      MonitoringQuickFilter.offline => dot(cs.outline),
      MonitoringQuickFilter.standby => Icon(
        Icons.dark_mode_outlined,
        size: _mark,
        color: fg,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = selected ? cs.onPrimaryContainer : t.secondary;
    final label = labelOf(filter);
    final chip = BarChip(
      key: ValueKey('monitoring-filter-${filter.name}'),
      selected: selected,
      onPressed: count == 0 ? null : onPressed,
      children: [
        if (_hasMark(filter, iconOnly)) _mark14(context, fg),
        if (!iconOnly)
          Text(label, style: _labelStyle(context).copyWith(color: fg)),
        Text(
          '$count',
          style: _countStyle(context)
              .copyWith(color: selected ? cs.onPrimaryContainer : t.tertiary),
        ),
      ],
    );
    return Semantics(
      label: iconOnly ? label : null,
      selected: selected,
      child: iconOnly ? CustomTooltip(message: label, child: chip) : chip,
    );
  }
}

/// `8 of 20` while a search or a quick filter hides some projectors.
class _ShownCount extends ConsumerWidget {
  const _ShownCount({required this.filter});

  final MonitoringFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shows = watchMonitoringFilter(ref);
    final shown = ref.watch(
      workspaceProvider.select((nodes) => nodes.where(shows).length),
    );
    final total = ref.watch(workspaceProvider.select((nodes) => nodes.length));
    return Text(
      '$shown of $total',
      key: const ValueKey('monitoring-shown-count'),
      style: AppText.of(context).description,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.count,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Widget? count;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('monitoring-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: plainFieldStyle,
      decoration: dialogFieldDecoration(
        context,
        hintText: hint,
        prefixIcon: Icons.search,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?count,
              // The clear button's slot is kept while empty, so the count
              // doesn't move when typing starts.
              SizedBox.square(
                dimension: 32,
                child: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close),
                        onPressed: () => onChanged(''),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupByButton extends ConsumerWidget {
  const _GroupByButton({required this.byGroup, required this.iconOnly});

  final bool byGroup;
  final bool iconOnly;

  static String labelOf(bool byGroup) =>
      byGroup ? 'Group by: group' : 'Group by: none';

  static TextStyle _style(BuildContext context) =>
      AppText.of(context).description.copyWith(fontWeight: FontWeight.w500);

  static double estimateWidth(
    BuildContext context,
    bool byGroup, {
    required bool iconOnly,
  }) =>
      2 * BarChip.defaultPadding +
      (iconOnly ? 14 : _textWidth(context, labelOf(byGroup), _style(context))) +
      BarChip.gap +
      16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(monitoringViewProvider.notifier);
    final t = AppText.of(context);
    final label = labelOf(byGroup);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: byGroup),
          onPressed: () => notifier.setGroupByGroup(true),
          child: const Text('Group'),
        ),
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: !byGroup),
          onPressed: () => notifier.setGroupByGroup(false),
          child: const Text('None'),
        ),
      ],
      builder: (context, controller, _) {
        final chip = BarChip(
          key: const ValueKey('monitoring-group-by'),
          selected: false,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          children: [
            if (iconOnly)
              Icon(Icons.workspaces_outlined, size: 14, color: t.secondary)
            else
              Text(label, style: _style(context).copyWith(color: t.secondary)),
            Icon(Icons.expand_more, size: 16, color: t.secondary),
          ],
        );
        return iconOnly ? CustomTooltip(message: label, child: chip) : chip;
      },
    );
  }
}

/// The column chooser: a checkbox per column, then *Show all columns* and
/// *Fit columns to window*. The menu stays open while columns are toggled.
class _ColumnsButton extends ConsumerWidget {
  const _ColumnsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(monitoringViewProvider.select((s) => s.columns));
    final fit = ref.watch(
      appSettingsProvider.select((s) => s.monitoringFitToWidth),
    );
    final visible = resolveMonitoringTableColumns(saved);
    final notifier = ref.read(monitoringViewProvider.notifier);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final c in kMonitoringTableColumns)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: MenuCheckGutter(checked: visible.contains(c.id)),
            onPressed: () => notifier.toggleColumn(c.id),
            child: SizedBox(width: 180, child: Text(c.label)),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const MenuCheckGutter(),
          onPressed: () => notifier.setColumns([
            for (final c in kMonitoringTableColumns) c.id,
          ]),
          child: const Text('Show all columns'),
        ),
        MenuItemButton(
          leadingIcon: MenuCheckGutter(checked: fit),
          onPressed: () => ref
              .read(appSettingsProvider.notifier)
              .setMonitoringFitToWidth(!fit),
          child: const Text('Fit columns to window'),
        ),
      ],
      builder: (context, controller, _) => CustomTooltip(
        message: 'Columns',
        child: IconButton(
          icon: const Icon(Icons.view_column_outlined, size: 20),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
