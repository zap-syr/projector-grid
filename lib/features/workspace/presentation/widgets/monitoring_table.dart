import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/workspace_provider.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';

const double _kRowHeight = 40;
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
  final Widget Function(
    BuildContext,
    ProjectorNode,
    Map<String, ProjectorGroup>,
  )
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
    'Essentials': [
      'connection',
      'model',
      'ip',
      'power',
      'shutter',
      'input',
      'errors',
    ],
    'Thermal': [
      'connection',
      'model',
      'ip',
      'intake',
      'exhaust',
      'runtime',
      'voltage',
    ],
    'Signal': [
      'connection',
      'model',
      'ip',
      'input',
      'signal',
      'power',
      'shutter',
    ],
  };

  static List<String> get showAllColumns => allColumnIds;
}

class _MonitoringTableState extends ConsumerState<MonitoringTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _headerHorizontalController = ScrollController();

  // Sort cache — avoids re-sorting on every build when nothing changed.
  List<ProjectorNode> _cachedSorted = const [];
  List<ProjectorNode>? _lastNodes;
  String _lastSortId = '';
  bool _lastSortAsc = true;
  int _lastGroupsHash = 0;

  String? _dragOverColId;

  // Manual header-edge resize. Transient while a drag is in flight; the final
  // base width is persisted to `monitoringColumnWidths` on drag end so we don't
  // hit the settings file on every pointer move.
  String? _resizeColId;
  double _resizeStartEffective =
      0; // on-screen width of the column at drag start
  double _resizeOtherBase = 0; // summed base width of the other columns (fixed)
  double _resizeViewport = 0;
  bool _resizeScaling = false; // fit-to-window was scaling widths at drag start
  double _resizeAccumDx = 0; // accumulated screen delta since drag start

  // Layout metrics, refreshed from the density preset at the top of every
  // build so `_buildHeader` / `_autoFitColumn` (instance methods) and the row
  // widgets all read one consistent set.
  double _rowHeight = _kRowHeight;
  double _headerHeight = 48;
  EdgeInsets _cellPadding = _kCellPadding;
  double? _bodyFontSize;

  /// Row / header height, horizontal cell padding and body font size for each
  /// density. `standard` keeps the pre-density values so nothing shifts for
  /// users who never touch the setting.
  static ({double row, double header, double hpad, double? font})
  _densityMetrics(MonitoringDensity d) => switch (d) {
    MonitoringDensity.compact => (row: 32, header: 40, hpad: 10, font: 12.5),
    MonitoringDensity.standard => (
      row: _kRowHeight,
      header: 48,
      hpad: 16,
      font: null,
    ),
    MonitoringDensity.comfortable => (
      row: 52,
      header: 56,
      hpad: 20,
      font: null,
    ),
  };

  // ── Const icon widgets — allocated once, reused across all rows ───────────

  static const _iconOnline = Icon(Icons.circle, size: 12, color: Colors.green);
  static const _iconOffline = Icon(Icons.circle, size: 12, color: Colors.red);
  static const _iconWarning = Icon(Icons.circle, size: 12, color: Colors.amber);
  static const _iconLock = Icon(
    Icons.lock_outline,
    size: 12,
    color: Colors.amber,
  );
  static const _iconLockOpen = Icon(
    Icons.lock_open,
    size: 12,
    color: Colors.blue,
  );
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

  /// Readable amber for warning *text* — the pale `Colors.amber` used for the
  /// status dots/icons fails contrast when it carries a word on the light
  /// surface. Used for "Auth Error" and the warm-temperature tint.
  static const _warnText = Color(0xFFB26A00);

  // Hard-coded thermal severity thresholds (°C) for the Intake/Exhaust tint.
  // Intake tracks the projectors' 0–45 °C operating spec — units raise a
  // temperature fault around 45 °C and shut down near 50 °C. Exhaust is
  // `QTM:1`, the internal optics / around-lamp sensor, which Panasonic never
  // gives a numeric limit for (only the qualitative TEMP indicator), so these
  // are a deliberately high heuristic to avoid false alarms — tune once there
  // is field data.
  static const double _intakeWarmC = 40, _intakeHotC = 45;
  static const double _exhaustWarmC = 55, _exhaustHotC = 65;

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
      sortKey: (n, groups) => (_groupOf(n, groups)?.name ?? '￿').toLowerCase(),
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
      label: 'Projector Runtime',
      defaultWidth: 150,
      text: (n, _) => n.runtime,
      sortKey: (n, _) => _leadingNum(n.runtime),
      cell: (_, n, _) => _CellText(n.runtime),
    ),
    _Column(
      id: 'lightRuntime',
      label: 'Light Runtime',
      defaultWidth: 130,
      text: (n, _) => n.lightRuntime,
      sortKey: (n, _) => _leadingNum(n.lightRuntime),
      cell: (_, n, _) => _CellText(n.lightRuntime),
    ),
    _Column(
      id: 'intake',
      label: 'Intake Temp',
      defaultWidth: 130,
      text: (n, _) => n.intakeTemp,
      sortKey: (n, _) => _leadingNum(n.intakeTemp),
      cell: (_, n, _) => _CellText(
        n.intakeTemp,
        color: _tempTint(n.intakeTemp, exhaust: false),
      ),
    ),
    _Column(
      id: 'exhaust',
      label: 'Exhaust Temp',
      defaultWidth: 150,
      text: (n, _) => n.exhaustTemp,
      sortKey: (n, _) => _leadingNum(n.exhaustTemp),
      cell: (_, n, _) => _CellText(
        n.exhaustTemp,
        color: _tempTint(n.exhaustTemp, exhaust: true),
      ),
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
      text: (n, _) => n.errors == '-'
          ? '-'
          : (_errorsOk(n.errors) ? 'NO ERRORS' : n.errors),
      // Faulted rows sort before healthy ones (ascending); unpolled ('-')
      // sorts with healthy — matches statusSummaryProvider's own '-'
      // exclusion from warnings, instead of grouping unpolled rows with
      // genuinely faulted ones.
      sortKey: (n, _) =>
          n.errors == '-' ? '1-' : '${_errorsOk(n.errors) ? 1 : 0}${n.errors}',
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
    'lightRuntime',
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

  /// Flattens the sorted node list into a display list: with [groupBy] on, each
  /// group's nodes (still in the current sort order) are preceded by a
  /// `_HeaderEntry`; groups are ordered by name, ungrouped and orphaned nodes
  /// last. Stripe parity resets per cluster so every group starts light.
  static List<_Entry> _buildEntries(
    List<ProjectorNode> sorted,
    List<ProjectorGroup> groupList,
    bool groupBy,
  ) {
    if (!groupBy) {
      return [
        for (var i = 0; i < sorted.length; i++) _NodeEntry(sorted[i], i.isOdd),
      ];
    }
    final byGroup = <String?, List<ProjectorNode>>{};
    for (final n in sorted) {
      (byGroup[n.groupId] ??= []).add(n);
    }
    final named = [
      for (final g in groupList)
        if (byGroup.containsKey(g.id)) g,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final entries = <_Entry>[];
    void addCluster(ProjectorGroup? group, List<ProjectorNode> members) {
      entries.add(_HeaderEntry(group, members));
      for (var i = 0; i < members.length; i++) {
        entries.add(_NodeEntry(members[i], i.isOdd));
      }
    }

    for (final g in named) {
      addCluster(g, byGroup[g.id]!);
    }
    final trailing = [
      ...?byGroup[null],
      for (final e in byGroup.entries)
        if (e.key != null && !groupList.any((g) => g.id == e.key)) ...e.value,
    ];
    if (trailing.isNotEmpty) addCluster(null, trailing);
    return entries;
  }

  /// Worst-status roll-up for a group header: errors beat auth errors beat
  /// offline; healthy groups get no pill.
  static ({String text, Color color})? _worstStatus(List<ProjectorNode> m) {
    final errors = m
        .where((n) => n.errors != '-' && !_errorsOk(n.errors))
        .length;
    if (errors > 0) {
      return (
        text: '$errors error${errors == 1 ? '' : 's'}',
        color: Colors.red,
      );
    }
    final auth = m
        .where((n) => n.connectionStatus == ConnectionStatus.unauthorized)
        .length;
    if (auth > 0) {
      return (
        text: '$auth auth error${auth == 1 ? '' : 's'}',
        color: _warnText,
      );
    }
    final offline = m
        .where((n) => n.connectionStatus == ConnectionStatus.offline)
        .length;
    if (offline > 0) return (text: '$offline offline', color: Colors.red);
    return null;
  }

  /// Text tint for an Intake/Exhaust cell from its display string: `null`
  /// (default colour) when normal or unreadable (`-`, `Timeout`), amber past
  /// the warm threshold, red past the hot one. See `_intakeWarmC` etc.
  static Color? _tempTint(String display, {required bool exhaust}) {
    final n = _leadingNum(display);
    if (n == double.negativeInfinity) return null;
    final warm = exhaust ? _exhaustWarmC : _intakeWarmC;
    final hot = exhaust ? _exhaustHotC : _intakeHotC;
    if (n >= hot) return Colors.red;
    if (n >= warm) return _warnText;
    return null;
  }

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
    super.dispose();
  }

  // ── Sort ────────────────────────────────────────────────────────────────

  // Sort fires on a plain `onTap` — no `onDoubleTap` on the header label, so a
  // single click never waits out gesture disambiguation. Auto-fit lives on the
  // right-edge resize handle instead (double-click there), the way desktop
  // tables handle "double-click the column separator to fit".
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

  void _reorderColumn(
    List<_Column> current,
    String draggedId,
    String targetId,
  ) {
    if (draggedId == targetId) return;
    final ids = [for (final c in current) c.id];
    final from = ids.indexOf(draggedId);
    final to = ids.indexOf(targetId);
    if (from < 0 || to < 0) return;
    // Take `to` from the *original* list. Removing `draggedId` first and then
    // re-looking up the target shifts its index left by one whenever the drag
    // goes left→right, which lands the column right back where it started
    // (a silent no-op). Using the pre-removal index makes a left→right drop
    // land after the target and a right→left drop land before it.
    ids.removeAt(from);
    ids.insert(to, draggedId);
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

  // ── Column manual resize (header right-edge drag) ──────────────────────

  /// Maps the accumulated on-screen drag delta to the persisted *base* width
  /// for the column being resized. When fit-to-window was scaling widths at
  /// drag start, we invert the proportional scale so the header edge tracks the
  /// cursor: with the other columns' base total fixed at `B`, a base width `b`
  /// renders at `b * V / (B + b)`; solving that for the desired on-screen width
  /// `e` gives `b = e * B / (V - e)`. Past the point where the columns no
  /// longer fit (`e >= V - B`) scaling is off and base == on-screen width; the
  /// two branches meet continuously at that boundary.
  double _resizeBaseFor(double accumDx) {
    final desired = _resizeStartEffective + accumDx;
    final scalingLimit = _resizeViewport - _resizeOtherBase;
    final double base;
    if (_resizeScaling && _resizeOtherBase > 0 && desired < scalingLimit) {
      base = desired * _resizeOtherBase / (_resizeViewport - desired);
    } else {
      base = desired;
    }
    return base.clamp(_minColWidth, 600.0);
  }

  void _onResizeStart(
    String id,
    double startEffective,
    double otherBase,
    double viewport,
    bool scaling,
  ) {
    setState(() {
      _resizeColId = id;
      _resizeStartEffective = startEffective;
      _resizeOtherBase = otherBase;
      _resizeViewport = viewport;
      _resizeScaling = scaling;
      _resizeAccumDx = 0;
    });
  }

  void _onResizeUpdate(double dx) {
    if (_resizeColId == null) return;
    setState(() => _resizeAccumDx += dx);
  }

  void _onResizeEnd() {
    final id = _resizeColId;
    if (id == null) return;
    final width = _resizeBaseFor(_resizeAccumDx);
    setState(() {
      _resizeColId = null;
      _resizeAccumDx = 0;
    });
    ref.read(appSettingsProvider.notifier).setMonitoringColumnWidth(id, width);
  }

  // ── Cell builders ──────────────────────────────────────────────────────

  // Power / Shutter / Connection carry the icon's colour on the label too:
  // green = on / open / online, red = standby / closed / offline, amber =
  // auth error.
  static Widget _connectionCell(ProjectorNode node) {
    final isOnline = node.connectionStatus == ConnectionStatus.connected;
    final isUnprotected = node.connectionStatus == ConnectionStatus.unprotected;
    final isUnauth = node.connectionStatus == ConnectionStatus.unauthorized;
    final (label, color) = isOnline || isUnprotected
        ? ('Online', Colors.green)
        : isUnauth
        ? ('Auth Error', _warnText)
        : ('Offline', Colors.red);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOnline || isUnprotected
            ? _iconOnline
            : (isUnauth ? _iconWarning : _iconOffline),
        _gap6,
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
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
          child: Text(
            on ? 'ON' : 'STANDBY',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: on ? Colors.green : Colors.red),
          ),
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
          child: Text(
            open ? 'OPEN' : 'CLOSED',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: open ? Colors.green : Colors.red),
          ),
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
    void Function(String columnId) onResizeStart,
    ValueChanged<double> onResizeUpdate,
    VoidCallback onResizeEnd,
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

          final cell = DragTarget<String>(
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

          // Right-edge resize handle sits on top of the cell; its opaque hit
          // area takes the pointer before the reorder Draggable. Its hairline is
          // hidden at rest and only shown while hovered/dragged. Double-clicking
          // it auto-fits the column (the desktop "double-click the separator").
          return Stack(
            children: [
              cell,
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _ColumnResizeHandle(
                  height: _headerHeight,
                  onStart: () => onResizeStart(col.id),
                  onUpdate: onResizeUpdate,
                  onEnd: onResizeEnd,
                  onAutoFit: () => onAutoFit(col.id),
                ),
              ),
            ],
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
    final density = ref.watch(
      appSettingsProvider.select((s) => s.monitoringDensity),
    );
    final groupBy = ref.watch(
      appSettingsProvider.select((s) => s.monitoringGroupBy),
    );

    final dm = _densityMetrics(density);
    _rowHeight = dm.row;
    _headerHeight = dm.header;
    _cellPadding = EdgeInsets.symmetric(horizontal: dm.hpad);
    _bodyFontSize = dm.font;

    final theme = Theme.of(context);
    var cols = _resolveColumns(savedColumns);
    if (groupBy) {
      // The Group column is redundant once rows sit under group headers.
      final withoutGroup = [
        for (final c in cols)
          if (c.id != 'group') c,
      ];
      if (withoutGroup.isNotEmpty) cols = withoutGroup;
    }
    final sortCol = cols.firstWhere(
      (c) => c.id == sortId,
      orElse: () => cols.first,
    );
    final sortedNodes = _getOrSortNodes(nodes, sortCol, sortAsc, groups);
    final entries = _buildEntries(sortedNodes, groupList, groupBy);

    final headingStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final bodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final altRowColor = theme.colorScheme.surfaceContainerLow;
    final hoverColor = theme.colorScheme.surfaceContainerHighest;
    final primaryColor = theme.colorScheme.primary;
    final dragTargetColor = theme.colorScheme.primary.withValues(alpha: 0.10);

    final baseWidths = [
      for (final c in cols)
        c.id == _resizeColId
            ? _resizeBaseFor(_resizeAccumDx)
            : (widthOverrides[c.id] ?? c.defaultWidth),
    ];
    final totalWidth = baseWidths.fold<double>(0, (a, b) => a + b);

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;

          final scaleToFit = fitToWidth && viewportWidth > totalWidth;
          final tableWidth = scaleToFit ? viewportWidth : totalWidth;
          final effectiveWidths = scaleToFit
              ? [for (final w in baseWidths) w * viewportWidth / totalWidth]
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
                      (id) {
                        final idx = cols.indexWhere((c) => c.id == id);
                        if (idx < 0) return;
                        _onResizeStart(
                          id,
                          effectiveWidths[idx],
                          totalWidth - baseWidths[idx],
                          viewportWidth,
                          scaleToFit,
                        );
                      },
                      _onResizeUpdate,
                      _onResizeEnd,
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
                        child: DefaultTextStyle.merge(
                          style: _bodyFontSize == null
                              ? const TextStyle()
                              : TextStyle(fontSize: _bodyFontSize),
                          child: ListView.builder(
                            controller: _verticalController,
                            itemExtent: _rowHeight,
                            itemCount: entries.length,
                            itemBuilder: (ctx, i) {
                              final entry = entries[i];
                              if (entry is _HeaderEntry) {
                                return _GroupHeaderRow(
                                  group: entry.group,
                                  members: entry.members,
                                  width: tableWidth,
                                  height: _rowHeight,
                                  padding: _cellPadding,
                                );
                              }
                              final ne = entry as _NodeEntry;
                              return _MonitoringRow(
                                key: ValueKey(ne.node.id),
                                node: ne.node,
                                columns: cols,
                                widths: effectiveWidths,
                                groups: groups,
                                stripe: ne.stripe,
                                rowHeight: _rowHeight,
                                cellPadding: _cellPadding,
                                altRowColor: altRowColor,
                                hoverColor: hoverColor,
                              );
                            },
                          ),
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
    );
  }
}

