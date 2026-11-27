import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

import 'fake_warp_projector.dart';

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

  /// The warp tables of this projector: a binary line (`01` and hex) is
  /// answered from it, and so are the `GMMI0`, `GDTS1` and `GGNS1` commands
  /// that [responses] does not script. Its injection hooks (an error frame,
  /// a rejected write, a dropped connection) reach the client as on the wire.
  final FakeWarpProjector warp = FakeWarpProjector();

  /// When set, only this many connections get a valid [greeting]; every later
  /// one gets a garbage handshake — a fast transport failure on the client
  /// side (`Error: Invalid Handshake`) without waiting out a socket timeout.
  int? validHandshakes;
  int _connections = 0;

  /// Wait this long before answering a command, to keep a call in flight.
  Duration? replyDelay;

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
    // A client that hangs up right after the greeting (checkConnection) makes
    // the write fail with ECONNRESET on macOS; that is not the test's concern.
    socket.done.ignore();
    socket.add(ascii.encode(ok ? '$greeting\r' : 'HTTP/1.1 400\r'));
    if (!ok) {
      socket.close().ignore();
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
      // A binary command: the hash, `01` and the frame as upper-case hex.
      final binary = body == null
          ? RegExp(r'^(?:[0-9a-f]{32})?01((?:[0-9A-F]{2})+)$').firstMatch(line)
          : null;
      void reply() {
        if (binary != null) {
          final answer = warp.handleBinary(warpHexToBytes(binary.group(1)!));
          if (answer != null) socket.add(ascii.encode('$answer\r'));
        } else if (warp.dropsAscii(cmd) && !responses.containsKey(cmd)) {
          // No reply, just a closed connection.
        } else {
          final scripted = responses[cmd] ?? warp.handleAscii(cmd) ?? 'ER401';
          socket.add(ascii.encode('00$scripted\r'));
        }
        socket.close().ignore();
      }

      final delay = replyDelay;
      if (delay == null) {
        reply();
      } else {
        Timer(delay, reply);
      }
    }, onError: (_) {});
  }

  Future<void> close() => _server.close();
}
