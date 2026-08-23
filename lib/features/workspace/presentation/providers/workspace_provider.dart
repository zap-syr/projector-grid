import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import '../../domain/log_event.dart';
import '../../../../core/services/panasonic_protocol_service.dart';
import 'event_log_provider.dart';
import 'selection_provider.dart';
import 'poll_status_provider.dart';

part 'workspace_provider.g.dart';

@riverpod
class WorkspaceNotifier extends _$WorkspaceNotifier {
  final _protocolService = PanasonicProtocolService();
  Timer? _pollingTimer;
  int _pollingIntervalSeconds = 60;
  int _pollingGeneration = 0;
  bool _isPollingDisposed = false;

  static const int _maxHistorySize = 50;
  final List<_WorkspaceSnapshot> _undoStack = [];
  final List<_WorkspaceSnapshot> _redoStack = [];
  bool _isDragging = false;
  final List<Timer> _optimisticTimers = [];

  List<ProjectorGroup> _groups = [];
  List<ProjectorGroup> get groups => List.unmodifiable(_groups);

  @override
  List<ProjectorNode> build() {
    // Start polling when provider initializes
    _startPolling();

    // Make sure to clean up the timer when the provider is destroyed
    ref.onDispose(() {
      _isPollingDisposed = true;
      _pollingTimer?.cancel();
      for (final t in _optimisticTimers) {
        t.cancel();
      }
    });

    return [];
  }

  // ── Undo / Redo ──────────────────────────────────────────────────────────

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Strips transient fields so snapshots only capture user-editable state.
  List<ProjectorNode> _stripTransient(List<ProjectorNode> nodes) {
    return nodes
        .map(
          (n) => n.copyWith(
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
          ),
        )
        .toList();
  }

  _WorkspaceSnapshot _createSnapshot() {
    return _WorkspaceSnapshot(
      nodes: _stripTransient(state),
      groups: List.of(_groups),
    );
  }

