import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/workspace_provider.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';

const double _kRowHeight = 40;
const double _kAccentWidth = 3;
const EdgeInsets _kCellPadding = EdgeInsets.symmetric(horizontal: 16);

/// One monitoring-table column. The descriptor list (`_allColumns`) is the
/// single source of truth for what columns exist, their default geometry, how
/// they sort, and how a cell renders — replacing the old parallel
/// `_columnLabels` / `_columnWidths` / index `switch` that all had to stay
/// aligned by hand.
class _Column {
  final String id;
  final String label;
  final double defaultWidth;

  /// Leading-icon allowance (px) added on top of the measured text width when
  /// auto-fitting, for cells that render an icon before their text.
  final double iconPad;

  /// Plain text the cell shows, ignoring any icon — used for auto-fit
  /// measurement and as the tooltip contents.
  final String Function(ProjectorNode, Map<String, ProjectorGroup>) text;

  /// Sort key for this column. Return type is consistent within a column
  /// (num for numeric columns, String/int elsewhere) so `Comparable.compare`
  /// never mixes types.
  final Comparable Function(ProjectorNode, Map<String, ProjectorGroup>) sortKey;

  /// Builds the cell body (may include icons); receives the already-resolved
  /// group map so it doesn't re-look-up per row.
  final Widget Function(BuildContext, ProjectorNode, Map<String, ProjectorGroup>)
  cell;

  const _Column({
    required this.id,
    required this.label,
    required this.defaultWidth,
    required this.text,
    required this.sortKey,
    required this.cell,
    this.iconPad = 0,
  });
}

class MonitoringTable extends ConsumerStatefulWidget {
  const MonitoringTable({super.key});

  @override
  ConsumerState<MonitoringTable> createState() => _MonitoringTableState();

  // ── Column catalogue, exposed for the View ▸ Monitoring Table menu ──────

  /// All known column ids in canonical order.
  static List<String> get allColumnIds =>
      _MonitoringTableState._allColumns.map((c) => c.id).toList();

  /// Human label for a column id.
  static String labelFor(String id) =>
      _MonitoringTableState._columnsById[id]?.label ?? id;

  /// Visible columns (ordered) the table would actually render for [saved] —
  /// resolves the "empty means defaults" rule so the menu shows real state.
  static List<String> resolveVisible(List<String> saved) {
    final ids = saved.isEmpty
        ? _MonitoringTableState._defaultVisibleIds
        : saved;
    final known = [
      for (final id in ids)
        if (_MonitoringTableState._columnsById.containsKey(id)) id,
    ];
    return known.isEmpty
        ? List.of(_MonitoringTableState._defaultVisibleIds)
        : known;
  }

  /// Toggles [id] in the visible set. Re-showing a column drops it back at its
  /// canonical position relative to the columns already visible. Returns null
  /// if the change would hide the last remaining column.
  static List<String>? toggledColumn(List<String> saved, String id) {
    final visible = resolveVisible(saved);
    if (visible.contains(id)) {
      if (visible.length == 1) return null;
      return [
        for (final c in visible)
          if (c != id) c,
      ];
    }
    final canonical = allColumnIds;
    final insertRank = canonical.indexOf(id);
    final next = List.of(visible);
    var insertAt = next.length;
    for (var i = 0; i < next.length; i++) {
      if (canonical.indexOf(next[i]) > insertRank) {
        insertAt = i;
        break;
      }
    }
    next.insert(insertAt, id);
    return next;
  }

  /// Named column presets for the menu.
  static const Map<String, List<String>> presets = {
    'Essentials': ['connection', 'model', 'ip', 'power', 'shutter', 'input',
        'errors'],
    'Thermal': ['connection', 'model', 'ip', 'intake', 'exhaust', 'runtime',
        'voltage'],
    'Signal': ['connection', 'model', 'ip', 'input', 'signal', 'power',
        'shutter'],
  };

  static List<String> get showAllColumns => allColumnIds;
}

