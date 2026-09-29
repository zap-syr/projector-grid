import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'web_auth.dart';
import 'web_event_hub.dart';

typedef Json = Map<String, Object?>;

Json sessionJson({required String projectName, WebRole? role}) => {
  'projectName': projectName,
  'authenticated': role != null,
  'role': ?role?.name,
};

Json loginJson(WebSession s) => {'token': s.token, 'role': s.role.name};

Json errorJson(String error, {int? retryAfter}) => {
  'error': error,
  'retryAfter': ?retryAfter,
};

/// What the API serves; implemented over the providers by
/// `web_server_provider.dart`, so no app logic lives in the server.
abstract interface class WebApiSource {
  String get projectName;
  String get viewerPinHash;
  Json config(WebRole role);
  List<Json> projectors();
  List<Json> groups();

  /// The first events a new `/api/events` stream receives.
  List<WebEvent> snapshotEvents();

  void signedIn(WebSession session);
}

/// `/api/*` routes: PIN login, session check on everything else, read-only
/// data and the SSE stream. See `web_ui/api/openapi.yaml`.
class WebApi {
  WebApi({required this.auth, required this.hub, required this.source});

  static const cookieName = 'pg_session';

  final WebAuth auth;
  final WebEventHub hub;
  final WebApiSource source;

  Handler get handler {
    final router =
        Router(notFoundHandler: (_) => _json(404, errorJson('not_found')))
          ..post('/api/login', _login)
          ..get('/api/session', _session)
          ..post('/api/logout', _authed((r, s) => _logout(s)))
          ..get(
            '/api/config',
            _authed((_, s) => _json(200, source.config(s.role))),
          )
          ..get(
            '/api/projectors',
            _authed((_, _) => _json(200, source.projectors())),
          )
          ..get('/api/projectors/<id>', (Request r, String id) {
            return _authed((_, _) {
              final match = source.projectors().where((p) => p['id'] == id);
              return match.isEmpty
                  ? _json(404, errorJson('not_found'))
                  : _json(200, match.first);
            })(r);
          })
          ..get('/api/groups', _authed((_, _) => _json(200, source.groups())))
          // Filled by the alerts provider (ROADMAP §4) once it exists.
          ..get('/api/alerts', _authed((_, _) => _json(200, const <Json>[])))
          ..get('/api/events', _authed((_, s) => _events(s)));
    return router.call;
  }

  Future<Response> _login(Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException {
      return _json(400, errorJson('bad_request'));
    }
    final pin = body is Map ? body['pin'] : null;
    if (pin is! String) return _json(400, errorJson('bad_request'));

    final result = auth.login(
      ip: _clientIp(request),
      pin: pin,
      viewerPinHash: source.viewerPinHash,
    );
    switch (result) {
      case LoginOk(:final session):
        source.signedIn(session);
        return _json(
          200,
          loginJson(session),
          headers: {
            'set-cookie':
                '$cookieName=${session.token}; Path=/; HttpOnly; SameSite=Strict',
          },
        );
      case LoginInvalidPin():
        return _json(401, errorJson('invalid_pin'));
      case LoginLockedOut(:final retryAfter):
        final seconds = (retryAfter.inMilliseconds / 1000).ceil();
        return _json(
          429,
          errorJson('locked_out', retryAfter: seconds),
          headers: {'retry-after': '$seconds'},
        );
    }
  }

  Response _session(Request request) {
    final session = auth.touch(_token(request));
    return _json(
      200,
      sessionJson(projectName: source.projectName, role: session?.role),
    );
  }

  Response _logout(WebSession session) {
    auth.logout(session.token);
    hub.close(session.token);
    return Response(
      204,
      headers: {
        'set-cookie':
            '$cookieName=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0',
        'cache-control': 'no-store',
      },
    );
  }

  Response _events(WebSession session) => Response.ok(
    hub.subscribe(session.token, source.snapshotEvents()),
    headers: {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-store',
    },
    // Each event must reach the page as it's sent, not when a buffer fills.
    context: {'shelf.io.buffer_output': false},
  );

  Handler _authed(
    FutureOr<Response> Function(Request request, WebSession session) inner,
  ) {
    return (request) {
      final session = auth.touch(_token(request));
      if (session == null) return _json(401, errorJson('unauthorized'));
      return inner(request, session);
    };
  }

  /// Bearer token (scripts) first, then the session cookie (browsers).
  static String? _token(Request request) {
    final authz = request.headers['authorization'];
    if (authz != null && authz.startsWith('Bearer ')) {
      return authz.substring('Bearer '.length).trim();
    }
    for (final part in (request.headers['cookie'] ?? '').split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2 && kv[0] == cookieName) return kv[1];
    }
    return null;
  }

  static String _clientIp(Request request) =>
      (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
          .remoteAddress
          .address;

  static Response _json(
    int status,
    Object body, {
    Map<String, String> headers = const {},
  }) => Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      ...headers,
    },
  );
}
