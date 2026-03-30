// OSC codec unit test — dart run tool/osc_codec_test.dart
// Validates OSC message encode/decode roundtrip without the app running.
import 'dart:io';
import 'dart:typed_data';

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
  final tagBuf = StringBuffer(',');
  for (final a in args) {
    if (a is int) tagBuf.write('i');
    if (a is double) tagBuf.write('f');
    if (a is String) tagBuf.write('s');
  }
  result.addAll(_encodeString(tagBuf.toString()));
  for (final a in args) {
    if (a is int) result.addAll(_encodeInt(a));
    if (a is String) result.addAll(_encodeString(a));
  }
  return result;
}

int _align(int offset) => offset + (4 - offset % 4) % 4;

Map<String, dynamic> parseOscMessage(List<int> bytes) {
  final addrEnd = bytes.indexOf(0);
  final address = String.fromCharCodes(bytes.sublist(0, addrEnd));
  var offset = _align(addrEnd + 1);
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
    } else if (t == 's') {
      final end = bytes.indexOf(0, offset);
      final s = String.fromCharCodes(bytes.sublist(offset, end));
      args.add(s);
      offset = _align(end + 1);
    }
  }
  return {'address': address, 'args': args};
}

int _pass = 0, _fail = 0;

void _check(String label, Object actual, Object expected) {
  if (actual.toString() == expected.toString()) {
    print('  ✓ $label');
    _pass++;
  } else {
    print('  ✗ $label');
    print('    expected: $expected');
    print('    actual:   $actual');
    _fail++;
  }
}

void _testRoundtrip(String address, List<Object> args) {
  final bytes = buildOscMessage(address, args);
  final parsed = parseOscMessage(bytes);
  _check('address: $address', parsed['address'], address);
  _check('args: $args', parsed['args'].toString(), args.toString());
}

Future<void> _testLoopback() async {
  const port = 19999;
  final receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, port);
  final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);

  final received = <Map<String, dynamic>>[];
  receiver.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = receiver.receive();
      if (dg != null) received.add(parseOscMessage(dg.data));
    }
  });

  final messages = [
    ('/pgrid/status', <Object>[]),
    ('/pgrid/all/power/on', <Object>[]),
    ('/pgrid/all/shutter/open', <Object>[]),
    ('/pgrid/status', <Object>[3, 1, 0]), // status reply format
  ];

  for (final (addr, args) in messages) {
    final bytes = buildOscMessage(addr, args);
    sender.send(bytes, InternetAddress.loopbackIPv4, port);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 200));

  _check('loopback received count', received.length, messages.length);
  for (var i = 0; i < received.length && i < messages.length; i++) {
    _check('loopback[$i] address', received[i]['address'], messages[i].$1);
  }

  receiver.close();
  sender.close();
}

Future<void> main() async {
  print('═══════════════════════════════════════════════');
  print(' OSC Codec & Loopback Tests');
  print('═══════════════════════════════════════════════\n');

  print('── Encode/decode roundtrip ──');
  _testRoundtrip('/pgrid/status', []);
  _testRoundtrip('/pgrid/all/power/on', []);
  _testRoundtrip('/pgrid/all/shutter/open', []);
  _testRoundtrip('/pgrid/group/stage/shutter/close', []);
  _testRoundtrip('/pgrid/status', [3, 1, 0]); // online=3, offline=1, warnings=0

  print('\n── UDP loopback ──');
  await _testLoopback();

  print('\n═══════════════════════════════════════════════');
  print(' Results: $_pass passed, $_fail failed');
  print('═══════════════════════════════════════════════');
  if (_fail > 0) exit(1);
}
