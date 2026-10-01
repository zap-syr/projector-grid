import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_api.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/core/services/web_event_hub.dart';
import 'package:shelf/shelf.dart';

class _Conn implements HttpConnectionInfo {
  _Conn(String ip) : remoteAddress = InternetAddress(ip);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 50000;
  @override
  int get localPort => 8080;
}

final _operatorHash = hashPin('9876', random: Random(2));

class _Source implements WebApiSource {
  final signedInSessions = <WebSession>[];
  final roleChanges = <WebRole>[];

  /// *Allow control*; on by default here.
  bool controlAllowed = true;

  @override
  String get projectName => 'Main Hall';
  @override
  final String viewerPinHash = hashPin('1234', random: Random(1));
  @override
  String? get operatorPinHash => controlAllowed ? _operatorHash : null;
  @override
  void roleChanged(WebSession session) => roleChanges.add(session.role);

  /// Bodies [dispatch] was handed; `{"bad": …}` counts as invalid.
  final dispatched = <Object?>[];
  @override
  Future<Json?> dispatch(Object? body, WebSession session) async {
    dispatched.add(body);
    return body is Map && body.containsKey('bad') ? null : {'ok': 1};
  }

  /// (op, body) pairs [alignmentOp] was handed; the op `bad` counts as invalid.
  final alignmentOps = <(String, Object?)>[];
  @override
  Json alignment() => {'active': alignmentOps.isNotEmpty};
  @override
  Future<Json?> alignmentOp(String op, Object? body, WebSession session) async {
    if (op == 'bad') return null;
    alignmentOps.add((op, body));
    return alignment();
  }

  /// Preview streams opened, as `id`; only `a` exists.
  final previews = <String>[];
  @override
  Stream<List<int>>? preview(String id, WebSession session) {
    if (id != 'a') return null;
    previews.add(id);
    return Stream.value(utf8.encode('event: status\ndata: {}\n\n'));
  }

  final retried = <String>[];
  @override
  bool previewRetry(String id) {
    if (id != 'a') return false;
    retried.add(id);
    return true;
  }

  /// (id, body) pairs [previewPreShow] was handed; only `{"on": bool}` is valid.
  final preShows = <(String, Object?)>[];
  @override
  Future<Json?> previewPreShow(
    String id,
    Object? body,
    WebSession session,
  ) async {
    if (body is! Map || body['on'] is! bool) return null;
    preShows.add((id, body));
    return {'on': body['on']};
  }

  @override
  Json config(WebRole role) => {'role': role.name};
  @override
  List<Json> projectors() => [
    {'id': 'a', 'name': 'PJ-01'},
    {'id': 'b', 'name': 'PJ-02'},
  ];
  @override
  List<Json> groups() => const [];
  @override
  List<WebEvent> snapshotEvents() => [(name: 'snapshot', data: 'S')];
  @override
  void signedIn(WebSession session) => signedInSessions.add(session);
}

