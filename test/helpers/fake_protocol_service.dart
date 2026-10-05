import 'dart:async';

import 'package:projector_grid/core/services/panasonic_protocol_service.dart';

/// Scriptable stand-in for [PanasonicProtocolService] — never opens a socket.
class FakeProtocolService extends PanasonicProtocolService {
  /// What `pollProjectorTelemetry` returns, per IP. Unset IPs are offline.
  final Map<String, (ProbeResult, Map<String, dynamic>?)> pollResults = {};

  /// `checkConnection` result per IP. Unset IPs are unreachable.
  final Map<String, bool> reachable = {};

  /// `sendCommand` result per IP. Unset IPs succeed.
  final Map<String, bool> commandSucceeds = {};

  /// `sendCommand` to these IPs doesn't answer until the completer does —
  /// a projector that stopped responding mid-command.
  final Map<String, Completer<void>> holdCommands = {};

  /// `sendRawCommand` / `sendRawCommandPreservingErrorCodes` reply per
  /// command. Unset commands return null (transport failure).
  final Map<String, String?> rawResponses = {};

  /// Per-IP overrides of [rawResponses], checked first.
  final Map<String, Map<String, String?>> rawResponsesByIp = {};

  /// `sendQuickQuery` to these IPs doesn't answer until the completer does.
  final Map<String, Completer<void>> holdQueries = {};

  final List<(String ip, String cmd)> sentCommands = [];
  final List<(String ip, String cmd)> sentRaw = [];

  /// `sendQuickQuery` calls only (the signal watch's).
  final List<(String ip, String cmd)> sentQuick = [];
  int pollCount = 0;

  @override
  Future<bool> checkConnection(String ip, int port) async =>
      reachable[ip] ?? false;

  @override
  Future<bool> sendCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    sentCommands.add((ip, cmd));
    await holdCommands[ip]?.future;
    return commandSucceeds[ip] ?? true;
  }

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    sentRaw.add((ip, cmd));
    return _raw(ip, cmd);
  }

  @override
  Future<String?> sendRawCommandPreservingErrorCodes(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    sentRaw.add((ip, cmd));
    return _raw(ip, cmd);
  }

  @override
  Future<String?> sendQuickQuery(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    sentQuick.add((ip, cmd));
    await holdQueries[ip]?.future;
    return _raw(ip, cmd);
  }

  String? _raw(String ip, String cmd) {
    final perIp = rawResponsesByIp[ip];
    if (perIp != null && perIp.containsKey(cmd)) return perIp[cmd];
    if (rawResponses.containsKey(cmd)) return rawResponses[cmd];
    // Writes (`VXX:KEY=value`) succeed and echo back unless scripted.
    if (cmd.contains('=')) return cmd.substring(4);
    return null;
  }

  @override
  Future<(ProbeResult, Map<String, dynamic>?)> pollProjectorTelemetry(
    String ip,
    int port,
    String login,
    String password, {
    int concurrency = 2,
  }) async {
    pollCount++;
    return pollResults[ip] ?? (ProbeResult.offline, null);
  }
}

/// A full, healthy telemetry map as `pollProjectorTelemetry` returns it.
Map<String, dynamic> telemetry({
  String modelName = 'PT-RQ25K',
  String? serialNumber = 'SN123',
  String? power = 'POWI1=+00003',
  String? shutter = '0',
  String? input = 'HD1',
  String? signal = 'NSGS1=1080/60p',
  String? runtime = 'RTMS1=2185',
  String? lightRuntime = 'LRTS3=00:1577',
  String? intakeTemp = '0030/0086',
  String? exhaustTemp = '0041/0106',
  String? acVoltage = 'VMOI2=+00230',
  String? errors = 'ERRS2=',
  String? testPattern = '00',
}) => {
  'modelName': modelName,
  'serialNumber': serialNumber,
  'power': power,
  'shutter': shutter,
  'input': input,
  'signal': signal,
  'runtime': runtime,
  'lightRuntime': lightRuntime,
  'intakeTemp': intakeTemp,
  'exhaustTemp': exhaustTemp,
  'acVoltage': acVoltage,
  'errors': errors,
  'testPattern': testPattern,
};
