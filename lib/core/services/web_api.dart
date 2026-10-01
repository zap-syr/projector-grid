import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'web_auth.dart';
import 'web_event_hub.dart';

typedef Json = Map<String, Object?>;

Json sessionJson({
  required String projectName,
  required bool controlAllowed,
  WebRole? role,
}) => {
  'projectName': projectName,
  'authenticated': role != null,
  'role': ?role?.name,
  'controlAllowed': controlAllowed,
};

Json loginJson(WebSession s, {required bool controlAllowed}) => {
  'token': s.token,
  'role': s.role.name,
  'controlAllowed': controlAllowed,
};

/// A session's role and whether *Unlock control* is available: the reply to
/// unlock / lock, and the `access` event when either changes.
Json accessJson(WebRole role, {required bool controlAllowed}) => {
  'role': role.name,
  'controlAllowed': controlAllowed,
};

/// SSE event name for [accessJson], sent to one session's pages.
const accessEvent = 'access';

Json errorJson(String error, {int? retryAfter}) => {
  'error': error,
  'retryAfter': ?retryAfter,
};

/// What the API serves; implemented over the providers by
/// `web_server_provider.dart`, so no app logic lives in the server.
abstract interface class WebApiSource {
  String get projectName;
  String get viewerPinHash;

  /// Null while *Allow control* is off: no operator login, no unlock.
  String? get operatorPinHash;
  Json config(WebRole role);
  List<Json> projectors();
  List<Json> groups();

  /// The first events a new `/api/events` stream receives.
  List<WebEvent> snapshotEvents();

  void signedIn(WebSession session);

  /// After *Unlock control* or *Lock*.
  void roleChanged(WebSession session);

  /// `POST /api/actions` from an operator: [body] is the decoded JSON. Null
  /// when it isn't a valid action request, else the dispatch summary.
  Future<Json?> dispatch(Object? body, WebSession session);

  /// Alignment mode's state (`GET /api/alignment`).
  Json alignment();

  /// `POST /api/alignment/{op}` from an operator: [body] is the decoded JSON
  /// (null when empty). Null when the op or its body is invalid, else the
  /// new state.
  Future<Json?> alignmentOp(String op, Object? body, WebSession session);

  /// `GET /api/preview/{id}`: the projector's Remote Preview as SSE; null
  /// for an unknown projector.
  Stream<List<int>>? preview(String id, WebSession session);

  /// `POST /api/preview/{id}/retry`: reconnects a watched feed; false when
  /// no page watches [id].
  bool previewRetry(String id);

  /// `POST /api/preview/{id}/preshow` from an operator: [body] is the decoded
  /// JSON. Null when it's invalid or the projector can't take it now (not in
  /// Standby, no live feed), else the preview status.
  Future<Json?> previewPreShow(String id, Object? body, WebSession session);
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
          ..post('/api/unlock', _authed(_unlock))
          ..post('/api/lock', _authed((_, s) => _lock(s)))
          ..post('/api/actions', _authed(_actions))
          ..get(
            '/api/alignment',
            _authed((_, _) => _json(200, source.alignment())),
          )
          ..post(
            '/api/alignment/<op>',
            (Request r, String op) =>
                _authed((r, s) => _alignment(r, s, op))(r),
          )
          ..get(
            '/api/preview/<id>',
            (Request r, String id) => _authed((_, s) => _preview(s, id))(r),
          )
          ..post(
            '/api/preview/<id>/retry',
            (Request r, String id) => _authed(
              (_, _) => source.previewRetry(id)
                  ? Response(204, headers: {'cache-control': 'no-store'})
                  : _json(404, errorJson('not_found')),
            )(r),
          )
          ..post(
            '/api/preview/<id>/preshow',
            (Request r, String id) => _authed(
              (r, s) => _operatorPost(
                r,
                s,
                (body) => source.previewPreShow(id, body, s),
              ),
            )(r),
          )
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

  bool get _controlAllowed => source.operatorPinHash != null;

