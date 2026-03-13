import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';

part 'workspace_provider.g.dart';

@riverpod
class WorkspaceNotifier extends _$WorkspaceNotifier {
  final _protocolService = PanasonicProtocolService();
  Timer? _pollingTimer;

  @override
  List<ProjectorNode> build() {
    // Start polling when provider initializes
    _startPolling();
    
    // Make sure to clean up the timer when the provider is destroyed
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    
    return [];
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _pollAllProjectors();
    });
  }

  Future<void> _pollAllProjectors() async {
    for (var node in state) {
      if (node.connectionStatus == ConnectionStatus.connected) {
        await _pollSingleProjector(node);
      }
    }
  }

  Future<void> _pollSingleProjector(ProjectorNode node) async {
    final telemetry = await _protocolService.pollProjectorTelemetry(node.ipAddress, node.port, node.login, node.password);
    
    if (telemetry != null) {
      state = state.map((n) {
        if (n.id == node.id) {
          return n.copyWith(
            name: telemetry['modelName'] ?? n.name,
            serialNumber: telemetry['serialNumber'] ?? n.serialNumber,
            powerStatus: telemetry['power'] == '001' ? PowerStatus.on : PowerStatus.standby,
            shutterStatus: telemetry['shutter'] == '1' ? ShutterStatus.closed : ShutterStatus.open,
            input: telemetry['input'] ?? n.input,
            signal: (telemetry['signal'] as String).replaceAll('NSGS1=', ''),
            runtime: (telemetry['runtime'] as String).replaceAll('RTMS1=', ''),
            intakeTemp: telemetry['intakeTemp'] ?? n.intakeTemp,
            exhaustTemp: telemetry['exhaustTemp'] ?? n.exhaustTemp,
            acVoltage: (telemetry['acVoltage'] as String).replaceAll('VMOI2=', ''),
            errors: (telemetry['errors'] as String).replaceAll('ERRS2=', ''),
            connectionStatus: ConnectionStatus.connected, // ensure it's marked connected
          );
        }
        return n;
      }).toList();
    } else {
      // If telemetry fails, mark as offline
      state = state.map((n) {
        if (n.id == node.id) {
          return n.copyWith(connectionStatus: ConnectionStatus.offline);
        }
        return n;
      }).toList();
    }
  }

  void addProjectors(List<Map<String, dynamic>> configs) {
    final rand = Random();
    double snap(double val) => (val / 20).round() * 20.0;
    
    final newNodes = configs.map((config) {
      ConnectionStatus connStatus = ConnectionStatus.offline;
      if (config['status'] == 'online' || config['status'] == 'protected') {
        connStatus = ConnectionStatus.connected;
      }

      return ProjectorNode(
        id: DateTime.now().microsecondsSinceEpoch.toString() + rand.nextInt(1000).toString(),
        name: config['name'] ?? 'Projector ${state.length + 1}',
        ipAddress: config['ip'] as String,
        port: config['port'] ?? 1024,
        login: config['login'] ?? 'admin1',
        password: config['password'] ?? 'panasonic',
        x: snap(100.0 + rand.nextInt(200)),
        y: snap(100.0 + rand.nextInt(200)),
        connectionStatus: connStatus,
      );
    }).toList();

    state = [...state, ...newNodes];

    // Trigger an asynchronous ping for any newly added offline nodes
    for (var node in newNodes) {
      if (node.connectionStatus == ConnectionStatus.offline) {
        _checkAndSetNodeStatus(node.id, node.ipAddress, node.port);
      } else {
        // If it's added as online, trigger an immediate full telemetry poll!
        _pollSingleProjector(node);
      }
    }
  }

  Future<void> _checkAndSetNodeStatus(String id, String ip, int port) async {
    final isOnline = await _protocolService.checkConnection(ip, port);
    if (isOnline) {
      // Temporarily mark connected so the UI shows green
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(connectionStatus: ConnectionStatus.connected);
        }
        return node;
      }).toList();
      
      // Grab the node with its credentials and fetch telemetry right away
      final targetNode = state.firstWhere((n) => n.id == id);
      await _pollSingleProjector(targetNode);
    }
  }

  void updateNodePosition(String id, double dx, double dy) {
    final targetNode = state.firstWhere((n) => n.id == id);
    if (targetNode.isSelected) {
      state = state.map((node) {
        if (node.isSelected) {
          return node.copyWith(x: node.x + dx, y: node.y + dy);
        }
        return node;
      }).toList();
    } else {
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(x: node.x + dx, y: node.y + dy);
        }
        return node;
      }).toList();
    }
  }

  void snapNodeToGrid(String id) {
    double snap(double val) => (val / 20).round() * 20.0;
    final targetNode = state.firstWhere((n) => n.id == id);
    if (targetNode.isSelected) {
      state = state.map((node) {
        if (node.isSelected) {
          return node.copyWith(x: snap(node.x), y: snap(node.y));
        }
        return node;
      }).toList();
    } else {
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(x: snap(node.x), y: snap(node.y));
        }
        return node;
      }).toList();
    }
  }

  void selectNodeOnDown(String id, {bool multiSelect = false}) {
    final targetNode = state.firstWhere((n) => n.id == id);
    if (multiSelect) {
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(isSelected: !node.isSelected);
        }
        return node;
      }).toList();
    } else {
      // If not selected, select it and deselect others
      // If already selected, do nothing on mouse down to allow dragging multiple
      if (!targetNode.isSelected) {
        state = state.map((node) {
          return node.copyWith(isSelected: node.id == id);
        }).toList();
      }
    }
  }

  void selectNodeOnTap(String id, {bool multiSelect = false}) {
    if (!multiSelect) {
      // On mouse up without drag, if no modifier key is pressed, ensure only this node is selected
      state = state.map((node) {
        return node.copyWith(isSelected: node.id == id);
      }).toList();
    }
  }

  void deselectAll() {
    state = state.map((node) => node.copyWith(isSelected: false)).toList();
  }

  void selectAll() {
    state = state.map((node) => node.copyWith(isSelected: true)).toList();
  }

  Set<String> _preDragSelection = {};

  void startMarqueeSelection({bool append = false}) {
    if (append) {
      _preDragSelection = state.where((n) => n.isSelected).map((n) => n.id).toSet();
    } else {
      _preDragSelection = {};
      state = state.map((node) => node.copyWith(isSelected: false)).toList();
    }
  }

  void endMarqueeSelection() {
    _preDragSelection.clear();
  }

  void selectNodesInRect(Rect selectionRect, {bool append = false}) {
    state = state.map((node) {
      // Fixed size for cards for intersection logic (120x100 based on 6x5 grid cells)
      final nodeRect = Rect.fromLTWH(node.x, node.y, 120, 100);
      final isOverlapping = selectionRect.overlaps(nodeRect);
      
      if (append) {
        final wasSelected = _preDragSelection.contains(node.id);
        // If appending (Ctrl/Cmd pressed): toggle the state of overlapping items
        return node.copyWith(isSelected: isOverlapping ? !wasSelected : wasSelected);
      } else {
        // Normal selection: only overlapping items are selected
        return node.copyWith(isSelected: isOverlapping);
      }
    }).toList();
  }
}