class _MonitoringTableState extends ConsumerState<MonitoringTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _headerHorizontalController = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'MonitoringTable');

  // Sort cache — avoids re-sorting on every build when nothing changed.
  List<ProjectorNode> _cachedSorted = const [];
  List<ProjectorNode>? _lastNodes;
  String _lastSortId = '';
  bool _lastSortAsc = true;
  int _lastGroupsHash = 0;

  String? _dragOverColId;
  int? _selectionAnchor; // index into the sorted list, for shift-range select

  static const double _rowHeight = _kRowHeight;
  static const double _headerHeight = 48;
  static const EdgeInsets _cellPadding = _kCellPadding;

  // ── Const icon widgets — allocated once, reused across all rows ───────────

  static const _iconOnline = Icon(Icons.circle, size: 12, color: Colors.green);
  static const _iconOffline = Icon(Icons.circle, size: 12, color: Colors.red);
  static const _iconWarning = Icon(Icons.circle, size: 12, color: Colors.amber);
  static const _iconLock = Icon(Icons.lock_outline, size: 12, color: Colors.amber);
  static const _iconLockOpen = Icon(Icons.lock_open, size: 12, color: Colors.blue);
  static const _iconPowerOn = Icon(
    Icons.power_settings_new,
    size: 16,
    color: Colors.green,
  );
  static const _iconPowerOff = Icon(
    Icons.power_settings_new,
    size: 16,
    color: Colors.red,
  );
  static const _iconShutterOpen = Icon(
    Icons.visibility,
    size: 16,
    color: Colors.green,
  );
  static const _iconShutterClosed = Icon(
    Icons.visibility,
    size: 16,
    color: Colors.red,
  );
  static const _iconNoErrors = Icon(
    Icons.check_circle,
    size: 13,
    color: Colors.green,
  );
  static const _iconErrors = Icon(Icons.error, size: 13, color: Colors.red);
  static const _gap4 = SizedBox(width: 4);
  static const _gap6 = SizedBox(width: 6);

  // ── Column descriptors ──────────────────────────────────────────────────

  /// Every known column, in canonical order. `_defaultVisibleIds` picks the
  /// subset shown before the user customises anything.
  static final List<_Column> _allColumns = [
    _Column(
      id: 'connection',
      label: 'Connection',
      defaultWidth: 130,
      iconPad: 22,
      text: (n, _) => switch (n.connectionStatus) {
        ConnectionStatus.connected => 'Online',
        ConnectionStatus.unprotected => 'Online',
        ConnectionStatus.unauthorized => 'Auth Error',
        ConnectionStatus.offline => 'Offline',
      },
      sortKey: (n, _) => switch (n.connectionStatus) {
        ConnectionStatus.connected => 0,
        ConnectionStatus.unprotected => 1,
        ConnectionStatus.unauthorized => 2,
        ConnectionStatus.offline => 3,
      },
      cell: (_, n, _) => _connectionCell(n),
    ),
    _Column(
      id: 'model',
      label: 'Model',
      defaultWidth: 160,
      text: (n, _) => n.name,
      sortKey: (n, _) => n.name.toLowerCase(),
      cell: (_, n, _) => _CellText(n.name),
    ),
    _Column(
      id: 'serial',
      label: 'Serial Number',
      defaultWidth: 160,
      text: (n, _) => n.serialNumber,
      sortKey: (n, _) => n.serialNumber.toLowerCase(),
      cell: (_, n, _) => _CellText(n.serialNumber),
    ),
    _Column(
      id: 'group',
      label: 'Group',
      defaultWidth: 150,
      iconPad: 18,
      text: (n, groups) => _groupOf(n, groups)?.name ?? '—',
      // Ungrouped sorts last (ascending) via a high sentinel.
      sortKey: (n, groups) =>
          (_groupOf(n, groups)?.name ?? '￿').toLowerCase(),
      cell: (_, n, groups) => _groupCell(_groupOf(n, groups)),
    ),
    _Column(
      id: 'ip',
      label: 'IP Address',
      defaultWidth: 130,
      text: (n, _) => n.ipAddress,
      sortKey: (n, _) => _ipSortKey(n.ipAddress),
      cell: (_, n, _) => _CellText(n.ipAddress),
    ),
    _Column(
      id: 'power',
      label: 'Power',
      defaultWidth: 130,
      iconPad: 22,
      text: (n, _) => n.powerStatus == PowerStatus.on ? 'ON' : 'STANDBY',
      sortKey: (n, _) => n.powerStatus == PowerStatus.on ? 0 : 1,
      cell: (_, n, _) => _powerCell(n),
    ),
    _Column(
      id: 'shutter',
      label: 'Shutter',
      defaultWidth: 110,
      iconPad: 22,
      text: (n, _) => n.shutterStatus == ShutterStatus.open ? 'OPEN' : 'CLOSED',
      sortKey: (n, _) => n.shutterStatus == ShutterStatus.open ? 0 : 1,
      cell: (_, n, _) => _shutterCell(n),
    ),
    _Column(
      id: 'input',
      label: 'Input',
      defaultWidth: 90,
      text: (n, _) => n.input,
      sortKey: (n, _) => n.input.toLowerCase(),
      cell: (_, n, _) => _CellText(n.input),
    ),
    _Column(
      id: 'signal',
      label: 'Signal',
      defaultWidth: 140,
      text: (n, _) => n.signal,
      sortKey: (n, _) => n.signal.toLowerCase(),
      cell: (_, n, _) => _CellText(n.signal),
    ),
    _Column(
      id: 'runtime',
      label: 'Runtime',
      defaultWidth: 110,
      text: (n, _) => n.runtime,
      sortKey: (n, _) => _leadingNum(n.runtime),
      cell: (_, n, _) => _CellText(n.runtime),
    ),
    _Column(
      id: 'intake',
      label: 'Intake Temp',
      defaultWidth: 130,
      text: (n, _) => n.intakeTemp,
      sortKey: (n, _) => _leadingNum(n.intakeTemp),
      cell: (_, n, _) => _CellText(n.intakeTemp),
    ),
    _Column(
      id: 'exhaust',
      label: 'Exhaust Temp',
      defaultWidth: 150,
      text: (n, _) => n.exhaustTemp,
      sortKey: (n, _) => _leadingNum(n.exhaustTemp),
      cell: (_, n, _) => _CellText(n.exhaustTemp),
    ),
    _Column(
      id: 'voltage',
      label: 'AC Voltage',
      defaultWidth: 130,
      text: (n, _) => n.acVoltage,
      sortKey: (n, _) => _leadingNum(n.acVoltage),
      cell: (_, n, _) => _CellText(n.acVoltage),
    ),
    _Column(
      id: 'errors',
      label: 'Errors',
      defaultWidth: 140,
      iconPad: 20,
      text: (n, _) => _errorsOk(n.errors) ? 'NO ERRORS' : n.errors,
      // Faulted rows sort before healthy ones (ascending).
      sortKey: (n, _) => '${_errorsOk(n.errors) ? 1 : 0}${n.errors}',
      cell: (_, n, _) => _errorsCell(n),
    ),
  ];

  static const List<String> _defaultVisibleIds = [
    'connection',
    'model',
    'serial',
    'ip',
    'power',
    'shutter',
    'input',
    'signal',
    'runtime',
    'intake',
    'exhaust',
    'voltage',
    'errors',
  ];

  static final Map<String, _Column> _columnsById = {
    for (final c in _allColumns) c.id: c,
  };

  /// Floor for auto-fit / (future) manual column resize.
  static const double _minColWidth = 60;

  // ── Column resolution ───────────────────────────────────────────────────

  /// Turns the persisted id list into concrete descriptors. Empty / all-unknown
  /// falls back to the default set; unknown ids are dropped.
  List<_Column> _resolveColumns(List<String> saved) {
    final ids = saved.isEmpty ? _defaultVisibleIds : saved;
    final cols = [
      for (final id in ids)
        if (_columnsById[id] != null) _columnsById[id]!,
    ];
    return cols.isEmpty
        ? [for (final id in _defaultVisibleIds) _columnsById[id]!]
        : cols;
  }

  // ── Static value helpers ────────────────────────────────────────────────

  static ProjectorGroup? _groupOf(
    ProjectorNode n,
    Map<String, ProjectorGroup> groups,
  ) => n.groupId == null ? null : groups[n.groupId];

  static bool _errorsOk(String errors) =>
      errors == 'NO ERRORS' || errors.isEmpty;

  /// Leading numeric value of a display string like `"25°C"`, `"1234H"`,
  /// `"120V"`; `-` / non-numeric sort first (ascending) via -infinity.
  static num _leadingNum(String s) {
    final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
    return m == null ? double.negativeInfinity : num.parse(m.group(0)!);
  }

  /// Zero-padded dotted-quad so a plain string compare orders IPs numerically.
  static String _ipSortKey(String ip) => ip
      .split('.')
      .map((o) => (int.tryParse(o) ?? 0).toString().padLeft(3, '0'))
      .join('.');

  // ── Scroll sync ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_syncHeader);
  }

  void _syncHeader() {
    if (_headerHorizontalController.hasClients &&
        _headerHorizontalController.position.hasPixels) {
      _headerHorizontalController.jumpTo(_horizontalController.offset);
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _headerHorizontalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Sort ────────────────────────────────────────────────────────────────

  void _onHeaderTap(String columnId) {
    final s = ref.read(appSettingsProvider);
    final asc = s.monitoringSortColumnId == columnId
        ? !s.monitoringSortAscending
        : true;
    ref.read(appSettingsProvider.notifier).setMonitoringSort(columnId, asc);
  }

  List<ProjectorNode> _sortNodes(
    List<ProjectorNode> nodes,
    _Column col,
    bool ascending,
    Map<String, ProjectorGroup> groups,
  ) {
    final sorted = List<ProjectorNode>.from(nodes);
    sorted.sort((a, b) {
      final cmp = Comparable.compare(
        col.sortKey(a, groups),
        col.sortKey(b, groups),
      );
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  List<ProjectorNode> _getOrSortNodes(
    List<ProjectorNode> nodes,
    _Column col,
    bool ascending,
    Map<String, ProjectorGroup> groups,
  ) {
    final groupsHash = Object.hashAll(
      groups.entries.map((e) => Object.hash(e.key, e.value.name)),
    );
    if (identical(nodes, _lastNodes) &&
        _lastSortId == col.id &&
        _lastSortAsc == ascending &&
        _lastGroupsHash == groupsHash) {
      return _cachedSorted;
    }
    _lastNodes = nodes;
    _lastSortId = col.id;
    _lastSortAsc = ascending;
    _lastGroupsHash = groupsHash;
    _cachedSorted = _sortNodes(nodes, col, ascending, groups);
    return _cachedSorted;
  }

  // ── Column reorder ──────────────────────────────────────────────────────

  void _reorderColumn(List<_Column> current, String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final ids = [for (final c in current) c.id];
    ids.remove(draggedId);
    final targetIdx = ids.indexOf(targetId);
    if (targetIdx < 0) return;
    ids.insert(targetIdx, draggedId);
    ref.read(appSettingsProvider.notifier).setMonitoringColumns(ids);
  }

  // ── Column auto-fit (header double-click) ───────────────────────────────

  void _autoFitColumn(
    _Column col,
    List<ProjectorNode> nodes,
    Map<String, ProjectorGroup> groups,
    TextStyle bodyStyle,
    TextStyle headerStyle,
  ) {
    double measure(String text, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    var widest = measure(col.label, headerStyle);
    for (final n in nodes) {
      final w = measure(col.text(n, groups), bodyStyle) + col.iconPad;
      if (w > widest) widest = w;
    }
    final target = (widest + _cellPadding.horizontal + 6).clamp(
      _minColWidth,
      600.0,
    );
    ref
        .read(appSettingsProvider.notifier)
        .setMonitoringColumnWidth(col.id, target);
  }

  // ── Selection ──────────────────────────────────────────────────────────

  void _onRowTap(int index, List<ProjectorNode> sorted) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final multi =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final range =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final sel = ref.read(selectionProvider.notifier);
    final id = sorted[index].id;

    if (range && _selectionAnchor != null) {
      final lo = _selectionAnchor! < index ? _selectionAnchor! : index;
      final hi = _selectionAnchor! < index ? index : _selectionAnchor!;
      final next = {
        ...ref.read(selectionProvider),
        for (var i = lo; i <= hi; i++) sorted[i].id,
      };
      sel.set(next);
      return;
    }
    if (multi) {
      sel.toggle(id);
    } else {
      sel.selectOnly(id);
    }
    _selectionAnchor = index;
  }

  void _selectAllVisible(List<ProjectorNode> sorted) {
    ref.read(selectionProvider.notifier).set({for (final n in sorted) n.id});
  }

  // ── Cell builders ──────────────────────────────────────────────────────

  static Widget _connectionCell(ProjectorNode node) {
    final isOnline = node.connectionStatus == ConnectionStatus.connected;
    final isUnprotected = node.connectionStatus == ConnectionStatus.unprotected;
    final isUnauth = node.connectionStatus == ConnectionStatus.unauthorized;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOnline || isUnprotected
            ? _iconOnline
            : (isUnauth ? _iconWarning : _iconOffline),
        _gap6,
        Flexible(
          child: Text(
            isOnline
                ? 'Online'
                : isUnprotected
                ? 'Online'
                : isUnauth
                ? 'Auth Error'
                : 'Offline',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isUnauth) ...[_gap4, _iconLock],
        if (isUnprotected) ...[_gap4, _iconLockOpen],
      ],
    );
  }

  static Widget _powerCell(ProjectorNode node) {
    final on = node.powerStatus == PowerStatus.on;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        on ? _iconPowerOn : _iconPowerOff,
        _gap4,
        Flexible(
          child: Text(on ? 'ON' : 'STANDBY', overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  static Widget _shutterCell(ProjectorNode node) {
    final open = node.shutterStatus == ShutterStatus.open;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        open ? _iconShutterOpen : _iconShutterClosed,
        _gap4,
        Flexible(
          child: Text(open ? 'OPEN' : 'CLOSED', overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  static Widget _groupCell(ProjectorGroup? group) {
    if (group == null) return const _CellText('—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Color(group.color),
            shape: BoxShape.circle,
          ),
        ),
        _gap6,
        Flexible(child: _CellText(group.name)),
      ],
    );
  }

  static Widget _errorsCell(ProjectorNode node) {
    if (node.errors == '-') return const _CellText('-');
    final ok = _errorsOk(node.errors);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ok ? _iconNoErrors : _iconErrors,
        _gap6,
        Flexible(
          child: _CellText(
            ok ? 'NO ERRORS' : node.errors,
            color: ok ? null : Colors.red,
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(
    List<_Column> cols,
    List<double> widths,
    double tableWidth,
    TextStyle? headingStyle,
    Color primaryColor,
    String sortId,
    bool sortAsc,
    Color dragTargetColor,
    void Function(String columnId) onAutoFit,
  ) {
    return SizedBox(
      height: _headerHeight,
      width: tableWidth,
      child: Row(
        children: List.generate(cols.length, (i) {
          final col = cols[i];
          final isSorted = sortId == col.id;
          final isDragOver = _dragOverColId == col.id;

          final headerContent = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onHeaderTap(col.id),
              onDoubleTap: () => onAutoFit(col.id),
              child: Container(
                width: widths[i],
                height: _headerHeight,
                color: isDragOver ? dragTargetColor : null,
                padding: _cellPadding,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        col.label,
                        style: headingStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSorted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

          return DragTarget<String>(
            onWillAcceptWithDetails: (d) => d.data != col.id,
            onMove: (_) {
              if (_dragOverColId != col.id) {
                setState(() => _dragOverColId = col.id);
              }
            },
            onLeave: (_) {
              if (_dragOverColId == col.id) {
                setState(() => _dragOverColId = null);
              }
            },
            onAcceptWithDetails: (d) {
              setState(() => _dragOverColId = null);
              _reorderColumn(cols, d.data, col.id);
            },
            builder: (context, _, _) => Draggable<String>(
              data: col.id,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: _HeaderDragFeedback(
                label: col.label,
                style: headingStyle,
                color: primaryColor,
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: headerContent),
              child: headerContent,
            ),
          );
        }),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final groupList = ref.read(workspaceProvider.notifier).groups;
    final groups = {for (final g in groupList) g.id: g};
    final selection = ref.watch(selectionProvider);

    final savedColumns = ref.watch(
      appSettingsProvider.select((s) => s.monitoringColumns),
    );
    final widthOverrides = ref.watch(
      appSettingsProvider.select((s) => s.monitoringColumnWidths),
    );
    final sortId = ref.watch(
      appSettingsProvider.select((s) => s.monitoringSortColumnId),
    );
    final sortAsc = ref.watch(
      appSettingsProvider.select((s) => s.monitoringSortAscending),
    );
    final fitToWidth = ref.watch(
      appSettingsProvider.select((s) => s.monitoringFitToWidth),
    );

    final theme = Theme.of(context);
    final cols = _resolveColumns(savedColumns);
    final sortCol = cols.firstWhere(
      (c) => c.id == sortId,
      orElse: () => cols.first,
    );
    final sortedNodes = _getOrSortNodes(nodes, sortCol, sortAsc, groups);

    final headingStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final bodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final altRowColor = theme.colorScheme.surfaceContainerLow;
    final hoverColor = theme.colorScheme.surfaceContainerHighest;
    final selectedColor = theme.colorScheme.primary.withValues(alpha: 0.14);
    final accentColor = theme.colorScheme.primary;
    final primaryColor = theme.colorScheme.primary;
    final dragTargetColor = theme.colorScheme.primary.withValues(alpha: 0.10);

    final baseWidths = [
      for (final c in cols) widthOverrides[c.id] ?? c.defaultWidth,
    ];
    final totalWidth = baseWidths.fold<double>(0, (a, b) => a + b);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(selectionProvider.notifier).clear(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            _selectAllVisible(sortedNodes),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
            _selectAllVisible(sortedNodes),
      },
      child: Focus(
        focusNode: _focusNode,
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 0.0;

              final scaleToFit = fitToWidth && viewportWidth > totalWidth;
              final tableWidth = scaleToFit ? viewportWidth : totalWidth;
              final effectiveWidths = scaleToFit
                  ? [
                      for (final w in baseWidths)
                        w * viewportWidth / totalWidth,
                    ]
                  : baseWidths;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sticky header ────────────────────────────────────────
                  SizedBox(
                    width: viewportWidth,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        controller: _headerHorizontalController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: _buildHeader(
                          cols,
                          effectiveWidths,
                          tableWidth,
                          headingStyle,
                          primaryColor,
                          sortId,
                          sortAsc,
                          dragTargetColor,
                          (id) => _autoFitColumn(
                            _columnsById[id]!,
                            nodes,
                            groups,
                            bodyStyle,
                            headingStyle ?? bodyStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Virtualized scrollable body ──────────────────────────
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: ListView.builder(
                              controller: _verticalController,
                              itemExtent: _rowHeight,
                              itemCount: sortedNodes.length,
                              itemBuilder: (ctx, i) {
                                final node = sortedNodes[i];
                                return _MonitoringRow(
                                  key: ValueKey(node.id),
                                  node: node,
                                  index: i,
                                  columns: cols,
                                  widths: effectiveWidths,
                                  groups: groups,
                                  stripe: i.isOdd,
                                  selected: selection.contains(node.id),
                                  altRowColor: altRowColor,
                                  hoverColor: hoverColor,
                                  selectedColor: selectedColor,
                                  accentColor: accentColor,
                                  onTap: () {
                                    _focusNode.requestFocus();
                                    _onRowTap(i, sortedNodes);
                                  },
                                );
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
          ),
        ),
      ),
    );
  }
}

/// A single virtualized table row. Kept as its own `StatefulWidget` so mouse
/// hover repaints stay local to the row instead of rebuilding the whole table
/// (which carries the `LayoutBuilder` + nested `Scrollbar`s).
class _MonitoringRow extends StatefulWidget {
  final ProjectorNode node;
  final int index;
  final List<_Column> columns;
  final List<double> widths;
  final Map<String, ProjectorGroup> groups;
  final bool stripe;
  final bool selected;
  final Color altRowColor;
  final Color hoverColor;
  final Color selectedColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _MonitoringRow({
    super.key,
    required this.node,
    required this.index,
    required this.columns,
    required this.widths,
    required this.groups,
    required this.stripe,
    required this.selected,
    required this.altRowColor,
    required this.hoverColor,
    required this.selectedColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_MonitoringRow> createState() => _MonitoringRowState();
}

class _MonitoringRowState extends State<_MonitoringRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final bg = w.selected
        ? w.selectedColor
        : _hovered
        ? w.hoverColor
        : (w.stripe ? w.altRowColor : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: w.onTap,
        child: SizedBox(
          height: _kRowHeight,
          child: ColoredBox(
            color: bg,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < w.columns.length; i++)
                      SizedBox(
                        width: w.widths[i],
                        height: _kRowHeight,
                        child: Padding(
                          padding: _kCellPadding,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: w.columns[i].cell(context, w.node, w.groups),
                          ),
                        ),
                      ),
                  ],
                ),
                if (w.selected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: _kAccentWidth,
                      color: w.accentColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text that shows a tooltip with its full contents only when the rendered
/// text is actually truncated to fit its cell.
class _CellText extends StatelessWidget {
  final String text;
  final Color? color;

  const _CellText(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(TextStyle(color: color));
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflowing = tp.didExceedMaxLines;
        tp.dispose();

        final label = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: color == null ? null : TextStyle(color: color),
        );
        return overflowing
            ? Tooltip(message: text, child: label)
            : label;
      },
    );
  }
}

class _HeaderDragFeedback extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final Color color;

  const _HeaderDragFeedback({
    required this.label,
    required this.style,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: Text(label, style: style),
      ),
    );
  }
}
