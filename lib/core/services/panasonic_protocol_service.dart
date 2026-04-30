import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

enum ProbeResult { online, unauthorized, offline, unprotected }

class PanasonicProtocolService {
  /// Scans a given subnet (e.g. "192.168.1") for Panasonic projectors on the specified port.
  /// Yields results as they are found.
  Stream<Map<String, dynamic>> scanNetwork(String subnet, int port, {String login = '', String password = ''}) async* {
    final List<Future<Map<String, dynamic>?>> tasks = [];

    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      tasks.add(_pingProjector(ip, port, login, password));
    }

    for (final task in tasks) {
      final result = await task;
      if (result != null) {
        yield result;
      }
    }
  }

  /// Attempts to connect to a specific IP and port, verify it's a Panasonic projector,
  /// and retrieve its model name (QID). Returns status 'online', 'unprotected', or 'auth_error'.
  Future<Map<String, dynamic>?> _pingProjector(String ip, int port, String login, String password) async {
    final (modelResponse, isProtected) = await _sendSingleCommandEx(ip, port, login, password, 'QID');
    if (modelResponse == 'Timeout' || modelResponse.contains('Error') || modelResponse.isEmpty) {
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

  /// Probes a projector to determine its reachability and auth status without
  /// fetching full telemetry. Returns [ProbeResult.online] if reachable with valid
  /// credentials, [ProbeResult.unprotected] if reachable in non-protected mode,
  /// [ProbeResult.unauthorized] if reachable but auth fails, and [ProbeResult.offline]
  /// if not reachable at all.
  Future<ProbeResult> probeProjector(String ip, int port, String login, String password) async {
    final (response, isProtected) = await _sendSingleCommandEx(ip, port, login, password, 'QID');
    if (response == 'Timeout' || response.contains('Error') || response.isEmpty) {
      return ProbeResult.offline;
    }
    if (response == 'ERRA') {
      return ProbeResult.unauthorized;
    }
    if (response.startsWith('ER')) {
      return ProbeResult.offline;
    }
    return isProtected ? ProbeResult.online : ProbeResult.unprotected;
  }

  /// A quick ping to just check if an already added projector is online and reachable on the port.
  Future<bool> checkConnection(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 1500));
      return true;
    } catch (e) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// Helper method to send a single command and return only the response string.
  Future<String> _sendSingleCommand(String ip, int port, String login, String password, String cmd) async {
    final (response, _) = await _sendSingleCommandEx(ip, port, login, password, cmd);
    return response;
  }

  /// Sends a single command and returns both the response and whether the connection
  /// used protected (auth-required) mode. Handles the NTCONTROL handshake, computes
  /// the MD5 hash for protected mode, and strips the response prefix deterministically.
  Future<(String, bool)> _sendSingleCommandEx(String ip, int port, String login, String password, String cmd) async {
    Socket? socket;
    StreamSubscription? subscription;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));

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

      final initResponse = await currentCompleter.future.timeout(const Duration(seconds: 5));

      if (!initResponse.startsWith('NTCONTROL')) {
        await subscription.cancel();
        return ('Error: Invalid Handshake', false);
      }

      // Detect protected mode from the handshake: "NTCONTROL 1 TOKEN" vs "NTCONTROL 0"
      final isProtected = initResponse.contains(' 1 ');
      String commandPrefix = '00';
      if (isProtected) {
        final tokenMatch = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})').firstMatch(initResponse);
        if (tokenMatch != null) {
          final token = tokenMatch.group(1)!;
          final hashStr = '$login:$password:$token';
          commandPrefix = '${md5.convert(utf8.encode(hashStr))}00';
        }
      }

      currentCompleter = Completer<String>();
      processBuffer();

      final fullCmd = '$commandPrefix$cmd\r';
      socket.add(ascii.encode(fullCmd));
      await socket.flush();

      final response = await currentCompleter.future.timeout(const Duration(seconds: 5));

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
  Future<bool> sendCommand(String ip, int port, String login, String password, String cmd) async {
    final response = await _sendSingleCommand(ip, port, login, password, cmd);
    if (response == 'Timeout' || response.startsWith('ER')) {
      return false;
    }
    return true;
  }

  /// Sends a specific command and returns its raw string response.
  Future<String?> sendRawCommand(String ip, int port, String login, String password, String cmd) async {
    final response = await _sendSingleCommand(ip, port, login, password, cmd);
    if (response == 'Timeout' || response.startsWith('ER')) {
      return null;
    }
    return response;
  }

  /// Polls all essential telemetry points for the Monitoring Table
  Future<Map<String, dynamic>?> pollProjectorTelemetry(String ip, int port, String login, String password) async {
    final modelResponse = await _sendSingleCommand(ip, port, login, password, 'QID');
    if (modelResponse == 'Timeout' || modelResponse.contains('Error') || modelResponse.contains('ERRA')) {
      return null;
    }

    final Map<String, dynamic> telemetry = {};
    telemetry['modelName'] = modelResponse;

    telemetry['serialNumber'] = await _sendSingleCommand(ip, port, login, password, 'QSN');
    telemetry['power'] = await _sendSingleCommand(ip, port, login, password, 'QPW');
    telemetry['shutter'] = await _sendSingleCommand(ip, port, login, password, 'QSH');
    telemetry['input'] = await _sendSingleCommand(ip, port, login, password, 'QIN');
    telemetry['signal'] = await _sendSingleCommand(ip, port, login, password, 'QVX:NSGS1');
    telemetry['runtime'] = await _sendSingleCommand(ip, port, login, password, 'QVX:RTMS1');
    telemetry['intakeTemp'] = await _sendSingleCommand(ip, port, login, password, 'QTM:0');
    telemetry['exhaustTemp'] = await _sendSingleCommand(ip, port, login, password, 'QTM:1');
    telemetry['acVoltage'] = await _sendSingleCommand(ip, port, login, password, 'QVX:VMOI2');
    telemetry['errors'] = await _sendSingleCommand(ip, port, login, password, 'QVX:ERRS2');

    return telemetry;
  }
}
