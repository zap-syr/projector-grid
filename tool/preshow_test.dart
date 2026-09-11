// Pre-show mode probe — dart run tool/preshow_test.dart
//
// Toggles pre-show over the preview WebSocket (preshow:1 / preshow:0) and polls
// NTCONTROL QVX:PSMI1 to see exactly what the projector reports and how quickly.
// Edit the connection block below. Leaves pre-show OFF at the end.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const ip = '192.168.0.8';
const ntPort = 1024;
const login = 'dispadmin';
const password = '@Panasonic';
const watch = Duration(seconds: 12);

Future<String> nt(String cmd) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      ip,
      ntPort,
      timeout: const Duration(seconds: 4),
    );
    var completer = Completer<String>();
    var buffer = StringBuffer();
    void process() {
      final s = buffer.toString();
      final i = s.indexOf('\r');
      if (i != -1) {
        final msg = s.substring(0, i);
        buffer = StringBuffer(s.substring(i + 1));
        if (!completer.isCompleted) completer.complete(msg);
      }
    }

    final sub = socket.listen(
      (d) {
        buffer.write(ascii.decode(d));
        process();
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    final init = await completer.future.timeout(const Duration(seconds: 3));
    var prefix = '00';
    if (init.contains(' 1 ')) {
      final m = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})').firstMatch(init);
      if (m != null) {
        prefix =
            '${md5.convert(utf8.encode('$login:$password:${m.group(1)}'))}00';
      }
    }
    completer = Completer<String>();
    process();
    socket.add(ascii.encode('$prefix$cmd\r'));
    await socket.flush();
    final resp = await completer.future.timeout(const Duration(seconds: 3));
    await sub.cancel();
    socket.destroy();
    return resp.trim();
  } catch (e) {
    socket?.destroy();
    return 'ERR($e)';
  }
}

Future<void> pollFor(Duration d) async {
  final t0 = DateTime.now();
  while (DateTime.now().difference(t0) < d) {
    final r = await nt('QVX:PSMI1');
    final ms = DateTime.now().difference(t0).inMilliseconds;
    stdout.writeln('  [t=${ms.toString().padLeft(5)}ms] QVX:PSMI1 -> "$r"');
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> main() async {
  stdout.writeln('baseline QVX:PSMI1 -> "${await nt('QVX:PSMI1')}"\n');

  final ws = await WebSocket.connect(
    'ws://$ip/remotepreview',
    protocols: const ['pj-cast-protocol'],
  ).timeout(const Duration(seconds: 5));
  ws.add('start');
  final alive = Timer.periodic(
    const Duration(seconds: 5),
    (_) => ws.add('alive'),
  );
  ws.listen((d) {
    if (d is String && d == 'PING') ws.add('PONG');
  }, cancelOnError: true);

  stdout.writeln('--- send preshow:1, watch ${watch.inSeconds}s ---');
  ws.add('preshow:1');
  await pollFor(watch);

  stdout.writeln('\n--- send preshow:0, watch ${watch.inSeconds}s ---');
  ws.add('preshow:0');
  await pollFor(watch);

  alive.cancel();
  await ws.close();
  stdout.writeln('\nfinal QVX:PSMI1 -> "${await nt('QVX:PSMI1')}"');
}
