// OSC Integration Test Tool — dart run tool/osc_test.dart
// App must be running with OSC enabled (Preferences → OSC tab).
// App listens on 0.0.0.0:8000, sends status back to 127.0.0.1:9000.

import 'dart:io';
import 'dart:typed_data';

// ── Minimal OSC encoder (no external deps) ─────────────────────────────────

List<int> _encodeString(String s) {
  final bytes = s.codeUnits.toList()..add(0);
  final pad = (4 - bytes.length % 4) % 4;
  bytes.addAll(List.filled(pad, 0));
  return bytes;
}

List<int> _encodeInt(int v) {
  final b = Uint8List(4);
  ByteData.view(b.buffer).setInt32(0, v);
  return b;
}

List<int> buildOscMessage(String address, List<Object> args) {
  final result = <int>[];
  result.addAll(_encodeString(address));

  // Type tag string
  final tagBuf = StringBuffer(',');
  for (final a in args) {
    if (a is int) tagBuf.write('i');
    if (a is double) tagBuf.write('f');
    if (a is String) tagBuf.write('s');
  }
  result.addAll(_encodeString(tagBuf.toString()));

  // Arguments
  for (final a in args) {
    if (a is int) result.addAll(_encodeInt(a));
    if (a is String) result.addAll(_encodeString(a));
  }
  return result;
}

// ── Minimal OSC decoder ────────────────────────────────────────────────────

String _decodeString(List<int> bytes, int offset) {
  final end = bytes.indexOf(0, offset);
  return String.fromCharCodes(bytes.sublist(offset, end == -1 ? bytes.length : end));
}

int _align(int offset) => offset + (4 - offset % 4) % 4;

Map<String, dynamic> parseOscMessage(List<int> bytes) {
  // Address
  final addrEnd = bytes.indexOf(0);
  final address = String.fromCharCodes(bytes.sublist(0, addrEnd));
  var offset = _align(addrEnd + 1);

  // Type tag
  final tagEnd = bytes.indexOf(0, offset);
  final typeTag = String.fromCharCodes(bytes.sublist(offset, tagEnd));
  offset = _align(tagEnd + 1);

  final args = <Object>[];
  for (var i = 1; i < typeTag.length; i++) {
    final t = typeTag[i];
    if (t == 'i') {
      final v = ByteData.view(Uint8List.fromList(bytes.sublist(offset, offset + 4)).buffer).getInt32(0);
      args.add(v);
      offset += 4;
    } else if (t == 'f') {
      final v = ByteData.view(Uint8List.fromList(bytes.sublist(offset, offset + 4)).buffer).getFloat32(0);
      args.add(v);
      offset += 4;
    } else if (t == 's') {
      final s = _decodeString(bytes, offset);
      args.add(s);
      offset = _align(offset + s.length + 1);
    }
  }

  return {'address': address, 'args': args};
}

// ── Test runner ───────────────────────────────────────────────────────────

const String appHost = '127.0.0.1';
const int appReceivePort = 8000; // port the app listens on
const int testListenPort = 9000; // port we listen on (app sends status here)

void _send(RawDatagramSocket socket, String address, [List<Object> args = const []]) {
  final bytes = buildOscMessage(address, args);
  final sent = socket.send(bytes, InternetAddress(appHost), appReceivePort);
  print('→ Sent [$address] ($sent bytes)');
}

Future<void> main() async {
  print('═══════════════════════════════════════════════');
  print(' OSC Integration Test');
  print(' App receive: $appHost:$appReceivePort');
  print(' Test listen: 0.0.0.0:$testListenPort');
  print('═══════════════════════════════════════════════\n');

  // Bind to the port the app sends status TO so we can capture replies
  final listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, testListenPort);
  // Also use this socket to send to the app
  final sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  print('[LISTEN] Bound to 0.0.0.0:$testListenPort — waiting for incoming OSC messages...\n');

  // Listen for incoming messages in the background
  int receivedCount = 0;
  listenSocket.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = listenSocket.receive();
      if (dg == null) return;
      try {
        final msg = parseOscMessage(dg.data);
        receivedCount++;
        print('← Received from ${dg.address.address}:${dg.port}');
        print('   Address: ${msg['address']}');
        print('   Args:    ${msg['args']}');
        print('');
      } catch (e) {
        print('← Received ${dg.data.length} bytes (parse failed: $e)');
      }
    }
  });

  await Future.delayed(const Duration(milliseconds: 200));

  // ── Test 1: Request status reply ────────────────────────────────────────
  print('─── Test 1: /pprjm/status (request outgoing status) ───');
  _send(sendSocket, '/pprjm/status');
  await Future.delayed(const Duration(milliseconds: 500));

  // ── Test 2: Power On all ─────────────────────────────────────────────────
  print('─── Test 2: /pprjm/all/power/on ───');
  _send(sendSocket, '/pprjm/all/power/on');
  await Future.delayed(const Duration(milliseconds: 500));

  // ── Test 3: Shutter open all ─────────────────────────────────────────────
  print('─── Test 3: /pprjm/all/shutter/open ───');
  _send(sendSocket, '/pprjm/all/shutter/open');
  await Future.delayed(const Duration(milliseconds: 500));

  // ── Test 4: Group command (group OSC address = /group/stage) ─────────────
  print('─── Test 4: /pprjm/group/stage/shutter/close ───');
  _send(sendSocket, '/pprjm/group/stage/shutter/close');
  await Future.delayed(const Duration(milliseconds: 500));

  // ── Test 5: Unknown command (should log warning, not crash) ──────────────
  print('─── Test 5: /pprjm/all/unknown/command (expect no crash) ───');
  _send(sendSocket, '/pprjm/all/unknown/command');
  await Future.delayed(const Duration(milliseconds: 500));

  // ── Test 6: Invalid OSC address ──────────────────────────────────────────
  print('─── Test 6: /pprjm/group/nonexistent-group/power/off (expect group not found) ───');
  _send(sendSocket, '/pprjm/group/nonexistent-group/power/off');
  await Future.delayed(const Duration(milliseconds: 500));

  print('\n═══════════════════════════════════════════════');
  print(' Tests done. Received $receivedCount message(s) from app.');
  if (receivedCount == 0) {
    print('\n ⚠ No messages received. Check:');
    print('   • Is the app running?');
    print('   • Is OSC enabled in Preferences → OSC tab?');
    print('   • App receive port = $appReceivePort, send port = $testListenPort');
    print('   • Firewall not blocking UDP?');
  }
  print('═══════════════════════════════════════════════');

  sendSocket.close();
  listenSocket.close();
}