/// A single virtualized table row. Kept as its own `StatefulWidget` so mouse
/// hover repaints stay local to the row instead of rebuilding the whole table
/// (which carries the `LayoutBuilder` + nested `Scrollbar`s).
class _MonitoringRow extends StatefulWidget {
  final ProjectorNode node;
  final List<_Column> columns;
  final List<double> widths;
  final Map<String, ProjectorGroup> groups;
  final bool stripe;
  final double rowHeight;
  final EdgeInsets cellPadding;
  final Color altRowColor;
  final Color hoverColor;

  const _MonitoringRow({
    super.key,
    required this.node,
    required this.columns,
    required this.widths,
    required this.groups,
    required this.stripe,
    required this.rowHeight,
    required this.cellPadding,
    required this.altRowColor,
    required this.hoverColor,
  });

  @override
  State<_MonitoringRow> createState() => _MonitoringRowState();
}

class _MonitoringRowState extends State<_MonitoringRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final bg = _hovered
        ? w.hoverColor
        : (w.stripe ? w.altRowColor : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: w.rowHeight,
        child: ColoredBox(
          color: bg,
          child: Row(
            children: [
              for (var i = 0; i < w.columns.length; i++)
                SizedBox(
                  width: w.widths[i],
                  height: w.rowHeight,
                  child: Padding(
                    padding: w.cellPadding,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: w.columns[i].cell(context, w.node, w.groups),
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

/// One line in the virtualized body list — either a node row or a group
/// header (only when "Merge into groups" is on).
sealed class _Entry {
  const _Entry();
}

final class _NodeEntry extends _Entry {
  final ProjectorNode node;

  /// Alt-row parity, reset per cluster so every group starts light.
  final bool stripe;

  const _NodeEntry(this.node, this.stripe);
}

final class _HeaderEntry extends _Entry {
  /// `null` for the trailing "Ungrouped" cluster.
  final ProjectorGroup? group;
  final List<ProjectorNode> members;

  const _HeaderEntry(this.group, this.members);
}

/// Non-collapsing cluster header shown above each group's rows when "Merge
/// into groups" is on. Same height as a data row so the list keeps a single
/// `itemExtent`.
class _GroupHeaderRow extends StatelessWidget {
  final ProjectorGroup? group;
  final List<ProjectorNode> members;
  final double width;
  final double height;
  final EdgeInsets padding;

  const _GroupHeaderRow({
    required this.group,
    required this.members,
    required this.width,
    required this.height,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = group;
    final accent = g == null ? scheme.outline : Color(g.color);
    final worst = _MonitoringTableState._worstStatus(members);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: g == null ? Colors.transparent : accent,
                  shape: BoxShape.circle,
                  border: g == null
                      ? Border.all(color: scheme.outline, width: 1.5)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  g?.name ?? 'Ungrouped',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${members.length} projector${members.length == 1 ? '' : 's'}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              if (worst != null) ...[
                const SizedBox(width: 8),
                _StatusPill(text: worst.text, color: worst.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
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
    final style = DefaultTextStyle.of(context).style
        .merge(TextStyle(color: color));
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
        return overflowing ? Tooltip(message: text, child: label) : label;
      },
    );
  }
}

/// Invisible drag zone on a header cell's right edge for manual column resize.
/// Opaque hit area so a horizontal drag here resizes rather than triggering the
/// cell's reorder `Draggable`. Nothing is drawn at rest — the table keeps its
/// flat look; on hover a 1 px hairline set [_ruleInset] px inside the column
/// edge fades in as a resize hint, and while dragging it is 2 px in `primary`.
/// Double-clicking the zone runs [onAutoFit] — the header label itself has no
/// double-tap, so a header click sorts with no disambiguation delay.
class _ColumnResizeHandle extends StatefulWidget {
  final double height;
  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onAutoFit;

  const _ColumnResizeHandle({
    required this.height,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onAutoFit,
  });

  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  /// Pointer hit-zone width, and the hairline's gap from the column edge.
  static const double _zoneWidth = 12;
  static const double _ruleInset = 3;

  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color ruleColor;
    final double ruleWidth;
    if (_dragging) {
      ruleColor = scheme.primary;
      ruleWidth = 2;
    } else if (_hover) {
      ruleColor = scheme.outlineVariant;
      ruleWidth = 1;
    } else {
      ruleColor = Colors.transparent;
      ruleWidth = 1;
    }

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
          width: _zoneWidth,
          height: widget.height,
          child: Padding(
            padding: const EdgeInsets.only(right: _ruleInset),
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: ruleWidth,
                height: widget.height,
                color: ruleColor,
              ),
            ),
          ),
        ),
      ),
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