void main() {
  late _Source source;
  late WebAuth auth;
  late WebEventHub hub;
  late Handler api;

  setUp(() {
    source = _Source();
    auth = WebAuth();
    hub = WebEventHub();
    api = WebApi(auth: auth, hub: hub, source: source).handler;
  });
  tearDown(() => hub.closeAll());

  Future<Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    String ip = '10.0.0.5',
  }) async => api(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
      headers: headers,
      context: {'shelf.io.connection_info': _Conn(ip)},
    ),
  );

  Future<Object?> jsonOf(Response r) async =>
      jsonDecode(await r.readAsString());

  Future<String> loginToken() async {
    final r = await send('POST', '/api/login', body: {'pin': '1234'});
    return ((await jsonOf(r)) as Map)['token'] as String;
  }

  group('/api/login', () {
    test('right PIN → token, role and an HttpOnly cookie', () async {
      final r = await send('POST', '/api/login', body: {'pin': '1234'});
      expect(r.statusCode, 200);
      final body = (await jsonOf(r)) as Map;
      expect(body['role'], 'viewer');
      expect(body['controlAllowed'], isTrue);
      expect(
        r.headers['set-cookie'],
        '${WebApi.cookieName}=${body['token']}; Path=/; HttpOnly; SameSite=Strict',
      );
      expect(source.signedInSessions.single.ip, '10.0.0.5');
    });

    test('wrong PIN → 401', () async {
      final r = await send('POST', '/api/login', body: {'pin': '9999'});
      expect(r.statusCode, 401);
      expect(await jsonOf(r), {'error': 'invalid_pin'});
    });

    test('bad bodies → 400', () async {
      expect((await send('POST', '/api/login', body: 'nope')).statusCode, 400);
      expect(
        (await send('POST', '/api/login', body: {'pin': 1234})).statusCode,
        400,
      );
      expect((await send('POST', '/api/login', body: [1])).statusCode, 400);
    });

    test('lockout → 429 with Retry-After', () async {
      for (var i = 0; i < WebAuth.maxFailures - 1; i++) {
        await send('POST', '/api/login', body: {'pin': '0000'});
      }
      final r = await send('POST', '/api/login', body: {'pin': '0000'});
      expect(r.statusCode, 429);
      expect(r.headers['retry-after'], '60');
      expect(await jsonOf(r), {'error': 'locked_out', 'retryAfter': 60});
    });
  });

  test('/api/session reports the project and whether signed in', () async {
    expect(await jsonOf(await send('GET', '/api/session')), {
      'projectName': 'Main Hall',
      'authenticated': false,
      'controlAllowed': true,
    });
    final token = await loginToken();
    expect(
      await jsonOf(
        await send(
          'GET',
          '/api/session',
          headers: {'cookie': 'other=1; ${WebApi.cookieName}=$token'},
        ),
      ),
      {
        'projectName': 'Main Hall',
        'authenticated': true,
        'role': 'viewer',
        'controlAllowed': true,
      },
    );
  });

  group('operator access', () {
    Future<Response> unlock(String token, String pin) => send(
      'POST',
      '/api/unlock',
      body: {'pin': pin},
      headers: {'authorization': 'Bearer $token'},
    );

    test('the Operator PIN logs straight in as operator', () async {
      final r = await send('POST', '/api/login', body: {'pin': '9876'});
      expect(((await jsonOf(r)) as Map)['role'], 'operator');
    });

    test('unlock → operator, lock → viewer, other tabs are told', () async {
      final token = await loginToken();
      final events = <String>[];
      final sub = hub
          .subscribe(token, const [])
          .map(utf8.decode)
          .listen(events.add);

      final wrong = await unlock(token, '1234');
      expect(wrong.statusCode, 401);
      expect(await jsonOf(wrong), {'error': 'invalid_pin'});

      final ok = await unlock(token, '9876');
      expect(await jsonOf(ok), {'role': 'operator', 'controlAllowed': true});
      final locked = await send(
        'POST',
        '/api/lock',
        headers: {'authorization': 'Bearer $token'},
      );
      expect(await jsonOf(locked), {'role': 'viewer', 'controlAllowed': true});

      await pumpEventQueue();
      expect(
        events.where((e) => e.startsWith('event: $accessEvent')),
        hasLength(2),
      );
      expect(source.roleChanges, [WebRole.operator, WebRole.viewer]);
      await sub.cancel();
    });

    test(
      'with Allow control off: no operator login, no unlock/lock routes',
      () async {
        source.controlAllowed = false;
        expect(
          (await send('POST', '/api/login', body: {'pin': '9876'})).statusCode,
          401,
        );
        final token = await loginToken();
        expect((await unlock(token, '9876')).statusCode, 404);
        expect(
          (await send(
            'POST',
            '/api/lock',
            headers: {'authorization': 'Bearer $token'},
          )).statusCode,
          404,
        );
        final session = await jsonOf(await send('GET', '/api/session'));
        expect((session as Map)['controlAllowed'], isFalse);
      },
    );

    group('/api/actions', () {
      Future<Response> act(String token, Object body) => send(
        'POST',
        '/api/actions',
        body: body,
        headers: {'authorization': 'Bearer $token'},
      );
      const request = {
        'targets': 'all',
        'action': {'power': 'on'},
      };

      test('operators only: a viewer gets 403, nothing is sent', () async {
        final r = await act(await loginToken(), request);
        expect(r.statusCode, 403);
        expect(await jsonOf(r), {'error': 'forbidden'});
        expect(source.dispatched, isEmpty);
      });

      test('an operator\'s request is dispatched', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        final r = await act(token, request);
        expect(r.statusCode, 200);
        expect(await jsonOf(r), {'ok': 1});
        expect(source.dispatched, [request]);
      });

      test('invalid requests → 400', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        expect((await act(token, {'bad': 1})).statusCode, 400);
        expect((await act(token, 'not json {')).statusCode, 400);
      });

      test('no route at all while Allow control is off', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        source.controlAllowed = false;
        expect((await act(token, request)).statusCode, 404);
      });
    });

    group('/api/alignment', () {
      Future<Response> op(String token, String name, {Object? body}) => send(
        'POST',
        '/api/alignment/$name',
        body: body,
        headers: {'authorization': 'Bearer $token'},
      );

      test('anyone signed in reads the state', () async {
        final r = await send(
          'GET',
          '/api/alignment',
          headers: {'authorization': 'Bearer ${await loginToken()}'},
        );
        expect(await jsonOf(r), {'active': false});
      });

      test('operators only: a viewer gets 403, nothing happens', () async {
        final r = await op(await loginToken(), 'enter');
        expect(r.statusCode, 403);
        expect(source.alignmentOps, isEmpty);
      });

      test('an operator\'s op runs, with or without a body', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        final r = await op(token, 'next');
        expect(r.statusCode, 200);
        expect(await jsonOf(r), {'active': true});
        await op(token, 'focus', body: {'id': 'b'});
        expect(source.alignmentOps.map((o) => o.$1), ['next', 'focus']);
        expect(source.alignmentOps.map((o) => o.$2), [
          null,
          {'id': 'b'},
        ]);
      });

      test('invalid ops and bodies → 400', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        expect((await op(token, 'bad')).statusCode, 400);
        expect((await op(token, 'focus', body: 'not json {')).statusCode, 400);
      });

      test('no route at all while Allow control is off', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        source.controlAllowed = false;
        expect((await op(token, 'exit')).statusCode, 404);
      });
    });

    group('/api/preview', () {
      Future<Response> post(String token, String path, {Object? body}) => send(
        'POST',
        path,
        body: body,
        headers: {'authorization': 'Bearer $token'},
      );

      test('anyone signed in watches; unknown projector → 404', () async {
        final h = {'authorization': 'Bearer ${await loginToken()}'};
        final r = await send('GET', '/api/preview/a', headers: h);
        expect(r.headers['content-type'], startsWith('text/event-stream'));
        expect(r.context['shelf.io.buffer_output'], isFalse);
        expect(await r.readAsString(), startsWith('event: status'));
        expect(
          (await send('GET', '/api/preview/zz', headers: h)).statusCode,
          404,
        );
        expect(source.previews, ['a']);
      });

      test('a viewer can retry, but not switch pre-show', () async {
        final token = await loginToken();
        expect((await post(token, '/api/preview/a/retry')).statusCode, 204);
        expect((await post(token, '/api/preview/zz/retry')).statusCode, 404);
        expect(source.retried, ['a']);
        final r = await post(
          token,
          '/api/preview/a/preshow',
          body: {'on': true},
        );
        expect(r.statusCode, 403);
        expect(source.preShows, isEmpty);
      });

      test('an operator switches pre-show; bad bodies → 400', () async {
        final token = await loginToken();
        await unlock(token, '9876');
        final r = await post(
          token,
          '/api/preview/a/preshow',
          body: {'on': true},
        );
        expect(await jsonOf(r), {'on': true});
        expect(
          (await post(
            token,
            '/api/preview/a/preshow',
            body: {'on': 1},
          )).statusCode,
          400,
        );
        expect(source.preShows.map((p) => p.$1), ['a']);
        expect(source.preShows.map((p) => p.$2), [
          {'on': true},
        ]);
      });
    });

    test('unlock needs a session', () async {
      expect(
        (await send('POST', '/api/unlock', body: {'pin': '9876'})).statusCode,
        401,
      );
    });
  });

  group('authenticated routes', () {
    test('401 without a session', () async {
      for (final path in [
        '/api/config',
        '/api/projectors',
        '/api/projectors/a',
        '/api/groups',
        '/api/alerts',
        '/api/alignment',
        '/api/events',
        '/api/preview/a',
      ]) {
        final r = await send('GET', path);
        expect(r.statusCode, 401, reason: path);
        expect(await jsonOf(r), {'error': 'unauthorized'});
      }
      expect((await send('POST', '/api/logout')).statusCode, 401);
    });

    test('bearer token and cookie both work', () async {
      final token = await loginToken();
      final byBearer = await send(
        'GET',
        '/api/config',
        headers: {'authorization': 'Bearer $token'},
      );
      expect(await jsonOf(byBearer), {'role': 'viewer'});
      final byCookie = await send(
        'GET',
        '/api/groups',
        headers: {'cookie': '${WebApi.cookieName}=$token'},
      );
      expect(byCookie.statusCode, 200);
    });

    test('data routes', () async {
      final h = {'authorization': 'Bearer ${await loginToken()}'};
      expect(
        (await jsonOf(await send('GET', '/api/projectors', headers: h)))
            as List,
        hasLength(2),
      );
      expect(await jsonOf(await send('GET', '/api/projectors/b', headers: h)), {
        'id': 'b',
        'name': 'PJ-02',
      });
      expect(
        (await send('GET', '/api/projectors/zz', headers: h)).statusCode,
        404,
      );
      expect(
        await jsonOf(await send('GET', '/api/alerts', headers: h)),
        isEmpty,
      );
      final r = await send('GET', '/api/nope', headers: h);
      expect(r.statusCode, 404);
      expect(r.headers['cache-control'], 'no-store');
    });

    test('/api/events streams the snapshot first', () async {
      final r = await send(
        'GET',
        '/api/events',
        headers: {'authorization': 'Bearer ${await loginToken()}'},
      );
      expect(r.headers['content-type'], startsWith('text/event-stream'));
      expect(r.context['shelf.io.buffer_output'], isFalse);
      final chunks = await r.read().map(utf8.decode).take(2).toList();
      expect(chunks, ['retry: 3000\n\n', 'event: snapshot\ndata: "S"\n\n']);
    });

    test('logout ends the session and clears the cookie', () async {
      final h = {'authorization': 'Bearer ${await loginToken()}'};
      final r = await send('POST', '/api/logout', headers: h);
      expect(r.statusCode, 204);
      expect(r.headers['set-cookie'], contains('Max-Age=0'));
      expect((await send('GET', '/api/config', headers: h)).statusCode, 401);
    });
  });
}
