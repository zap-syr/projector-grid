import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

enum ProbeResult { online, unauthorized, offline }

class PanasonicProtocolService {
  /// Scans a given subnet (e.g. "192.168.1") for Panasonic projectors on the specified port.
  /// Yields results as they are found.
  Stream<Map<String, dynamic>> scanNetwork(String subnet, int port, {String login = '', String password = ''}) async* {
    final List<Future<Map<String, dynamic>?>> tasks = [];

    // Scan all 254 possible host addresses in a /24 subnet concurrently
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
  /// and retrieve its model name (QID).
  Future<Map<String, dynamic>?> _pingProjector(String ip, int port, String login, String password) async {
    final modelResponse = await _sendSingleCommand(ip, port, login, password, 'QID');
    if (modelResponse == 'Timeout' || modelResponse.contains('Error') || modelResponse.isEmpty) {
      return null;
    }
    if (modelResponse == 'ERRA') {
      return {'ip': ip, 'name': ip, 'status': 'auth_error'};
    }
    if (modelResponse.startsWith('ER')) {
      return null;
    }
    return {'ip': ip, 'name': modelResponse, 'status': 'online'};
  }

  /// Probes a projector to determine its reachability and auth status without
  /// fetching full telemetry. Returns [ProbeResult.online] if reachable and
  /// credentials are valid, [ProbeResult.unauthorized] if reachable but auth
  /// fails, and [ProbeResult.offline] if not reachable at all.
  Future<ProbeResult> probeProjector(String ip, int port, String login, String password) async {
    final response = await _sendSingleCommand(ip, port, login, password, 'QID');
    if (response == 'Timeout' || response.contains('Error') || response.isEmpty) {
      return ProbeResult.offline;
    }
    if (response == 'ERRA') {
      return ProbeResult.unauthorized;
    }
    if (response.startsWith('ER')) {
      return ProbeResult.offline;
    }
    return ProbeResult.online;
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

  /// Helper method to send a single command. The Panasonic projector closes the connection after each command.
  Future<String> _sendSingleCommand(String ip, int port, String login, String password, String cmd) async {
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
        return 'Error: Invalid Handshake';
      }

      String commandPrefix = '00';
      if (initResponse.contains(' 1 ')) {
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
      
      final headerIndex = response.indexOf('00');
      if (headerIndex != -1 && response.length > headerIndex + 2) {
        return response.substring(headerIndex + 2).trim();
      }
      return response.trim();
    } catch (e) {
      return 'Timeout';
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  /// Sends an action command to the projector without expecting complex telemetry back.
  Future<bool> sendCommand(String ip, int port, String login, String password, String cmd) async {
    final response = await _sendSingleCommand(ip, port, login, password, cmd);
    // Usually responses are echoing the command back or a generic acknowledgment.
    // As long as it's not a timeout or ERRA (auth error), we consider the dispatch successful.
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
    telemetry['power'] = await _sendSingleCommand(ip, port, login, password, 'QPW'); // 000=standby, 001=on
    telemetry['shutter'] = await _sendSingleCommand(ip, port, login, password, 'QSH'); // 0=off(open), 1=on(closed)
    telemetry['input'] = await _sendSingleCommand(ip, port, login, password, 'QIN');
    telemetry['signal'] = await _sendSingleCommand(ip, port, login, password, 'QVX:NSGS1'); // Format: NSGS1=*****
    telemetry['runtime'] = await _sendSingleCommand(ip, port, login, password, 'QVX:RTMS1'); // Format: RTMS1=1234
    telemetry['intakeTemp'] = await _sendSingleCommand(ip, port, login, password, 'QTM:0');
    telemetry['exhaustTemp'] = await _sendSingleCommand(ip, port, login, password, 'QTM:1');
    telemetry['acVoltage'] = await _sendSingleCommand(ip, port, login, password, 'QVX:VMOI2'); // Format: VMOI2=+00000
    telemetry['errors'] = await _sendSingleCommand(ip, port, login, password, 'QVX:ERRS2');

    return telemetry;
  }
}
