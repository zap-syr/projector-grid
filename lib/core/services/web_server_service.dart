import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Headers every response carries. The page loads nothing from other origins
/// (fonts and icons are bundled), so `'self'` is all it needs; inline styles
/// are allowed for Svelte's `style:` bindings.
const webSecurityHeaders = {
  'content-security-policy': "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'",
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
};

Middleware addWebSecurityHeaders() => createMiddleware(
  responseHandler: (r) => r.change(headers: webSecurityHeaders),
);

/// HTTP server for the Web UI, bound on all IPv4 interfaces so phones on the
/// show network can reach it. Transport only: what it serves is the
/// [Handler] it's started with.
class WebServerService {
  HttpServer? _server;

  bool get isActive => _server != null;

  /// Returns false when [port] can't be bound (in use, or not permitted).
  Future<bool> start({required int port, required Handler handler}) async {
    await stop();
    try {
      _server = await shelf_io.serve(
        const Pipeline()
            .addMiddleware(addWebSecurityHeaders())
            .addHandler(handler),
        InternetAddress.anyIPv4,
        port,
        poweredByHeader: null,
      );
      return true;
    } on SocketException {
      return false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
