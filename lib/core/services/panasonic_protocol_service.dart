import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';

enum ProbeResult { online, unauthorized, offline, unprotected }

class PanasonicProtocolService {
  /// Scans a given subnet (e.g. "192.168.1") for Panasonic projectors on the specified port.
  /// Yields results as they are found. Addresses are probed in batches of 50 to
  /// avoid opening all 254 sockets simultaneously.
  Stream<Map<String, dynamic>> scanNetwork(
    String subnet,
    int port, {
    String login = '',
    String password = '',
  }) async* {
    const batchSize = 50;
    final ips = [for (int i = 1; i <= 254; i++) '$subnet.$i'];

    for (int start = 0; start < ips.length; start += batchSize) {
      final batch = ips.sublist(
        start,
        (start + batchSize).clamp(0, ips.length),
      );
      final results = await Future.wait(
        batch.map((ip) => _pingProjector(ip, port, login, password)),
      );
      for (final result in results) {
        if (result != null) yield result;
      }
    }
  }

  /// Attempts to connect to a specific IP and port, verify it's a Panasonic projector,
  /// and retrieve its model name (QID). Returns status 'online', 'unprotected', or 'auth_error'.
  Future<Map<String, dynamic>?> _pingProjector(
    String ip,
    int port,
    String login,
    String password,
  ) async {
    final (modelResponse, isProtected) = await _sendSingleCommandEx(
      ip,
      port,
      login,
      password,
      'QID',
    );
    if (modelResponse == 'Timeout' ||
        modelResponse.contains('Error') ||
        modelResponse.isEmpty) {
      return null;
    }
    if (modelResponse == 'ERRA') {
      return {'ip': ip, 'name': ip, 'status': 'auth_error'};
    }
    if (modelResponse.startsWith('ER')) {
      return null;
    }
    return {
      'ip': ip,
      'name': modelResponse,
      'status': isProtected ? 'online' : 'unprotected',
    };
  }

