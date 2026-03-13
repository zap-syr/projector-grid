import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

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
    Socket? socket;
    try {
      // Connect with a slightly longer timeout for real-world networks
      socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 1500));
      
      final initCompleter = Completer<String>();
      StringBuffer buffer = StringBuffer();
      
      late StreamSubscription subscription;
      subscription = socket.listen(
        (data) {
          buffer.write(ascii.decode(data));
          if (buffer.toString().contains('\r') && !initCompleter.isCompleted) {
            initCompleter.complete(buffer.toString());
          }
        },
        onError: (e) {
          if (!initCompleter.isCompleted) initCompleter.completeError(e);
        },
        onDone: () {
          if (!initCompleter.isCompleted) initCompleter.completeError('Connection closed');
        },
      );

      final initResponse = await initCompleter.future.timeout(const Duration(seconds: 2));
      
      if (!initResponse.startsWith('NTCONTROL')) {
        await subscription.cancel();
        return null; // Not a Panasonic projector
      }

      final isProtected = initResponse.contains(' 1 ');
      
      String commandPrefix = '00'; // Default non-protected header '0' '0'
      
      if (isProtected) {
        if (login.isEmpty || password.isEmpty) {
          await subscription.cancel();
          return {
            'ip': ip,
            'name': 'Protected Projector (Requires Login)',
            'status': 'protected',
          };
        }

        // Extract the random 8-byte token at the end before CR
        // Format: NTCONTROL 1 zzzzzzzz\r
        final tokenMatch = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})\r?').firstMatch(initResponse);
        if (tokenMatch == null) {
          await subscription.cancel();
          return null;
        }
        
        final token = tokenMatch.group(1)!;
        
        // Generate MD5 hash: "login:password:token"
        final hashStr = '$login:$password:$token';
        final bytes = utf8.encode(hashStr);
        final digest = md5.convert(bytes);
        commandPrefix = '${digest.toString()}00';
      }

      // Prepare for next command response
      buffer.clear();
      final cmdCompleter = Completer<String>();
      
      // Override the data handler for the next command
      subscription.onData((data) {
        buffer.write(ascii.decode(data));
        if (buffer.toString().contains('\r') && !cmdCompleter.isCompleted) {
          cmdCompleter.complete(buffer.toString());
        }
      });
      subscription.onError((e) {
        if (!cmdCompleter.isCompleted) cmdCompleter.completeError(e);
      });

      // We send the Model Name query command: QID
      final qidCommand = '${commandPrefix}QID\r';
      socket.add(ascii.encode(qidCommand));
      await socket.flush();

      final cmdResponse = await cmdCompleter.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      // Expected response format: "00<ModelName>\r" (Non-Protected) or "00<ModelName>\r" with a 32-byte hash header
      String modelName = 'Unknown Model';
      if (cmdResponse.contains('ERR')) {
        modelName = 'Auth Failed or Error: ${cmdResponse.trim()}';
      } else {
        // Find the index of the command response header. 
        // If protected, it might be returning a hash. 
        // According to protocol, response header is '0' '0'.
        final headerIndex = cmdResponse.indexOf('00');
        if (headerIndex != -1 && cmdResponse.length > headerIndex + 2) {
          modelName = cmdResponse.substring(headerIndex + 2).replaceAll('\r', '').trim();
          if (modelName.isEmpty) modelName = 'Panasonic Projector';
        } else {
           modelName = 'Panasonic Projector';
        }
      }

      return {
        'ip': ip,
        'name': modelName,
        'status': 'online',
      };

    } catch (e) {
      // Timeout, connection refused, etc.
      return null;
    } finally {
      socket?.destroy();
    }
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
}
