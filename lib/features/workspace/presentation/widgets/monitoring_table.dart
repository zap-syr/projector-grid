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

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_syncHeader);
  }

  void _syncHeader() {
    if (_horizontalController.hasClients &&
        _horizontalController.position.hasPixels &&
        _headerHorizontalController.hasClients &&
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

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  int _compareIp(String a, String b) {
    final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 4; i++) {
      final cmp = (aParts.elementAtOrNull(i) ?? 0)
          .compareTo(bParts.elementAtOrNull(i) ?? 0);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  // Used by the sticky header DataTable. onSort is set so DataTable wraps each
  // label in Row(Flexible(label), SizedBox(2), _SortArrow(16px)) — adding 18px
  // to every heading cell whether sorted or not (_SortArrow is invisible but
  // still occupies space when visible:false).
  List<DataColumn> get _columns => [
        DataColumn(label: const Text('Connection'), onSort: _sort),
        DataColumn(label: const Text('Model'), onSort: _sort),
        DataColumn(label: const Text('Serial Number'), onSort: _sort),
        DataColumn(label: const Text('IP Address'), onSort: _sort),
        DataColumn(label: const Text('Power'), onSort: _sort),
        DataColumn(label: const Text('Shutter'), onSort: _sort),
        DataColumn(label: const Text('Input'), onSort: _sort),
        DataColumn(label: const Text('Signal'), onSort: _sort),
        DataColumn(label: const Text('Runtime'), onSort: _sort),
        DataColumn(label: const Text('Intake Temp'), onSort: _sort),
        DataColumn(label: const Text('Exhaust Temp'), onSort: _sort),
        DataColumn(label: const Text('AC Voltage'), onSort: _sort),
        DataColumn(label: const Text('Errors'), onSort: _sort),
      ];

  // Used by the body DataTable. onSort: null so no sort arrow is rendered —
  // but each label manually includes the same 2px + 16px invisible spacer that
  // DataTable adds when onSort != null. This keeps heading cell widths
  // identical to _columns so IntrinsicColumnWidth computes matching column
  // widths in both tables.
  static List<DataColumn> _buildBodyColumns() {
    const labels = [
      'Connection', 'Model', 'Serial Number', 'IP Address',
      'Power', 'Shutter', 'Input', 'Signal', 'Runtime',
      'Intake Temp', 'Exhaust Temp', 'AC Voltage', 'Errors',
    ];
    return labels
        .map(
          (text) => DataColumn(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text),
                const SizedBox(width: 2),
                const Opacity(
                  opacity: 0,
                  child: Icon(Icons.arrow_upward, size: 16),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  static final _bodyColumns = _buildBodyColumns();

  // ── Cell builders ──────────────────────────────────────────────────────────
  // Shared between header phantom rows and body rows so both DataTables
  // calculate identical column widths via IntrinsicColumnWidth.

  static Widget _connectionCell(ProjectorNode node) {
    final isOnline = node.connectionStatus == ConnectionStatus.connected;
    final isUnauth = node.connectionStatus == ConnectionStatus.unauthorized;
    final color =
        isOnline ? Colors.green : isUnauth ? Colors.amber : Colors.red;
    final label = isOnline ? 'Online' : isUnauth ? 'Auth Error' : 'Offline';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
        if (isUnauth) ...[
          const SizedBox(width: 4),
          const Icon(Icons.lock_outline, size: 12, color: Colors.amber),
        ],
      ],
    );
  }

  static Widget _powerCell(ProjectorNode node) {
    final on = node.powerStatus == PowerStatus.on;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.power_settings_new,
            size: 16, color: on ? Colors.green : Colors.red),
        const SizedBox(width: 4),
        Text(on ? 'ON' : 'STANDBY'),
      ],
    );
  }

  static Widget _shutterCell(ProjectorNode node) {
    final open = node.shutterStatus == ShutterStatus.open;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility,
            size: 16, color: open ? Colors.green : Colors.red),
        const SizedBox(width: 4),
        Text(open ? 'OPEN' : 'CLOSED'),
      ],
    );
  }

  static List<DataCell> _cells(ProjectorNode node) => [
        DataCell(_connectionCell(node)),
        DataCell(Text(node.name)),
        DataCell(Text(node.serialNumber)),
        DataCell(Text(node.ipAddress)),
        DataCell(_powerCell(node)),
        DataCell(_shutterCell(node)),
        DataCell(Text(node.input)),
        DataCell(Text(node.signal)),
        DataCell(Text(node.runtime)),
        DataCell(Text(node.intakeTemp)),
        DataCell(Text(node.exhaustTemp)),
        DataCell(Text(node.acVoltage)),
        DataCell(Text(node.errors)),
      ];

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final theme = Theme.of(context);

    // Apply sorting
    final sortedNodes = List<ProjectorNode>.from(nodes);
    sortedNodes.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          int order(ConnectionStatus s) => switch (s) {
                ConnectionStatus.connected => 0,
                ConnectionStatus.unauthorized => 1,
                ConnectionStatus.offline => 2,
              };
          cmp = order(a.connectionStatus).compareTo(order(b.connectionStatus));
          break;
        case 1:
          cmp = a.name.compareTo(b.name);
          break;
        case 2:
          cmp = a.serialNumber.compareTo(b.serialNumber);
          break;
        case 3:
          cmp = _compareIp(a.ipAddress, b.ipAddress);
          break;
        case 4:
          cmp = (a.powerStatus == PowerStatus.on ? 0 : 1)
              .compareTo(b.powerStatus == PowerStatus.on ? 0 : 1);
          break;
        case 5:
          cmp = (a.shutterStatus == ShutterStatus.open ? 0 : 1)
              .compareTo(b.shutterStatus == ShutterStatus.open ? 0 : 1);
          break;
        case 6:
          cmp = a.input.compareTo(b.input);
          break;
        case 7:
          cmp = a.signal.compareTo(b.signal);
          break;
        case 8:
          cmp = a.runtime.compareTo(b.runtime);
          break;
        case 9:
          cmp = a.intakeTemp.compareTo(b.intakeTemp);
          break;
        case 10:
          cmp = a.exhaustTemp.compareTo(b.exhaustTemp);
          break;
        case 11:
          cmp = a.acVoltage.compareTo(b.acVoltage);
          break;
        case 12:
          cmp = a.errors.compareTo(b.errors);
          break;
        default:
          cmp = _compareIp(a.ipAddress, b.ipAddress);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    final headingStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Container(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sticky header ──────────────────────────────────────────────
              // SizedBox clips the visible area to the viewport width.
              // SingleChildScrollView with NeverScrollableScrollPhysics lets
              // the DataTable render at its natural width without overflow
              // errors. _headerHorizontalController is synced to
              // _horizontalController via jumpTo in _syncHeader, which fires
              // during the body scroll listener — same frame, no visual lag.
              // Phantom data rows (height 0) force IntrinsicColumnWidth to
              // measure data cell widths, matching body column widths exactly.
              SizedBox(
                width: viewportWidth,
                child: ClipRect(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      // Must match the body's ConstrainedBox so RenderTable
                      // receives identical BoxConstraints and computes the
                      // same column widths in both DataTables.
                      constraints: BoxConstraints(minWidth: viewportWidth),
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingTextStyle: headingStyle,
                        // Phantom rows: collapsed to 0 height so invisible,
                        // but still measured for column width via
                        // IntrinsicColumnWidth.getMinIntrinsicWidth.
                        dataRowMinHeight: 0,
                        dataRowMaxHeight: 0,
                        columns: _columns,
                        rows: sortedNodes
                            .map((n) => DataRow(cells: _cells(n)))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),

              // ── Scrollable body ────────────────────────────────────────────
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    notificationPredicate: (notif) => notif.depth == 1,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: viewportWidth),
                          child: DataTable(
                            // Heading row collapsed to 0 height (invisible).
                            // Uses _bodyColumns (onSort: null, invisible spacer)
                            // so no sort arrow is rendered or bleeds into row 1.
                            headingRowHeight: 0,
                            headingTextStyle: headingStyle,
                            columns: _bodyColumns,
                            rows: sortedNodes
                                .map((n) => DataRow(cells: _cells(n)))
                                .toList(),
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
