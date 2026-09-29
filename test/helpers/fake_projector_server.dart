import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// A loopback NTCONTROL "projector": one TCP connection per command, the same
/// lifecycle `PanasonicProtocolService` expects from real hardware.
///
/// [responses] maps a bare command (e.g. `QID`) to the reply body; the server
/// adds the `00` prefix and `\r`. Unknown commands get `ER401`.
class FakeProjectorServer {
  FakeProjectorServer._(this._server, this.greeting, this.responses);

  final ServerSocket _server;

  /// First line sent on connect, e.g. `NTCONTROL 0` or `NTCONTROL 1 1a2b3c4d`.
  String greeting;
  final Map<String, String> responses;

  /// Every raw line the client sent (prefix included, `\r` stripped).
  final List<String> received = [];

  /// When set, only this many connections get a valid [greeting]; every later
  /// one gets a garbage handshake — a fast transport failure on the client
  /// side (`Error: Invalid Handshake`) without waiting out a socket timeout.
  int? validHandshakes;
  int _connections = 0;

  int get port => _server.port;
  String get host => InternetAddress.loopbackIPv4.address;

  static Future<FakeProjectorServer> start({
    String greeting = 'NTCONTROL 0',
    Map<String, String>? responses,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeProjectorServer._(server, greeting, responses ?? {});
    server.listen(fake._handle);
    return fake;
  }

  static String md5Prefix(String login, String password, String token) =>
      md5.convert(utf8.encode('$login:$password:$token')).toString();

  void _handle(Socket socket) {
    final limit = validHandshakes;
    final ok = limit == null || _connections < limit;
    _connections++;
    socket.add(ascii.encode(ok ? '$greeting\r' : 'HTTP/1.1 400\r'));
    if (!ok) {
      unawaited(socket.flush().then((_) => socket.close()));
      return;
    }
    final buffer = StringBuffer();
    socket.listen((data) {
      buffer.write(ascii.decode(data));
      final content = buffer.toString();
      final end = content.indexOf('\r');
      if (end < 0) return;
      final line = content.substring(0, end);
      received.add(line);
      // Strip the 32-hex MD5 hash (protected mode) and the `00` header.
      final body = RegExp(r'^(?:[0-9a-f]{32})?00(.*)$').firstMatch(line);
      final cmd = body?.group(1) ?? line;
      socket.add(ascii.encode('00${responses[cmd] ?? 'ER401'}\r'));
      unawaited(socket.flush().then((_) => socket.close()));
    }, onError: (_) {});
  }

  Future<void> close() => _server.close();
}
