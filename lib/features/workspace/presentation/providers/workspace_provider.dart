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

  static const int _maxHistorySize = 50;
  final List<List<ProjectorNode>> _undoStack = [];
  final List<List<ProjectorNode>> _redoStack = [];
  bool _isDragging = false;

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

  // ── Undo / Redo ──────────────────────────────────────────────────────────

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Strips transient fields so snapshots only capture user-editable state.
  List<ProjectorNode> _stripTransient(List<ProjectorNode> nodes) {
    return nodes.map((n) => n.copyWith(
      isSelected: false,
      connectionStatus: ConnectionStatus.offline,
      powerStatus: PowerStatus.standby,
      shutterStatus: ShutterStatus.closed,
      serialNumber: '-',
      runtime: '-',
      intakeTemp: '-',
      exhaustTemp: '-',
      acVoltage: '-',
      errors: '-',
      input: '-',
      signal: '-',
    )).toList();
  }

  void _saveSnapshot() {
    _undoStack.add(_stripTransient(state));
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Restores a snapshot while preserving live telemetry from current state.
  List<ProjectorNode> _mergeWithTelemetry(List<ProjectorNode> snapshot) {
    final currentMap = {for (var n in state) n.id: n};
    return snapshot.map((saved) {
      final live = currentMap[saved.id];
      if (live != null) {
        return saved.copyWith(
          name: live.name,
          connectionStatus: live.connectionStatus,
          powerStatus: live.powerStatus,
          shutterStatus: live.shutterStatus,
          serialNumber: live.serialNumber,
          runtime: live.runtime,
          intakeTemp: live.intakeTemp,
          exhaustTemp: live.exhaustTemp,
          acVoltage: live.acVoltage,
          errors: live.errors,
          input: live.input,
          signal: live.signal,
        );
      }
      return saved;
    }).toList();
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(_stripTransient(state));
    final snapshot = _undoStack.removeLast();
    state = _mergeWithTelemetry(snapshot);
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(_stripTransient(state));
    final snapshot = _redoStack.removeLast();
    state = _mergeWithTelemetry(snapshot);
  }

  /// Call before starting a node drag to capture pre-move state.
  void saveBeforeMove() {
    if (!_isDragging) {
      _isDragging = true;
      _saveSnapshot();
    }
  }

  /// Call when drag ends to allow the next drag to save a new snapshot.
  void endMove() {
    _isDragging = false;
  }

  void _startPolling({int seconds = 60}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      await _pollAllProjectors();
    });
  }

  Future<void> refreshAll() => _pollAllProjectors();

  void setNodes(List<ProjectorNode> nodes) {
    state = List<ProjectorNode>.from(nodes);
  }

  void setPollingInterval(int seconds) {
    _startPolling(seconds: seconds);
  }

  Future<void> _pollAllProjectors() async {
    // We must poll ALL nodes, not just connected ones, so offline nodes can reconnect.
    // Also, we must not take a static copy of state into a loop, because state might change
    // while we are awaiting. We should iterate over the current IDs.
    final currentIds = state.map((n) => n.id).toList();
    
    for (var id in currentIds) {
      // Find the latest version of the node just before polling
      final nodeIndex = state.indexWhere((n) => n.id == id);
      if (nodeIndex == -1) continue; // Node was deleted
      
      final node = state[nodeIndex];
      
      // If it's connected, fetch full telemetry. If offline, just ping it first to see if it's back.
      if (node.connectionStatus == ConnectionStatus.connected) {
        await _pollSingleProjector(node);
      } else {
        await _checkAndSetNodeStatus(node.id, node.ipAddress, node.port);
      }
    }
  }

  Future<void> _pollSingleProjector(ProjectorNode node) async {
    final probe = await _protocolService.probeProjector(
      node.ipAddress, node.port, node.login, node.password,
    );

    if (probe == ProbeResult.unauthorized) {
      state = state.map((n) => n.id == node.id
          ? n.copyWith(connectionStatus: ConnectionStatus.unauthorized)
          : n).toList();
      return;
    }

    if (probe == ProbeResult.offline) {
      state = state.map((n) => n.id == node.id
          ? n.copyWith(connectionStatus: ConnectionStatus.offline)
          : n).toList();
      return;
    }

    final telemetry = await _protocolService.pollProjectorTelemetry(
      node.ipAddress,
      node.port,
      node.login,
      node.password,
    );

    if (telemetry != null) {
      state = state.map((n) {
        if (n.id == node.id) {
          // Parse Input
          String input = telemetry['input'] ?? n.input;
          if (input == 'HD1') {
            input = 'HDMI 1';
          } else if (input == 'HD2') {
            input = 'HDMI 2';
          } else if (input == 'SD1') {
            input = 'SDI 1';
          } else if (input == 'SD2') {
            input = 'SDI 2';
          } else if (input == 'DL1') {
            input = 'DIGITAL LINK';
          } else if (input == 'DVI') {
            input = 'DVI-D';
          } else if (input == 'DP1') {
            input = 'DISPLAY PORT';
          }

          // Parse Signal
          String signal = (telemetry['signal'] as String).replaceAll('NSGS1=', '').trim();
          if (signal == 'ER401' || signal == 'NO SIGNAL' || signal.isEmpty) {
            signal = 'NO SIGNAL';
          }

          // Parse Runtime
          String runtimeRaw = (telemetry['runtime'] as String).replaceAll('RTMS1=', '').trim();
          String runtime = runtimeRaw.isEmpty || runtimeRaw == 'ER401'
              ? '-'
              : '${runtimeRaw}H';

          // Parse Temps
          String intake = telemetry['intakeTemp'] ?? n.intakeTemp;
          if (intake.contains('/')) {
            intake = '${intake.split('/')[0].substring(2)}°C';
          } else if (intake == 'ER401') {
            intake = '-';
          }

          String exhaust = telemetry['exhaustTemp'] ?? n.exhaustTemp;
          if (exhaust.contains('/')) {
            exhaust = '${exhaust.split('/')[0].substring(2)}°C';
          } else if (exhaust == 'ER401') {
            exhaust = '-';
          }

          // Parse Voltage
          String voltageRaw = (telemetry['acVoltage'] as String).replaceAll('VMOI2=', '').trim();
          String voltage = '-';
          if (voltageRaw != 'ER401' && voltageRaw.length > 3) {
            voltage = '${voltageRaw.substring(3)}V';
          } else if (voltageRaw.length == 3) {
            voltage = '${voltageRaw}V';
          }

          // Parse Errors
          String errorsRaw = (telemetry['errors'] as String).replaceAll('ERRS2=', '').trim();
          String errors = errorsRaw.isEmpty ? 'NO ERRORS' : errorsRaw;

          return n.copyWith(
            name: telemetry['modelName'] ?? n.name,
            serialNumber: telemetry['serialNumber'] ?? n.serialNumber,
            powerStatus: telemetry['power'] == '001'
                ? PowerStatus.on
                : PowerStatus.standby,
            shutterStatus: telemetry['shutter'] == '1'
                ? ShutterStatus.closed
                : ShutterStatus.open,
            input: input,
            signal: signal,
            runtime: runtime,
            intakeTemp: intake,
            exhaustTemp: exhaust,
            acVoltage: voltage,
            errors: errors,
            connectionStatus: ConnectionStatus.connected,
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

  static const double _cardWidth = 120;
  static const double _cardHeight = 100;
  static const double _gridOriginX = 40;
  static const double _gridOriginY = 40;
  static const double _gridHGap = 20;
  static const double _gridVGap = 40;
  static const int _gridMaxCols = 10;

  (double, double) _gridPosition(int index) {
    final col = index % _gridMaxCols;
    final row = index ~/ _gridMaxCols;
    return (
      _gridOriginX + col * (_cardWidth + _gridHGap),
      _gridOriginY + row * (_cardHeight + _gridVGap),
    );
  }

  void addProjectors(List<Map<String, dynamic>> configs) {
    final rand = Random();

    int idx = 0;
    final newNodes = configs.map((config) {
      ConnectionStatus connStatus = ConnectionStatus.offline;
      if (config['status'] == 'online' || config['status'] == 'protected') {
        connStatus = ConnectionStatus.connected;
      } else if (config['status'] == 'auth_error') {
        connStatus = ConnectionStatus.unauthorized;
      }

      final (x, y) = _gridPosition(idx);
      idx++;
      return ProjectorNode(
        id: '${DateTime.now().microsecondsSinceEpoch}_${rand.nextInt(100000)}_$idx',
        name: config['name'] ?? 'Projector ${state.length + idx}',
        ipAddress: config['ip'] as String,
        port: config['port'] ?? 1024,
        login: config['login'] ?? 'admin1',
        password: config['password'] ?? 'panasonic',
        x: x,
        y: y,
        connectionStatus: connStatus,
      );
    }).toList();

    _saveSnapshot();
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

  Future<void> sendCommandToSelected(String cmd) async {
    final selectedNodes = state.where((n) => n.isSelected).toList();
    for (var node in selectedNodes) {
      if (node.connectionStatus == ConnectionStatus.connected) {
        final success = await _protocolService.sendCommand(
          node.ipAddress,
          node.port,
          node.login,
          node.password,
          cmd,
        );
        
        // Optimistic UI updates for specific known commands
        if (success) {
          if (cmd == 'PON') {
            state = state.map((n) => n.id == node.id ? n.copyWith(powerStatus: PowerStatus.on) : n).toList();
            // Projector warming up: check shutter status in 8 seconds
            Future.delayed(const Duration(seconds: 8), () async {
              _pollSpecificTelemetry(node, 'QSH');
            });
          } else if (cmd == 'POF') {
            state = state.map((n) => n.id == node.id ? n.copyWith(powerStatus: PowerStatus.standby) : n).toList();
            // Projector cooling down: check shutter status in 5 seconds
            Future.delayed(const Duration(seconds: 5), () async {
              _pollSpecificTelemetry(node, 'QSH');
            });
          } else if (cmd == 'OSH:0') {
            state = state.map((n) => n.id == node.id ? n.copyWith(shutterStatus: ShutterStatus.open) : n).toList();
          } else if (cmd == 'OSH:1') {
            state = state.map((n) => n.id == node.id ? n.copyWith(shutterStatus: ShutterStatus.closed) : n).toList();
          }
        }
      }
    }
  }

  // Helper to fetch a single specific telemetry string without hitting the entire sequence
  Future<void> _pollSpecificTelemetry(ProjectorNode initialNode, String command) async {
    // Re-find the node to ensure we have the most current credentials/IP
    final idx = state.indexWhere((n) => n.id == initialNode.id);
    if (idx == -1) return;
    final node = state[idx];

    final response = await _protocolService.sendRawCommand(
      node.ipAddress, 
      node.port, 
      node.login, 
      node.password, 
      command
    );

    if (response != null && response != 'Timeout' && !response.contains('Error') && !response.contains('ERRA')) {
      state = state.map((n) {
        if (n.id == node.id) {
          if (command == 'QSH') {
             return n.copyWith(shutterStatus: response == '1' ? ShutterStatus.closed : ShutterStatus.open);
          }
          // Add other specific telemetry command parses here if needed later
        }
        return n;
      }).toList();
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

  void updateNode(String id, String ip, String login, String password) {
    _saveSnapshot();
    state = state.map((node) {
      if (node.id == id) {
        return node.copyWith(
          ipAddress: ip,
          login: login,
          password: password,
          connectionStatus: ConnectionStatus.offline, // Will be pinged on next poll or we can ping now
        );
      }
      return node;
    }).toList();
    _checkAndSetNodeStatus(id, ip, 1024);
  }

  void deleteSelected() {
    _saveSnapshot();
    state = state.where((node) => !node.isSelected).toList();
  }

  void deleteNode(String id) {
    _saveSnapshot();
    state = state.where((node) => node.id != id).toList();
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
      _preDragSelection = state
          .where((n) => n.isSelected)
          .map((n) => n.id)
          .toSet();
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
        return node.copyWith(
          isSelected: isOverlapping ? !wasSelected : wasSelected,
        );
      } else {
        // Normal selection: only overlapping items are selected
        return node.copyWith(isSelected: isOverlapping);
      }
    }).toList();
  }
}
