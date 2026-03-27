import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import '../../domain/projector_node.dart';

class MonitoringTable extends ConsumerStatefulWidget {
  const MonitoringTable({super.key});

  @override
  ConsumerState<MonitoringTable> createState() => _MonitoringTableState();
}

class _MonitoringTableState extends ConsumerState<MonitoringTable> {
  int _sortColumnIndex = 3; // Default: IP Address
  bool _sortAscending = true;

  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _headerHorizontalController = ScrollController();

  // Sort cache — avoids re-sorting on every build when nothing changed.
  List<ProjectorNode> _cachedSorted = const [];
  List<ProjectorNode>? _lastNodes;
  int _lastSortColumn = -1;
  bool _lastSortDir = true;

  // ── Column definitions ────────────────────────────────────────────────────

  static const List<String> _columnLabels = [
    'Connection',
    'Model',
    'Serial Number',
    'IP Address',
    'Power',
    'Shutter',
    'Input',
    'Signal',
    'Runtime',
    'Intake Temp',
    'Exhaust Temp',
    'AC Voltage',
    'Errors',
  ];

  static const List<double> _columnWidths = [
    130, // Connection
    160, // Model
    160, // Serial Number
    130, // IP Address
    130, // Power      — wider to fit icon + "STANDBY" with padding
    110, // Shutter
    90, // Input
    100, // Signal
    90, // Runtime
    130, // Intake Temp
    130, // Exhaust Temp
    110, // AC Voltage
    180, // Errors
  ];

  // Derived from _columnWidths so it stays in sync automatically.
  static final double _totalWidth = _columnWidths.reduce((a, b) => a + b);

  static const double _rowHeight = 40;
  static const double _headerHeight = 48;
  static const EdgeInsets _cellPadding = EdgeInsets.symmetric(horizontal: 16);

  // ── Const icon widgets — allocated once, reused across all rows ───────────

