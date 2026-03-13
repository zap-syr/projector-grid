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

  void _sort<T>(Comparable<T> Function(ProjectorNode node) getField, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final theme = Theme.of(context);

    // Apply sorting
    final sortedNodes = List<ProjectorNode>.from(nodes);
    sortedNodes.sort((a, b) {
      Comparable aValue;
      Comparable bValue;

      switch (_sortColumnIndex) {
        case 1: // Model
          aValue = a.name;
          bValue = b.name;
          break;
        case 2: // Serial Number
          aValue = a.serialNumber;
          bValue = b.serialNumber;
          break;
        case 3: // IP Address
          // Basic string sort for IP (for robust sorting, we'd pad octets, but this is okay for now)
          aValue = a.ipAddress;
          bValue = b.ipAddress;
          break;
        case 8: // Runtime
          aValue = a.runtime;
          bValue = b.runtime;
          break;
        default:
          aValue = a.ipAddress;
          bValue = b.ipAddress;
          break;
      }

      return _sortAscending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
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
              const DataColumn(label: Text('Connection')),
              DataColumn(
                label: const Text('Model'),
                onSort: (columnIndex, ascending) => _sort<String>((n) => n.name, columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('Serial Number'),
                onSort: (columnIndex, ascending) => _sort<String>((n) => n.serialNumber, columnIndex, ascending),
              ),
              DataColumn(
                label: const Text('IP Address'),
                onSort: (columnIndex, ascending) => _sort<String>((n) => n.ipAddress, columnIndex, ascending),
              ),
              const DataColumn(label: Text('Power')),
              const DataColumn(label: Text('Shutter')),
              const DataColumn(label: Text('Input')),
              const DataColumn(label: Text('Signal')),
              DataColumn(
                label: const Text('Runtime'),
                onSort: (columnIndex, ascending) => _sort<String>((n) => n.runtime, columnIndex, ascending),
              ),
              const DataColumn(label: Text('Intake Temp')),
              const DataColumn(label: Text('Exhaust Temp')),
              const DataColumn(label: Text('AC Voltage')),
              const DataColumn(label: Text('Errors')),
            ],
            rows: sortedNodes.map((node) {
              final isOnline = node.connectionStatus == ConnectionStatus.connected;
              final isPowerOn = node.powerStatus == PowerStatus.on;
              final isShutterOpen = node.shutterStatus == ShutterStatus.open;

              return DataRow(
                cells: [
                  DataCell(Icon(
                    Icons.circle,
                    size: 12,
                    color: isOnline ? Colors.green : Colors.red,
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
