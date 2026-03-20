// Panasonic NTCONTROL raw TCP test — dart run tool/projector_protocol_test.dart
// Tests direct TCP communication with a projector using the NTCONTROL protocol.
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

void main() async {
  final ip = '192.168.0.8';
  final port = 1024;
  final login = 'admin1';
  final password = 'panasonic';

  Future<String> sendSingleCommand(String cmd) async {
    print('Connecting to $ip:$port for $cmd...');
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));

      Completer<String>? currentCompleter = Completer<String>();
      StringBuffer buffer = StringBuffer();

      void processBuffer() {
        final content = buffer.toString();
        final newlineIndex = content.indexOf('\r');

        if (newlineIndex != -1) {
          final message = content.substring(0, newlineIndex);
          buffer = StringBuffer(content.substring(newlineIndex + 1));
          if (currentCompleter != null && !currentCompleter!.isCompleted) {
            currentCompleter!.complete(message);
          }
        }
      }

      final subscription = socket.listen(
        (data) {
          buffer.write(ascii.decode(data));
          processBuffer();
        },
        onError: (e) {
          if (currentCompleter != null && !currentCompleter!.isCompleted) {
            currentCompleter!.completeError(e);
          }
        },
      );

      final initResponse = await currentCompleter!.future.timeout(const Duration(seconds: 3));

      String commandPrefix = '00';
      if (initResponse.contains(' 1 ')) {
        final tokenMatch = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})').firstMatch(initResponse);
        if (tokenMatch != null) {
          final token = tokenMatch.group(1)!;
          final hashStr = '$login:$password:$token';
          final digest = md5.convert(utf8.encode(hashStr));
          commandPrefix = '${digest.toString()}00';
        }
      }

      currentCompleter = Completer<String>();
      processBuffer();

      final fullCmd = '$commandPrefix$cmd\r';
      socket.add(ascii.encode(fullCmd));
      await socket.flush();

      final response = await currentCompleter!.future.timeout(const Duration(seconds: 3));
      await subscription.cancel();
      socket.destroy();
      return response;
    } catch (e) {
      socket?.destroy();
      print('Error on $cmd: $e');
      return 'Timeout';
    }
  }

  print('--- Testing Telemetry ---');
  print('QID: ${await sendSingleCommand('QID')}');
  print('QSN: ${await sendSingleCommand('QSN')}');
  print('QPW: ${await sendSingleCommand('QPW')}');
  print('QSH: ${await sendSingleCommand('QSH')}');
  print('QVX:ERRS2: ${await sendSingleCommand('QVX:ERRS2')}');
  print('Done.');
}