  static const _iconOnline = Icon(Icons.circle, size: 12, color: Colors.green);
  static const _iconOffline = Icon(Icons.circle, size: 12, color: Colors.red);
  static const _iconWarning = Icon(Icons.circle, size: 12, color: Colors.amber);
  static const _iconLock = Icon(
    Icons.lock_outline,
    size: 12,
    color: Colors.amber,
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
  static const _gap4 = SizedBox(width: 4);
  static const _gap6 = SizedBox(width: 6);

  // ── Scroll sync ───────────────────────────────────────────────────────────

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

  // ── Sort ──────────────────────────────────────────────────────────────────

  void _sort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  List<ProjectorNode> _sortNodes(List<ProjectorNode> nodes) {
    final sorted = List<ProjectorNode>.from(nodes);

    // Pre-parse every IP address once so the comparator closure does zero
    // list allocations — instead of 2 × O(n log n) allocations per sort.
    final ipCache = <String, List<int>>{};
    for (final node in sorted) {
      ipCache[node.ipAddress] ??= node.ipAddress
          .split('.')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();
    }

    int compareIp(String a, String b) {
      final aParts = ipCache[a]!;
      final bParts = ipCache[b]!;
      for (var i = 0; i < 4; i++) {
        final cmp = (aParts.elementAtOrNull(i) ?? 0).compareTo(
          bParts.elementAtOrNull(i) ?? 0,
        );
        if (cmp != 0) return cmp;
      }
      return 0;
    }

    sorted.sort((a, b) {
      final int cmp;
      switch (_sortColumnIndex) {
        case 0:
          int order(ConnectionStatus s) => switch (s) {
            ConnectionStatus.connected => 0,
            ConnectionStatus.unauthorized => 1,
            ConnectionStatus.offline => 2,
          };
          cmp = order(a.connectionStatus).compareTo(order(b.connectionStatus));
        case 1:
          cmp = a.name.compareTo(b.name);
        case 2:
          cmp = a.serialNumber.compareTo(b.serialNumber);
        case 3:
          cmp = compareIp(a.ipAddress, b.ipAddress);
        case 4:
          cmp = (a.powerStatus == PowerStatus.on ? 0 : 1).compareTo(
            b.powerStatus == PowerStatus.on ? 0 : 1,
          );
        case 5:
          cmp = (a.shutterStatus == ShutterStatus.open ? 0 : 1).compareTo(
            b.shutterStatus == ShutterStatus.open ? 0 : 1,
          );
        case 6:
          cmp = a.input.compareTo(b.input);
        case 7:
          cmp = a.signal.compareTo(b.signal);
        case 8:
          cmp = a.runtime.compareTo(b.runtime);
        case 9:
          cmp = a.intakeTemp.compareTo(b.intakeTemp);
        case 10:
          cmp = a.exhaustTemp.compareTo(b.exhaustTemp);
        case 11:
          cmp = a.acVoltage.compareTo(b.acVoltage);
        case 12:
          cmp = a.errors.compareTo(b.errors);
        default:
          cmp = compareIp(a.ipAddress, b.ipAddress);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  // Returns the cached sorted list when nodes and sort params are unchanged,
  // skipping the O(n log n) sort on every build that changes nothing.
  List<ProjectorNode> _getOrSortNodes(List<ProjectorNode> nodes) {
    if (identical(nodes, _lastNodes) &&
        _lastSortColumn == _sortColumnIndex &&
        _lastSortDir == _sortAscending) {
      return _cachedSorted;
    }
    _lastNodes = nodes;
    _lastSortColumn = _sortColumnIndex;
    _lastSortDir = _sortAscending;
    _cachedSorted = _sortNodes(nodes);
    return _cachedSorted;
  }

  // ── Cell builders ─────────────────────────────────────────────────────────

  static Widget _connectionCell(ProjectorNode node) {
    final isOnline = node.connectionStatus == ConnectionStatus.connected;
    final isUnauth = node.connectionStatus == ConnectionStatus.unauthorized;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOnline ? _iconOnline : (isUnauth ? _iconWarning : _iconOffline),
        _gap6,
        Text(
          isOnline
              ? 'Online'
              : isUnauth
              ? 'Auth Error'
              : 'Offline',
        ),
        if (isUnauth) ...[_gap4, _iconLock],
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
        Text(on ? 'ON' : 'STANDBY'),
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
        Text(open ? 'OPEN' : 'CLOSED'),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    TextStyle? headingStyle,
    Color primaryColor,
    List<double> widths,
    double tableWidth,
  ) {
    return SizedBox(
      height: _headerHeight,
      width: tableWidth,
      child: Row(
        children: List.generate(_columnLabels.length, (i) {
          final isSorted = _sortColumnIndex == i;
          return InkWell(
            onTap: () => _sort(i),
            child: SizedBox(
              width: widths[i],
              height: _headerHeight,
              child: Padding(
                padding: _cellPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_columnLabels[i], style: headingStyle),
                    if (isSorted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Body row ──────────────────────────────────────────────────────────────

  Widget _buildRow(
    ProjectorNode node,
    int index,
    Color altRowColor,
    List<double> widths,
  ) {
    return SizedBox(
      height: _rowHeight,
      child: ColoredBox(
        color: index.isOdd ? altRowColor : Colors.transparent,
        child: Row(
          children: [
            _cell(0, _connectionCell(node), widths),
            _cell(1, Text(node.name, overflow: TextOverflow.ellipsis), widths),
            _cell(2, Text(node.serialNumber, overflow: TextOverflow.ellipsis), widths),
            _cell(3, Text(node.ipAddress), widths),
            _cell(4, _powerCell(node), widths),
            _cell(5, _shutterCell(node), widths),
            _cell(6, Text(node.input, overflow: TextOverflow.ellipsis), widths),
            _cell(7, Text(node.signal, overflow: TextOverflow.ellipsis), widths),
            _cell(8, Text(node.runtime, overflow: TextOverflow.ellipsis), widths),
            _cell(9, Text(node.intakeTemp, overflow: TextOverflow.ellipsis), widths),
            _cell(10, Text(node.exhaustTemp, overflow: TextOverflow.ellipsis), widths),
            _cell(11, Text(node.acVoltage, overflow: TextOverflow.ellipsis), widths),
            _cell(12, Text(node.errors, overflow: TextOverflow.ellipsis), widths),
          ],
        ),
      ),
    );
  }

  // Wraps content in a fixed-width cell with standard horizontal padding.
  static Widget _cell(int colIndex, Widget content, List<double> widths) {
    return SizedBox(
      width: widths[colIndex],
      height: _rowHeight,
      child: Padding(
        padding: _cellPadding,
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final theme = Theme.of(context);
    final sortedNodes = _getOrSortNodes(nodes);

    final headingStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final altRowColor = theme.colorScheme.surfaceContainerLow;
    final primaryColor = theme.colorScheme.primary;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;

          // When the viewport is wider than the fixed column total, scale all
          // columns proportionally so the table fills the full width.
          final tableWidth =
              viewportWidth > _totalWidth ? viewportWidth : _totalWidth;
          final effectiveWidths = viewportWidth > _totalWidth
              ? List<double>.generate(
                  _columnWidths.length,
                  (i) => _columnWidths[i] * viewportWidth / _totalWidth,
                )
              : _columnWidths;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sticky header ──────────────────────────────────────────────
              // Clipped to viewport width; synced to body horizontal scroll
              // via _headerHorizontalController — same frame, no visual lag.
              SizedBox(
                width: viewportWidth,
                child: ClipRect(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: _buildHeader(
                      headingStyle,
                      primaryColor,
                      effectiveWidths,
                      tableWidth,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),

              // ── Virtualized scrollable body ────────────────────────────────
              // Layout: outer Scrollbar (vertical, depth==1 because
              // ListView.builder is nested inside SingleChildScrollView) wraps
              // inner Scrollbar (horizontal, default depth==0 from
              // SingleChildScrollView directly below it).
              //
              // ListView.builder only builds ~20 visible rows at any time,
              // regardless of total node count. Column widths are fixed
              // constants — no IntrinsicColumnWidth measurement pass.
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
                          itemBuilder: (ctx, i) => _buildRow(
                            sortedNodes[i],
                            i,
                            altRowColor,
                            effectiveWidths,
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
