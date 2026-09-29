import 'package:projector_grid/core/services/panasonic_protocol_service.dart';

/// Scriptable stand-in for [PanasonicProtocolService] — never opens a socket.
class FakeProtocolService extends PanasonicProtocolService {
  /// What `pollProjectorTelemetry` returns, per IP. Unset IPs are offline.
  final Map<String, (ProbeResult, Map<String, dynamic>?)> pollResults = {};

  /// `checkConnection` result per IP. Unset IPs are unreachable.
  final Map<String, bool> reachable = {};

  /// `sendCommand` result per IP. Unset IPs succeed.
  final Map<String, bool> commandSucceeds = {};

  /// `sendRawCommand` / `sendRawCommandPreservingErrorCodes` reply per
  /// command. Unset commands return null (transport failure).
  final Map<String, String?> rawResponses = {};

  final List<(String ip, String cmd)> sentCommands = [];
  final List<(String ip, String cmd)> sentRaw = [];
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
    return _raw(cmd);
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
    return _raw(cmd);
  }

  String? _raw(String cmd) {
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
};
