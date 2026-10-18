import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/monitoring_layout.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/monitoring_table_columns.dart';
import '../../../domain/projector_group.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_panel_provider.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import '../../providers/workspace_provider.dart';
import 'monitoring_actions.dart';
import 'monitoring_cells.dart';
import 'monitoring_group_header.dart';
import 'monitoring_layout_watch.dart';
import 'monitoring_no_matches.dart';
import 'monitoring_parts.dart';

/// Row, header and group row height and the cell padding for each row
/// density. Two lines per row, so even Compact is taller than the old
/// single-line rows.
({double row, double header, double group, double hpad}) _metrics(
  MonitoringDensity d,
) => switch (d) {
  MonitoringDensity.compact => (row: 46, header: 36, group: 38, hpad: 8),
  MonitoringDensity.standard => (row: 52, header: 40, group: 40, hpad: 12),
  MonitoringDensity.comfortable => (row: 60, header: 44, group: 44, hpad: 16),
};

/// The group row's height, which the cards' group rows share so both views
/// band their groups alike.
double monitoringGroupRowHeight(MonitoringDensity d) => _metrics(d).group;

/// The Monitoring table (§7i.2): group rows (or a flat list with a Group
/// column), two-line columns from the column chooser, sort on a header
/// click, reorder by dragging a header, resize and auto-fit on a header's
/// right edge. A row click opens the projector panel.
class MonitoringDataTable extends ConsumerStatefulWidget {
  const MonitoringDataTable({super.key});

  @override
  ConsumerState<MonitoringDataTable> createState() =>
      _MonitoringDataTableState();
}

sealed class _Entry {
  const _Entry();
}

final class _HeaderEntry extends _Entry {
  const _HeaderEntry(this.section, this.collapsed);
  final MonitoringSection section;
  final bool collapsed;
}

final class _NodeEntry extends _Entry {
  const _NodeEntry(this.nodeId);
  final String nodeId;
}