  /// `{"pin": "<string>"}` → the PIN; null for anything else.
  static Future<String?> _readPin(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final pin = body is Map ? body['pin'] : null;
      return pin is String ? pin : null;
    } on FormatException {
      return null;
    }
  }

  Future<Response> _login(Request request) async {
    final pin = await _readPin(request);
    if (pin == null) return _json(400, errorJson('bad_request'));

    final result = auth.login(
      ip: _clientIp(request),
      pin: pin,
      viewerPinHash: source.viewerPinHash,
      operatorPinHash: source.operatorPinHash,
    );
    if (result is! LoginOk) return _pinRefused(result);
    final session = result.session;
    source.signedIn(session);
    return _json(
      200,
      loginJson(session, controlAllowed: _controlAllowed),
      headers: {
        'set-cookie':
            '$cookieName=${session.token}; Path=/; HttpOnly; SameSite=Strict',
      },
    );
  }

  Future<Response> _unlock(Request request, WebSession session) async {
    // With Allow control off the route doesn't exist.
    final operatorPinHash = source.operatorPinHash;
    if (operatorPinHash == null) return _json(404, errorJson('not_found'));
    final pin = await _readPin(request);
    if (pin == null) return _json(400, errorJson('bad_request'));

    final result = auth.unlock(session, pin, operatorPinHash);
    if (result is! LoginOk) return _pinRefused(result);
    return _roleChanged(session);
  }

  Response _lock(WebSession session) {
    if (!_controlAllowed) return _json(404, errorJson('not_found'));
    auth.lock(session);
    return _roleChanged(session);
  }

  /// Operator-only; the server enforces it, hidden buttons aren't the guard.
  Future<Response> _actions(Request request, WebSession session) =>
      _operatorPost(request, session, (body) => source.dispatch(body, session));

  Future<Response> _alignment(Request request, WebSession session, String op) =>
      _operatorPost(
        request,
        session,
        (body) => source.alignmentOp(op, body, session),
        allowEmpty: true,
      );

  /// The guards every control route shares: no route while *Allow control*
  /// is off, 403 for a viewer, 400 for a body that isn't JSON or that
  /// [handle] rejects (null). [allowEmpty] lets a body-less op through as null.
  Future<Response> _operatorPost(
    Request request,
    WebSession session,
    Future<Json?> Function(Object? body) handle, {
    bool allowEmpty = false,
  }) async {
    if (!_controlAllowed) return _json(404, errorJson('not_found'));
    if (session.role != WebRole.operator) {
      return _json(403, errorJson('forbidden'));
    }
    final text = await request.readAsString();
    final Object? body;
    try {
      body = allowEmpty && text.trim().isEmpty ? null : jsonDecode(text);
    } on FormatException {
      return _json(400, errorJson('bad_request'));
    }
    final result = await handle(body);
    return result == null
        ? _json(400, errorJson('bad_request'))
        : _json(200, result);
  }

  /// Tells the session's other tabs, logs it, and replies with the new access.
  Response _roleChanged(WebSession session) {
    final access = accessJson(session.role, controlAllowed: _controlAllowed);
    hub.sendTo(session.token, (name: accessEvent, data: access));
    source.roleChanged(session);
    return _json(200, access);
  }

  static Response _pinRefused(LoginResult result) => switch (result) {
    LoginLockedOut(:final retryAfter) => _lockedOut(retryAfter),
    _ => _json(401, errorJson('invalid_pin')),
  };

  static Response _lockedOut(Duration retryAfter) {
    final seconds = (retryAfter.inMilliseconds / 1000).ceil();
    return _json(
      429,
      errorJson('locked_out', retryAfter: seconds),
      headers: {'retry-after': '$seconds'},
    );
  }

  Response _session(Request request) {
    final session = auth.touch(_token(request));
    return _json(
      200,
      sessionJson(
        projectName: source.projectName,
        controlAllowed: _controlAllowed,
        role: session?.role,
      ),
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

  Response _events(WebSession session) =>
      _sse(hub.subscribe(session.token, source.snapshotEvents()));

  Response _preview(WebSession session, String id) {
    final stream = source.preview(id, session);
    return stream == null ? _json(404, errorJson('not_found')) : _sse(stream);
  }

  static Response _sse(Stream<List<int>> stream) => Response.ok(
    stream,
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