  void _saveSnapshot() {
    _undoStack.add(_createSnapshot());
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

  void _restoreSnapshot(_WorkspaceSnapshot snapshot) {
    state = _mergeWithTelemetry(snapshot.nodes);
    _groups = List.of(snapshot.groups);
    ref.read(selectionProvider.notifier).clear();
    _notifyStateChanged();
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(_createSnapshot());
    _restoreSnapshot(_undoStack.removeLast());
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(_createSnapshot());
    _restoreSnapshot(_redoStack.removeLast());
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

  // ── Groups ─────────────────────────────────────────────────────────────

  void setGroups(List<ProjectorGroup> groups) {
    _groups = List.of(groups);
  }

  void addGroup(ProjectorGroup group) {
    _saveSnapshot();
    _groups = [..._groups, group];
    // Trigger state rebuild so listeners (UI) update.
    state = [...state];
  }

  void updateGroup(ProjectorGroup updated) {
    _saveSnapshot();
    _groups = _groups.map((g) => g.id == updated.id ? updated : g).toList();
    state = [...state];
  }

  void deleteGroup(String groupId) {
    _saveSnapshot();
    _groups = _groups.where((g) => g.id != groupId).toList();
    // Unassign nodes that belonged to the deleted group.
    state = state
        .map((n) => n.groupId == groupId ? n.copyWith(groupId: null) : n)
        .toList();
  }

  void assignNodesToGroup(List<String> nodeIds, String? groupId) {
    _saveSnapshot();
    final idSet = nodeIds.toSet();
    state = state
        .map((n) => idSet.contains(n.id) ? n.copyWith(groupId: groupId) : n)
        .toList();
  }

  /// Invoked whenever projector connection/status state changes (used by OSC to push status).
  void Function()? onStateChanged;

  void _notifyStateChanged() => onStateChanged?.call();

  void _logEvent(LogEvent event) {
    ref.read(eventLogProvider.notifier).log(event);
  }

  void _startPolling({int seconds = 60}) {
    _pollingIntervalSeconds = seconds;
    _pollingGeneration++; // invalidates any in-flight poll's reschedule
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _scheduleNextPoll(_pollingGeneration);
  }

  void _scheduleNextPoll(int generation) {
    _pollingTimer = Timer(Duration(seconds: _pollingIntervalSeconds), () async {
      await _pollAllProjectors();
      // Only reschedule if this generation is still the active one.
      // If _startPolling was called while we were awaiting, the generation
      // will have been bumped and we bail out — the new chain is already running.
      if (!_isPollingDisposed && _pollingGeneration == generation) {
        _notifyStateChanged();
        _scheduleNextPoll(generation);
      }
    });
  }

  Future<void> refreshAll() => _pollAllProjectors();

  void setNodes(List<ProjectorNode> nodes) {
    state = List<ProjectorNode>.from(nodes);
    ref.read(selectionProvider.notifier).clear();
  }

  void setPollingInterval(int seconds) {
    _startPolling(seconds: seconds);
  }

  /// Polls every node in batches of [_networkBatchSize] concurrently, rather
  /// than awaiting each node's full telemetry chain in sequence. A single
  /// node's own poll (probe + up to 10 telemetry commands) still happens as
  /// one connect-per-command sequence internally — batching only overlaps
  /// *different* nodes' polls with each other, which is what keeps a full
  /// cycle from taking N-times-longer as the projector count grows.
  Future<void> _pollAllProjectors() async {
    ref.read(pollStatusProvider.notifier).started();
    try {
      // We must poll ALL nodes, not just connected ones, so offline nodes can reconnect.
      // Also, we must not take a static copy of state into a loop, because state might change
      // while we are awaiting. We should iterate over the current IDs.
      final currentIds = state.map((n) => n.id).toList();

      for (
        var start = 0;
        start < currentIds.length;
        start += _networkBatchSize
      ) {
        final batchIds = currentIds.sublist(
          start,
          (start + _networkBatchSize).clamp(0, currentIds.length),
        );
        await Future.wait(
          batchIds.map((id) async {
            // Find the latest version of the node just before polling
            final nodeIndex = state.indexWhere((n) => n.id == id);
            if (nodeIndex == -1) return; // Node was deleted

            final node = state[nodeIndex];

            // Offline nodes get a cheap TCP check first (1.5s) before full probe.
            // All other states (connected, unprotected, unauthorized) go straight to
            // _pollSingleProjector so no intermediate state is written before auth is confirmed.
            if (node.connectionStatus == ConnectionStatus.offline) {
              await _checkAndSetNodeStatus(node.id, node.ipAddress, node.port);
            } else {
              await _pollSingleProjector(node);
            }
          }),
        );
      }
    } finally {
      ref.read(pollStatusProvider.notifier).completed();
    }
  }

  Future<void> _pollSingleProjector(ProjectorNode node) async {
    final oldStatus = node.connectionStatus;
    final oldErrors = node.errors;

    final probe = await _protocolService.probeProjector(
      node.ipAddress,
      node.port,
      node.login,
      node.password,
    );

    if (probe == ProbeResult.unauthorized) {
      if (oldStatus != ConnectionStatus.unauthorized) {
        _logEvent(
          LogEvent(
            severity: LogSeverity.error,
            type: LogEventType.connectivity,
            message: 'Authentication failed',
            projectorIp: node.ipAddress,
            projectorName: node.name,
          ),
        );
      }
      state = state
          .map(
            (n) => n.id == node.id
                ? n.copyWith(connectionStatus: ConnectionStatus.unauthorized)
                : n,
          )
          .toList();
      _notifyStateChanged();
      return;
    }

    if (probe == ProbeResult.offline) {
      if (oldStatus != ConnectionStatus.offline) {
        _logEvent(
          LogEvent(
            severity: LogSeverity.warning,
            type: LogEventType.connectivity,
            message: 'Went offline',
            projectorIp: node.ipAddress,
            projectorName: node.name,
          ),
        );
      }
      state = state
          .map(
            (n) => n.id == node.id
                ? n.copyWith(connectionStatus: ConnectionStatus.offline)
                : n,
          )
          .toList();
      _notifyStateChanged();
      return;
    }

    final targetStatus = probe == ProbeResult.unprotected
        ? ConnectionStatus.unprotected
        : ConnectionStatus.connected;

    final telemetry = await _protocolService.pollProjectorTelemetry(
      node.ipAddress,
      node.port,
      node.login,
      node.password,
    );

    if (telemetry != null) {
      if (oldStatus == ConnectionStatus.offline ||
          oldStatus == ConnectionStatus.unauthorized) {
        _logEvent(
          LogEvent(
            severity: LogSeverity.success,
            type: LogEventType.connectivity,
            message: 'Came online',
            projectorIp: node.ipAddress,
            projectorName: node.name,
          ),
        );
      }

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
          String signal = (telemetry['signal'] as String)
              .replaceAll('NSGS1=', '')
              .trim();
          if (signal == 'ER401' || signal == 'NO SIGNAL' || signal.isEmpty) {
            signal = 'NO SIGNAL';
          }

          // Parse Runtime
          String runtimeRaw = (telemetry['runtime'] as String)
              .replaceAll('RTMS1=', '')
              .trim();
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
          String voltageRaw = (telemetry['acVoltage'] as String)
              .replaceAll('VMOI2=', '')
              .trim();
          String voltage = '-';
          if (voltageRaw != 'ER401' && voltageRaw.length > 3) {
            voltage = '${voltageRaw.substring(3)}V';
          } else if (voltageRaw.length == 3) {
            voltage = '${voltageRaw}V';
          }

          // Parse Errors
          String errorsRaw = (telemetry['errors'] as String)
              .replaceAll('ERRS2=', '')
              .trim();
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
            connectionStatus: targetStatus,
          );
        }
        return n;
      }).toList();
      _notifyStateChanged();

