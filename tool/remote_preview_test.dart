// Remote Preview integration test — dart run tool/remote_preview_test.dart
//
// Opens the projector's RemoView WebSocket the same way the web UI does,
// prints every text status message, and writes the first few JPEG frames to
// tool/ so you can eyeball them. No app, no auth. Edit [host] below first.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

const host = '192.168.0.8';
const port = 80;
const runFor = Duration(seconds: 20);
const framesToSave = 3;

Future<void> main() async {
  final url = 'ws://$host:$port/remotepreview';
  stdout.writeln('connecting $url  (subprotocol pj-cast-protocol)');

  final WebSocket ws;
  try {
    ws = await WebSocket.connect(
      url,
      protocols: const ['pj-cast-protocol'],
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    stderr.writeln('connect failed: $e');
    exitCode = 1;
    return;
  }
  stdout.writeln('connected (protocol="${ws.protocol}")\n');

  var closing = false;
  void send(String msg) {
    if (!closing) ws.add(msg);
  }

  send('start');
  final alive = Timer.periodic(
    const Duration(seconds: 5),
    (_) => send('alive'),
  );

  var frames = 0;
  var saved = 0;
  final done = Completer<void>();
  final stopAt = Timer(runFor, () {
    if (!done.isCompleted) done.complete();
  });

  final sub = ws.listen(
    (data) {
      if (data is List<int>) {
        frames++;
        final bytes = data is Uint8List ? data : Uint8List.fromList(data);
        final magic = bytes
            .take(3)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (saved < framesToSave) {
          saved++;
          final path = 'tool/remote_preview_frame_$saved.jpg';
          File(path).writeAsBytesSync(bytes);
          stdout.writeln(
            'frame $frames: ${bytes.length} bytes  magic=$magic  -> $path',
          );
        }
        send('receive');
      } else if (data is String) {
        stdout.writeln('text: $data');
        send(data == 'PING' ? 'PONG' : 'receive');
      }
    },
    onError: (Object e) {
      stderr.writeln('socket error: $e');
      if (!done.isCompleted) done.complete();
    },
    onDone: () {
      stdout.writeln('socket closed by projector');
      if (!done.isCompleted) done.complete();
    },
    cancelOnError: true,
  );

  await done.future;
  closing = true;
  alive.cancel();
  stopAt.cancel();
  await sub.cancel();
  await ws.close();
  stdout.writeln('\ndone — $frames binary frame(s) in ${runFor.inSeconds}s');
}
