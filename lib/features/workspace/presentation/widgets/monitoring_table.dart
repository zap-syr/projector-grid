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
  int _sortColumnIndex = 3; // Default to IP Address (index 3)
  bool _sortAscending = true;

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
      final cmp = (aParts.elementAtOrNull(i) ?? 0).compareTo(bParts.elementAtOrNull(i) ?? 0);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final theme = Theme.of(context);

    // Apply sorting
    final sortedNodes = List<ProjectorNode>.from(nodes);
    sortedNodes.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // Connection: connected=0, unauthorized=1, offline=2
          int connOrder(ConnectionStatus s) => switch (s) {
            ConnectionStatus.connected => 0,
            ConnectionStatus.unauthorized => 1,
            ConnectionStatus.offline => 2,
          };
          cmp = connOrder(a.connectionStatus).compareTo(connOrder(b.connectionStatus));
          break;
        case 1: // Model
          cmp = a.name.compareTo(b.name);
          break;
        case 2: // Serial Number
          cmp = a.serialNumber.compareTo(b.serialNumber);
          break;
        case 3: // IP Address
          cmp = _compareIp(a.ipAddress, b.ipAddress);
          break;
        case 4: // Power
          cmp = (a.powerStatus == PowerStatus.on ? 0 : 1)
              .compareTo(b.powerStatus == PowerStatus.on ? 0 : 1);
          break;
        case 5: // Shutter
          cmp = (a.shutterStatus == ShutterStatus.open ? 0 : 1)
              .compareTo(b.shutterStatus == ShutterStatus.open ? 0 : 1);
          break;
        case 6: // Input
          cmp = a.input.compareTo(b.input);
          break;
        case 7: // Signal
          cmp = a.signal.compareTo(b.signal);
          break;
        case 8: // Runtime
          cmp = a.runtime.compareTo(b.runtime);
          break;
        case 9: // Intake Temp
          cmp = a.intakeTemp.compareTo(b.intakeTemp);
          break;
        case 10: // Exhaust Temp
          cmp = a.exhaustTemp.compareTo(b.exhaustTemp);
          break;
        case 11: // AC Voltage
          cmp = a.acVoltage.compareTo(b.acVoltage);
          break;
        case 12: // Errors
          cmp = a.errors.compareTo(b.errors);
          break;
        default:
          cmp = _compareIp(a.ipAddress, b.ipAddress);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingTextStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            columns: [
              DataColumn(
                label: const Text('Connection'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Model'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Serial Number'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('IP Address'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Power'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Shutter'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Input'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Signal'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Runtime'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Intake Temp'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Exhaust Temp'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('AC Voltage'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Errors'),
                onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
              ),
            ],
            rows: sortedNodes.map((node) {
              final isOnline = node.connectionStatus == ConnectionStatus.connected;
              final isUnauthorized = node.connectionStatus == ConnectionStatus.unauthorized;
              final isPowerOn = node.powerStatus == PowerStatus.on;
              final isShutterOpen = node.shutterStatus == ShutterStatus.open;

              final connectionDotColor = isOnline
                  ? Colors.green
                  : isUnauthorized
                      ? Colors.amber
                      : Colors.red;
              final connectionLabel = isOnline
                  ? 'Online'
                  : isUnauthorized
                      ? 'Auth Error'
                      : 'Offline';

              return DataRow(
                cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 12, color: connectionDotColor),
                      const SizedBox(width: 6),
                      Text(connectionLabel),
                      if (isUnauthorized) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_outline, size: 12, color: Colors.amber),
                      ],
                    ],
                  )),
                  DataCell(Text(node.name)),
                  DataCell(Text(node.serialNumber)),
                  DataCell(Text(node.ipAddress)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.power_settings_new, size: 16, color: isPowerOn ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(isPowerOn ? 'ON' : 'STANDBY'),
                    ],
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 16, color: isShutterOpen ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(isShutterOpen ? 'OPEN' : 'CLOSED'),
                    ],
                  )),
                  DataCell(Text(node.input)),
                  DataCell(Text(node.signal)),
                  DataCell(Text(node.runtime)),
                  DataCell(Text(node.intakeTemp)),
                  DataCell(Text(node.exhaustTemp)),
                  DataCell(Text(node.acVoltage)),
                  DataCell(Text(node.errors)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