      // Log new hardware errors detected during this poll
      final updatedNode = state.firstWhere(
        (n) => n.id == node.id,
        orElse: () => node,
      );
      if (updatedNode.errors != 'NO ERRORS' &&
          updatedNode.errors != '-' &&
          updatedNode.errors != oldErrors) {
        _logEvent(
          LogEvent(
            severity: LogSeverity.error,
            type: LogEventType.hardware,
            message: 'Hardware error: ${updatedNode.errors}',
            projectorIp: node.ipAddress,
            projectorName: node.name,
          ),
        );
      }
    } else {
      // If telemetry fails, mark as offline
      if (oldStatus != ConnectionStatus.offline) {
        _logEvent(
          LogEvent(
            severity: LogSeverity.warning,
            type: LogEventType.connectivity,
            message: 'Went offline',
            projectorIp: node.ipAddress,
            projectorName: node.name,
          ),
        );
      }
      state = state.map((n) {
        if (n.id == node.id) {
          return n.copyWith(connectionStatus: ConnectionStatus.offline);
        }
        return n;
      }).toList();
      _notifyStateChanged();
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
      if (config['status'] == 'online') {
        connStatus = ConnectionStatus.connected;
      } else if (config['status'] == 'unprotected') {
        connStatus = ConnectionStatus.unprotected;
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
        login: config['login'] ?? '',
        password: config['password'] ?? '',
        x: x,
        y: y,
        connectionStatus: connStatus,
      );
    }).toList();

    _saveSnapshot();
    state = [...state, ...newNodes];
    _notifyStateChanged();

    // Trigger an asynchronous ping for any newly added offline nodes
    for (var node in newNodes) {
      if (node.connectionStatus == ConnectionStatus.offline) {
        _checkAndSetNodeStatus(node.id, node.ipAddress, node.port);
      } else if (node.connectionStatus != ConnectionStatus.unauthorized) {
        _pollSingleProjector(node);
      }
    }
  }

  Future<void> _checkAndSetNodeStatus(String id, String ip, int port) async {
    final isOnline = await _protocolService.checkConnection(ip, port);
    if (isOnline) {
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(connectionStatus: ConnectionStatus.connected);
        }
        return node;
      }).toList();
      _notifyStateChanged();

      final targetNode = state.where((n) => n.id == id).firstOrNull;
      if (targetNode == null) return;
      await _pollSingleProjector(targetNode);
    }
  }

  Future<void> sendCommandToSelected(String cmd) {
    final selected = ref.read(selectionProvider);
    return _dispatchToNodes(state.where((n) => selected.contains(n.id)), cmd);
  }

  // Caps how many TCP connections _dispatchToNodes and _pollAllProjectors
  // open at once. Firing every node in one Future.wait would open one socket
  // per target with no ceiling — fine for a handful of projectors, but large
  // installs (100+) could push the controlling machine's open-file-descriptor
  // limit. Batches keep both operations effectively simultaneous while
  // bounding peak socket usage, the same way scanNetwork bounds concurrent
  // scan probes.
  static const _networkBatchSize = 100;

  /// Sends [cmd] to every reachable node in [nodes] concurrently in batches
  /// of [_networkBatchSize], rather than awaiting each one's TCP round-trip
  /// in sequence.
  Future<void> _dispatchToNodes(
    Iterable<ProjectorNode> nodes,
    String cmd,
  ) async {
    final targets = nodes
        .where(
          (n) =>
              n.connectionStatus == ConnectionStatus.connected ||
              n.connectionStatus == ConnectionStatus.unprotected,
        )
        .toList();

    for (var start = 0; start < targets.length; start += _networkBatchSize) {
      final batch = targets.sublist(
        start,
        (start + _networkBatchSize).clamp(0, targets.length),
      );
      await Future.wait(
        batch.map((node) async {
          final success = await _protocolService.sendCommand(
            node.ipAddress,
            node.port,
            node.login,
            node.password,
            cmd,
          );
          _logEvent(
            LogEvent(
              severity: success ? LogSeverity.info : LogSeverity.error,
              type: LogEventType.command,
              message: success
                  ? 'Sent: ${commandLabel(cmd)}'
                  : 'Failed: ${commandLabel(cmd)}',
              projectorIp: node.ipAddress,
              projectorName: node.name,
            ),
          );
          if (success) {
            _applyOptimisticUpdate(node.id, cmd);
          }
        }),
      );
    }
  }

  // Helper to fetch a single specific telemetry string without hitting the entire sequence
  Future<void> _pollSpecificTelemetry(
    ProjectorNode initialNode,
    String command,
  ) async {
    // Re-find the node to ensure we have the most current credentials/IP
    final idx = state.indexWhere((n) => n.id == initialNode.id);
    if (idx == -1) return;
    final node = state[idx];

    final response = await _protocolService.sendRawCommand(
      node.ipAddress,
      node.port,
      node.login,
      node.password,
      command,
    );

    if (response != null &&
        response != 'Timeout' &&
        !response.contains('Error') &&
        !response.contains('ERRA')) {
      state = state.map((n) {
        if (n.id == node.id) {
          if (command == 'QSH') {
            return n.copyWith(
              shutterStatus: response == '1'
                  ? ShutterStatus.closed
                  : ShutterStatus.open,
            );
          }
          // Add other specific telemetry command parses here if needed later
        }
        return n;
      }).toList();
    }
  }

  Future<void> sendCommandToGroup(String groupId, String cmd) =>
      _dispatchToNodes(state.where((n) => n.groupId == groupId), cmd);

  Future<void> sendCommandToAll(String cmd) => _dispatchToNodes(state, cmd);

  void _applyOptimisticUpdate(String nodeId, String cmd) {
    if (cmd == 'PON') {
      state = state
          .map(
            (n) => n.id == nodeId ? n.copyWith(powerStatus: PowerStatus.on) : n,
          )
          .toList();
      _notifyStateChanged();
      final node = state.where((n) => n.id == nodeId).firstOrNull;
      if (node != null) {
        late Timer t;
        t = Timer(const Duration(seconds: 8), () {
          _optimisticTimers.remove(t);
          _pollSpecificTelemetry(node, 'QSH');
        });
        _optimisticTimers.add(t);
      }
    } else if (cmd == 'POF') {
      state = state
          .map(
            (n) => n.id == nodeId
                ? n.copyWith(powerStatus: PowerStatus.standby)
                : n,
          )
          .toList();
      _notifyStateChanged();
      final node = state.where((n) => n.id == nodeId).firstOrNull;
      if (node != null) {
        late Timer t;
        t = Timer(const Duration(seconds: 5), () {
          _optimisticTimers.remove(t);
          _pollSpecificTelemetry(node, 'QSH');
        });
        _optimisticTimers.add(t);
      }
    } else if (cmd == 'OSH:0') {
      state = state
          .map(
            (n) => n.id == nodeId
                ? n.copyWith(shutterStatus: ShutterStatus.open)
                : n,
          )
          .toList();
      _notifyStateChanged();
    } else if (cmd == 'OSH:1') {
      state = state
          .map(
            (n) => n.id == nodeId
                ? n.copyWith(shutterStatus: ShutterStatus.closed)
                : n,
          )
          .toList();
      _notifyStateChanged();
    }
  }

  static const double _workspaceWidth = 3000.0;
  static const double _workspaceHeight = 3000.0;

  static double _clampX(double x) => x.clamp(0.0, _workspaceWidth - _cardWidth);
  static double _clampY(double y) =>
      y.clamp(0.0, _workspaceHeight - _cardHeight);

  void setNodePositionsFromDrag(
    String id,
    Offset totalDelta,
    Map<String, Offset> startPositions,
  ) {
    final targetNode = state.where((n) => n.id == id).firstOrNull;
    if (targetNode == null) return;
    final selected = ref.read(selectionProvider);
    if (selected.contains(id)) {
      state = state.map((node) {
        final start = startPositions[node.id];
        if (selected.contains(node.id) && start != null) {
          return node.copyWith(
            x: _clampX(start.dx + totalDelta.dx),
            y: _clampY(start.dy + totalDelta.dy),
          );
        }
        return node;
      }).toList();
    } else {
      final start = startPositions[id];
      if (start == null) return;
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(
            x: _clampX(start.dx + totalDelta.dx),
            y: _clampY(start.dy + totalDelta.dy),
          );
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
          connectionStatus: ConnectionStatus.offline,
        );
      }
      return node;
    }).toList();
    _notifyStateChanged();
    _checkAndSetNodeStatus(id, ip, 1024);
  }

  void deleteSelected() {
    _saveSnapshot();
    final selected = ref.read(selectionProvider);
    state = state.where((node) => !selected.contains(node.id)).toList();
    ref.read(selectionProvider.notifier).clear();
    _notifyStateChanged();
  }

  void deleteNode(String id) {
    _saveSnapshot();
    state = state.where((node) => node.id != id).toList();
    ref.read(selectionProvider.notifier).removeIds([id]);
    _notifyStateChanged();
  }

  void snapNodeToGrid(String id) {
    double snap(double val) => (val / 20).round() * 20.0;
    final targetNode = state.where((n) => n.id == id).firstOrNull;
    if (targetNode == null) return;
    final selected = ref.read(selectionProvider);
    if (selected.contains(id)) {
      state = state.map((node) {
        if (selected.contains(node.id)) {
          return node.copyWith(
            x: _clampX(snap(node.x)),
            y: _clampY(snap(node.y)),
          );
        }
        return node;
      }).toList();
    } else {
      state = state.map((node) {
        if (node.id == id) {
          return node.copyWith(
            x: _clampX(snap(node.x)),
            y: _clampY(snap(node.y)),
          );
        }
        return node;
      }).toList();
    }
  }

  void selectNodeOnDown(String id, {bool multiSelect = false}) {
    final targetNode = state.where((n) => n.id == id).firstOrNull;
    if (targetNode == null) return;
    final selectionNotifier = ref.read(selectionProvider.notifier);
    if (multiSelect) {
      selectionNotifier.toggle(id);
    } else {
      // If not selected, select it and deselect others
      // If already selected, do nothing on mouse down to allow dragging multiple
      if (!ref.read(selectionProvider).contains(id)) {
        selectionNotifier.selectOnly(id);
      }
    }
  }

  void selectNodeOnTap(String id, {bool multiSelect = false}) {
    if (!multiSelect) {
      // On mouse up without drag, if no modifier key is pressed, ensure only this node is selected
      ref.read(selectionProvider.notifier).selectOnly(id);
    }
  }

  void deselectAll() {
    ref.read(selectionProvider.notifier).clear();
  }

  void selectAll() {
    ref.read(selectionProvider.notifier).set(state.map((n) => n.id).toSet());
  }

  void selectNodesInGroup(String groupId) {
    final ids = state
        .where((n) => n.groupId == groupId)
        .map((n) => n.id)
        .toSet();
    ref.read(selectionProvider.notifier).set(ids);
  }

  Set<String> _preDragSelection = {};

  void startMarqueeSelection({bool append = false}) {
    if (append) {
      _preDragSelection = Set<String>.of(ref.read(selectionProvider));
    } else {
      _preDragSelection = {};
      ref.read(selectionProvider.notifier).clear();
    }
  }

  void endMarqueeSelection() {
    _preDragSelection.clear();
  }

  void selectNodesInRect(Rect selectionRect, {bool append = false}) {
    final next = <String>{};
    for (final node in state) {
      // Fixed size for cards for intersection logic (120x100 based on 6x5 grid cells)
      final nodeRect = Rect.fromLTWH(node.x, node.y, 120, 100);
      final isOverlapping = selectionRect.overlaps(nodeRect);

      if (append) {
        final wasSelected = _preDragSelection.contains(node.id);
        // If appending (Ctrl/Cmd pressed): toggle the state of overlapping items
        if (isOverlapping ? !wasSelected : wasSelected) {
          next.add(node.id);
        }
      } else {
        // Normal selection: only overlapping items are selected
        if (isOverlapping) next.add(node.id);
      }
    }
    ref.read(selectionProvider.notifier).set(next);
  }
}

class _WorkspaceSnapshot {
  final List<ProjectorNode> nodes;
  final List<ProjectorGroup> groups;

  const _WorkspaceSnapshot({required this.nodes, required this.groups});
}