class _MonitoringDataTableState extends ConsumerState<MonitoringDataTable> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _headerHorizontal = ScrollController();

  String? _dragOverId;

  // Header-edge resize, transient while dragging; the width is saved once
  // on drag end, not on every pointer move.
  String? _resizeId;
  double _resizeStart = 0; // on-screen width at drag start
  double _resizeOtherBase = 0; // the other columns' base widths
  double _resizeViewport = 0;
  bool _resizeScaling = false; // fit-to-window was scaling at drag start
  double _resizeDx = 0;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(() {
      if (_headerHorizontal.hasClients &&
          _headerHorizontal.position.hasPixels) {
        _headerHorizontal.jumpTo(_horizontal.offset);
      }
    });
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    _headerHorizontal.dispose();
    super.dispose();
  }

  /// The base width for the accumulated drag: with fit-to-window scaling,
  /// a base `b` renders at `b * V / (B + b)` (other columns' base `B`,
  /// viewport `V`), so the on-screen width `e` needs `b = e * B / (V - e)`;
  /// once the columns no longer fit, base and on-screen width are equal.
  double _resizeBase() {
    final desired = _resizeStart + _resizeDx;
    final limit = _resizeViewport - _resizeOtherBase;
    final base = _resizeScaling && _resizeOtherBase > 0 && desired < limit
        ? desired * _resizeOtherBase / (_resizeViewport - desired)
        : desired;
    return base.clamp(kMonitoringTableMinColumnWidth, 600.0);
  }

  void _endResize() {
    final id = _resizeId;
    if (id == null) return;
    final width = _resizeBase();
    setState(() {
      _resizeId = null;
      _resizeDx = 0;
    });
    ref.read(monitoringViewProvider.notifier).setColumnWidth(id, width);
  }

  void _autoFit(
    String id,
    Map<String, ProjectorGroup> groups,
    double hpad,
    TextStyle body,
    TextStyle header,
  ) {
    double measure(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final statuses = ref.read(monitoringStatusProvider);
    final alerts = ref.read(appSettingsProvider).alerts;
    var widest = measure(monitoringTableColumn(id)!.label, header);
    for (final n in ref.read(workspaceProvider)) {
      final data = (
        node: n,
        status: statuses[n.id] ?? const MonitoringStatus(),
        groups: groups,
        alerts: alerts,
      );
      for (final text in monitoringCellTexts(id, data)) {
        final w = measure(text, body) + monitoringCellIconPad(id);
        if (w > widest) widest = w;
      }
    }
    ref
        .read(monitoringViewProvider.notifier)
        .setColumnWidth(
          id,
          (widest + 2 * hpad + 6).clamp(kMonitoringTableMinColumnWidth, 600.0),
        );
  }

  @override
  Widget build(BuildContext context) {
    final layout = watchMonitoringLayout(ref);
    final saved = ref.watch(monitoringViewProvider.select((s) => s.columns));
    final widthOverrides = ref.watch(
      monitoringViewProvider.select((s) => s.columnWidths),
    );
    final sortId = ref.watch(
      monitoringViewProvider.select((s) => s.sortColumnId),
    );
    final ascending = ref.watch(
      monitoringViewProvider.select((s) => s.sortAscending),
    );
    final collapsed = ref.watch(
      monitoringViewProvider.select((s) => s.collapsed),
    );
    final byGroup = ref.watch(
      monitoringViewProvider.select((s) => s.groupByGroup),
    );
    final filtering = ref.watch(
      monitoringFilterProvider.select((f) => f.active),
    );
    final fitToWidth = ref.watch(
      appSettingsProvider.select((s) => s.monitoringFitToWidth),
    );
    final m = _metrics(
      ref.watch(appSettingsProvider.select((s) => s.monitoringDensity)),
    );

    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final allIds = resolveMonitoringTableColumns(saved);
    // Grouped, the group rows name the group; the column comes back with
    // Group by: none.
    var cols = [
      for (final id in allIds)
        if (!(byGroup && id == 'group')) monitoringTableColumn(id)!,
    ];
    if (cols.isEmpty) cols = [monitoringTableColumn(allIds.first)!];

    final entries = <_Entry>[
      for (final s in layout.sections) ...[
        if (!s.flat) _HeaderEntry(s, collapsed.contains(s.key)),
        if (s.flat || !collapsed.contains(s.key))
          for (final id in s.nodeIds) _NodeEntry(id),
      ],
    ];
    final groups = layout.groupsById;

    final baseWidths = [
      for (final c in cols)
        c.id == _resizeId
            ? _resizeBase()
            : (widthOverrides[c.id] ?? c.defaultWidth),
    ];
    final baseTotal = baseWidths.fold<double>(0, (a, b) => a + b);
    final hpad = m.hpad;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final room = viewport - kMonitoringActionsWidth;
        final scale = fitToWidth && room > baseTotal;
        final widths = scale
            ? [for (final w in baseWidths) w * room / baseTotal]
            : baseWidths;
        final tableWidth =
            widths.fold<double>(0, (a, b) => a + b) + kMonitoringActionsWidth;

        Widget headerCell(int i) {
          final c = cols[i];
          final sorted = c.id == sortId;
          final content = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ref.read(monitoringViewProvider.notifier).sortBy(c.id),
              child: Container(
                width: widths[i],
                height: m.header,
                color: _dragOverId == c.id
                    ? cs.primary.withValues(alpha: 0.10)
                    : null,
                padding: EdgeInsets.symmetric(horizontal: hpad),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sorted
                            ? t.label.copyWith(color: t.primary)
                            : t.label,
                      ),
                    ),
                    if (sorted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: cs.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
          final cell = DragTarget<String>(
            onWillAcceptWithDetails: (d) => d.data != c.id,
            onMove: (_) {
              if (_dragOverId != c.id) setState(() => _dragOverId = c.id);
            },
            onLeave: (_) {
              if (_dragOverId == c.id) setState(() => _dragOverId = null);
            },
            onAcceptWithDetails: (d) {
              setState(() => _dragOverId = null);
              // The full saved list, Group included while it is hidden, so
              // a reorder never drops it.
              ref
                  .read(monitoringViewProvider.notifier)
                  .setColumns(
                    reorderMonitoringTableColumn(allIds, d.data, c.id),
                  );
            },
            builder: (context, _, _) => Draggable<String>(
              data: c.id,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: _DragFeedback(label: c.label),
              childWhenDragging: Opacity(opacity: 0.35, child: content),
              child: content,
            ),
          );
          return Stack(
            children: [
              cell,
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _ResizeHandle(
                  height: m.header,
                  onStart: () => setState(() {
                    _resizeId = c.id;
                    _resizeStart = widths[i];
                    _resizeOtherBase = baseTotal - baseWidths[i];
                    _resizeViewport = room;
                    _resizeScaling = scale;
                    _resizeDx = 0;
                  }),
                  onUpdate: (dx) => setState(() => _resizeDx += dx),
                  onEnd: _endResize,
                  onAutoFit: () =>
                      _autoFit(c.id, groups, hpad, t.body, t.label),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: viewport,
              child: SingleChildScrollView(
                controller: _headerHorizontal,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  height: m.header,
                  child: Row(
                    children: [
                      for (var i = 0; i < cols.length; i++) headerCell(i),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: entries.isEmpty && filtering
                  ? const MonitoringNoMatches()
                  : Scrollbar(
                      controller: _vertical,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.depth == 1,
                      child: Scrollbar(
                        controller: _horizontal,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: ListView.builder(
                              controller: _vertical,
                              itemCount: entries.length,
                              itemExtentBuilder: (i, _) => i >= entries.length
                                  ? null
                                  : entries[i] is _HeaderEntry
                                  ? m.group
                                  : m.row,
                              itemBuilder: (context, i) => switch (entries[i]) {
                                _HeaderEntry(
                                  :final section,
                                  :final collapsed,
                                ) =>
                                  MonitoringGroupHeader(
                                    key: ValueKey('group-${section.key}'),
                                    section: section,
                                    collapsed: collapsed,
                                  ),
                                _NodeEntry(:final nodeId) => _TableRow(
                                  key: ValueKey(nodeId),
                                  nodeId: nodeId,
                                  columns: [for (final c in cols) c.id],
                                  widths: widths,
                                  groups: groups,
                                  hpad: hpad,
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// One projector's row. Watches only its own node, status and whether its
/// panel is open, so a poll rebuilds just the rows it changed.
class _TableRow extends ConsumerStatefulWidget {
  const _TableRow({
    super.key,
    required this.nodeId,
    required this.columns,
    required this.widths,
    required this.groups,
    required this.hpad,
  });

  final String nodeId;
  final List<String> columns;
  final List<double> widths;
  final Map<String, ProjectorGroup> groups;
  final double hpad;

  @override
  ConsumerState<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends ConsumerState<_TableRow> {
  bool _hovered = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.nodeId;
    final node = ref.watch(
      workspaceProvider.select(
        (nodes) => nodes.where((n) => n.id == id).firstOrNull,
      ),
    );
    if (node == null) return const SizedBox.shrink();
    final status = ref.watch(
      monitoringStatusProvider.select((m) => m[id] ?? const MonitoringStatus()),
    );
    final selected = ref.watch(monitoringPanelProvider.select((p) => p == id));
    final alerts = ref.watch(appSettingsProvider.select((s) => s.alerts));
    final cs = Theme.of(context).colorScheme;
    final data = (
      node: node,
      status: status,
      groups: widget.groups,
      alerts: alerts,
    );
    final accent = problemColor(context, status.level);
    final offline = status.level == ProblemLevel.offline;
    final background = selected
        ? cs.primary.withValues(alpha: 0.10)
        : _hovered
        ? cs.primary.withValues(alpha: 0.05)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final panel = ref.read(monitoringPanelProvider.notifier);
          selected ? panel.close() : panel.open(id);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < widget.columns.length; i++)
                    SizedBox(
                      width: widget.widths[i],
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: widget.hpad),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          // Offline: the last known values, dimmed; the
                          // projector and its Offline badge stay readable.
                          child: Opacity(
                            opacity:
                                offline &&
                                    widget.columns[i] != 'projector' &&
                                    widget.columns[i] != 'errors'
                                ? 0.5
                                : 1,
                            child: monitoringCell(
                              context,
                              widget.columns[i],
                              data,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: kMonitoringActionsWidth,
                    child: _hovered || _menuOpen
                        ? Center(
                            child: MonitoringRowActions(
                              node: node,
                              onMenuOpenChanged: (open) =>
                                  setState(() => _menuOpen = open),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              if (accent != null)
                Positioned(
                  left: 0,
                  top: 6,
                  bottom: 6,
                  width: 3,
                  child: DecoratedBox(
                    key: const ValueKey('problem-accent'),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The invisible zone on a header's right edge: drag to resize,
/// double-click to auto-fit. A hairline shows on hover, 2 px primary while
/// dragging.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.height,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onAutoFit,
  });

  final double height;
  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onAutoFit;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _dragging
        ? cs.primary
        : _hover
        ? cs.outlineVariant
        : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onAutoFit,
        onHorizontalDragStart: (_) {
          setState(() => _dragging = true);
          widget.onStart();
        },
        onHorizontalDragUpdate: (d) => widget.onUpdate(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onEnd();
        },
        child: SizedBox(
          width: 12,
          height: widget.height,
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: _dragging ? 2 : 1,
                height: widget.height,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.primary),
        ),
        child: Text(label, style: AppText.of(context).label),
      ),
    );
  }
}
