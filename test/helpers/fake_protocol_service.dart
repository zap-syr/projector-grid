import 'dart:async';
import 'dart:typed_data';

import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

import 'fake_warp_projector.dart';

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

  /// `pollProjectorTelemetry` to these IPs doesn't answer until the
  /// completer does.
  final Map<String, Completer<void>> holdPolls = {};

  /// `sendRawCommand` / `sendRawCommandPreservingErrorCodes` reply per
  /// command. Unset commands return null (transport failure).
  final Map<String, String?> rawResponses = {};

  /// `sendRawCommand` to these IPs doesn't answer until the completer does.
  final Map<String, Completer<void>> holdRaw = {};

  /// Per-IP overrides of [rawResponses], checked first.
  final Map<String, Map<String, String?>> rawResponsesByIp = {};

  /// `sendQuickQuery` to these IPs doesn't answer until the completer does.
  final Map<String, Completer<void>> holdQueries = {};

  /// The warp tables of each projector that has been asked for with
  /// [warpFor]. Binary frames are answered from them, and so are the
  /// `GMMI0`, `GDTS1` and `GGNS1` commands that [rawResponses] does not script
  /// (an IP without one keeps the plain behaviour).
  final Map<String, FakeWarpProjector> warpProjectors = {};

  /// The warp tables of [ip], created on first use. Its injection hooks
  /// script a failed transfer.
  FakeWarpProjector warpFor(String ip) =>
      warpProjectors.putIfAbsent(ip, FakeWarpProjector.new);

  /// Every `sendBinaryCommand` call.
  final List<(String ip, Uint8List frame)> sentBinary = [];

  /// `sendBinaryCommand` to these IPs doesn't answer until the completer does.
  final Map<String, Completer<void>> holdBinary = {};

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
    final warp = warpProjectors[ip];
    if (warp != null) {
      if (warp.dropsAscii(cmd)) return false;
      warp.handleAscii(cmd);
    }
    return commandSucceeds[ip] ?? true;
  }

  @override
  Future<Uint8List> sendBinaryCommand(
    String ip,
    int port,
    String login,
    String password,
    Uint8List frame,
  ) async {
    sentBinary.add((ip, frame));
    await holdBinary[ip]?.future;
    final line = warpFor(ip).handleBinary(frame);
    if (line == null) throw const WarpTransportException('connection dropped');
    // The same parse as the real service.
    try {
      return parseWarpBinaryReply(line);
    } on FormatException {
      throw WarpProtocolException('unexpected reply: $line');
    }
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
    final hold = holdRaw[ip];
    if (hold != null) await hold.future;
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
    final warp = warpProjectors[ip];
    if (warp != null) {
      if (warp.dropsAscii(cmd)) return null;
      final reply = warp.handleAscii(cmd);
      if (reply != null) return reply;
    }
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
    bool withSerial = true,
  }) async {
    pollCount++;
    polls.add((ip, withSerial));
    // Not `await holdPolls[ip]?.future`: that would add a microtask turn for
    // every poll, which tests counting turns would notice.
    final hold = holdPolls[ip];
    if (hold != null) await hold.future;
    final (probe, t) = pollResults[ip] ?? (ProbeResult.offline, null);
    // Like the real service: no QSN, no `serialNumber` key.
    if (t == null || withSerial) return (probe, t);
    return (probe, {...t}..remove('serialNumber'));
  }

  /// `(ip, withSerial)` of every `pollProjectorTelemetry` call.
  final List<(String ip, bool withSerial)> polls = [];

  /// What `scanNetwork` yields, in order (`{ip, name, status}`).
  final List<Map<String, dynamic>> scanResults = [];

  /// `(subnet, port, login)` of every `scanNetwork` call.
  final List<(String, int, String)> scans = [];

  @override
  Stream<Map<String, dynamic>> scanNetwork(
    String subnet,
    int port, {
    String login = '',
    String password = '',
  }) async* {
    scans.add((subnet, port, login));
    yield* Stream.fromIterable(scanResults);
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