  /// A quick ping to just check if an already added projector is online and reachable on the port.
  Future<bool> checkConnection(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 1500),
      );
      return true;
    } catch (e) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// Helper method to send a single command and return only the response string.
  Future<String> _sendSingleCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    final (response, _) = await _sendSingleCommandEx(
      ip,
      port,
      login,
      password,
      cmd,
    );
    return response;
  }

  /// Sends a single command and returns both the response and whether the connection
  /// used protected (auth-required) mode. Handles the NTCONTROL handshake, computes
  /// the MD5 hash for protected mode, and strips the response prefix deterministically.
  Future<(String, bool)> _sendSingleCommandEx(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    Socket? socket;
    StreamSubscription? subscription;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 4),
      );

      Completer<String>? currentCompleter = Completer<String>();
      StringBuffer buffer = StringBuffer();

      void processBuffer() {
        final content = buffer.toString();
        final newlineIndex = content.indexOf('\r');
        if (newlineIndex != -1) {
          final message = content.substring(0, newlineIndex);
          buffer = StringBuffer(content.substring(newlineIndex + 1));
          if (currentCompleter != null && !currentCompleter.isCompleted) {
            currentCompleter.complete(message);
          }
        }
      }

      subscription = socket.listen(
        (data) {
          buffer.write(ascii.decode(data));
          processBuffer();
        },
        onError: (e) {
          if (currentCompleter != null && !currentCompleter.isCompleted) {
            currentCompleter.completeError(e);
          }
        },
      );

      final initResponse = await currentCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      if (!initResponse.startsWith('NTCONTROL')) {
        await subscription.cancel();
        return ('Error: Invalid Handshake', false);
      }

      // Detect protected mode from the handshake: "NTCONTROL 1 TOKEN" vs "NTCONTROL 0"
      final isProtected = initResponse.contains(' 1 ');
      String commandPrefix = '00';
      if (isProtected) {
        final tokenMatch = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})')
            .firstMatch(initResponse);
        if (tokenMatch == null) {
          // The projector announced protected mode but its challenge token
          // doesn't match the expected 8-hex-char format — sending the
          // command with the unauthenticated '00' prefix anyway would just
          // get silently rejected with no indication why, so fail
          // explicitly instead of guessing.
          await subscription.cancel();
          return ('Error: Unrecognized Auth Token', false);
        }
        final token = tokenMatch.group(1)!;
        final hashStr = '$login:$password:$token';
        commandPrefix = '${md5.convert(utf8.encode(hashStr))}00';
      }

      currentCompleter = Completer<String>();
      processBuffer();

      final fullCmd = '$commandPrefix$cmd\r';
      socket.add(ascii.encode(fullCmd));
      await socket.flush();

      final response = await currentCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      // Responses are always prefixed with '00' regardless of auth mode.
      // Strip exactly 2 chars from the front rather than searching for '00',
      // which could match inside a model name and strip the wrong amount.
      final trimmed = response.trim();
      final result = trimmed.startsWith('00') && trimmed.length > 2
          ? trimmed.substring(2)
          : trimmed;

      return (result, isProtected);
    } catch (e) {
      return ('Timeout', false);
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  /// Sends an action command to the projector without expecting complex telemetry back.
  Future<bool> sendCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    final response = await _sendSingleCommand(ip, port, login, password, cmd);
    if (response == 'Timeout' || response.startsWith('ER')) {
      return false;
    }
    return true;
  }

  /// Sends a specific command and returns its raw string response.
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    final response = await _sendSingleCommand(ip, port, login, password, cmd);
    if (response == 'Timeout' || response.startsWith('ER')) {
      return null;
    }
    return response;
  }

  /// Polls all essential telemetry points for the Monitoring Table, and
  /// classifies reachability/auth status from that same initial `QID` query.
  /// This used to be two separate methods (a dropped `probeProjector` plus
  /// this one) that each independently sent `QID` to the same projector on
  /// every poll cycle for overlapping information — merged so `QID` is only
  /// sent once. Classification order/logic here matches what `probeProjector`
  /// used to do exactly, so callers see the same [ProbeResult] values as
  /// before.
  Future<(ProbeResult, Map<String, dynamic>?)> pollProjectorTelemetry(
    String ip,
    int port,
    String login,
    String password,
  ) async {
    final (modelResponse, isProtected) = await _sendSingleCommandEx(
      ip,
      port,
      login,
      password,
      'QID',
    );
    if (modelResponse == 'Timeout' ||
        modelResponse.contains('Error') ||
        modelResponse.isEmpty) {
      return (ProbeResult.offline, null);
    }
    if (modelResponse == 'ERRA') {
      return (ProbeResult.unauthorized, null);
    }
    if (modelResponse.startsWith('ER')) {
      return (ProbeResult.offline, null);
    }

    final Map<String, dynamic> telemetry = {};
    telemetry['modelName'] = modelResponse;

    // Fire all 10 remaining telemetry queries concurrently rather than one
    // at a time — each is its own TCP connect/handshake/command/disconnect
    // cycle per the protocol's connection-lifetime rule, so awaiting them
    // sequentially paid every round-trip's latency 10 times over per node,
    // per poll cycle. Same concurrent-queries-to-one-projector pattern
    // already used (and verified on real hardware) by
    // geometry_correction_dialog.dart's _loadCorner().
    final results = await Future.wait([
      _sendSingleCommand(ip, port, login, password, 'QSN'),
      _sendSingleCommand(ip, port, login, password, 'QPW'),
      _sendSingleCommand(ip, port, login, password, 'QSH'),
      _sendSingleCommand(ip, port, login, password, 'QIN'),
      _sendSingleCommand(ip, port, login, password, 'QVX:NSGS1'),
      _sendSingleCommand(ip, port, login, password, 'QVX:RTMS1'),
      _sendSingleCommand(ip, port, login, password, 'QTM:0'),
      _sendSingleCommand(ip, port, login, password, 'QTM:1'),
      _sendSingleCommand(ip, port, login, password, 'QVX:VMOI2'),
      _sendSingleCommand(ip, port, login, password, 'QVX:ERRS2'),
    ]);

    telemetry['serialNumber'] = results[0];
    telemetry['power'] = results[1];
    telemetry['shutter'] = results[2];
    telemetry['input'] = results[3];
    telemetry['signal'] = results[4];
    telemetry['runtime'] = results[5];
    telemetry['intakeTemp'] = results[6];
    telemetry['exhaustTemp'] = results[7];
    telemetry['acVoltage'] = results[8];
    telemetry['errors'] = results[9];

    final status = isProtected ? ProbeResult.online : ProbeResult.unprotected;
    return (status, telemetry);
  }
}
