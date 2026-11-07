import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/projector_web_status_service.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';

void main() {
  group('RemotePreviewController endpoints', () {
    late HttpServer notFound;
    late HttpServer full;
    late HttpServer preview;

    Future<HttpServer> refusing(int status) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        req.response.statusCode = status;
        req.response.close();
      });
      return server;
    }

    setUp(() async {
      // The RQ-style address on a PT-RZ34K: answered, never upgraded.
      notFound = await refusing(HttpStatus.notFound);
      // An RQ25K with both viewer slots taken.
      full = await refusing(HttpStatus.internalServerError);
      preview = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      preview.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (protocols) => protocols.first,
        );
        ws.listen((msg) {
          if (msg == 'start') ws.add(<int>[0xff, 0xd8, 0xff, 0xd9]);
        });
      });
    });

    tearDown(() async {
      await notFound.close(force: true);
      await full.close(force: true);
      await preview.close(force: true);
    });

    Future<RemotePreviewState> firstState(
      List<RemotePreviewEndpoint> endpoints,
    ) async {
      final controller = RemotePreviewController(
        host: '127.0.0.1',
        endpoints: endpoints,
      );
      addTearDown(controller.dispose);
      final state = controller.states.first;
      controller.start();
      return state.timeout(const Duration(seconds: 5));
    }

    test('a 404 moves on to the next endpoint', () async {
      final state = await firstState([
        RemotePreviewEndpoint(notFound.port, '/remotepreview'),
        RemotePreviewEndpoint(preview.port, '/'),
      ]);
      expect(state, isA<RemotePreviewFrame>());
    });

    test('refused upgrades everywhere end unavailable', () async {
      final state = await firstState([
        RemotePreviewEndpoint(full.port, '/remotepreview'),
        RemotePreviewEndpoint(notFound.port, '/'),
      ]);
      expect(state, isA<RemotePreviewUnavailable>());
    });

    test('once an endpoint served, its refusal skips the fallback', () async {
      // Serves one viewer, then answers 500 like a full RQ25K.
      final once = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => once.close(force: true));
      var served = false;
      once.listen((req) async {
        if (served) {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
          return;
        }
        served = true;
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (protocols) => protocols.first,
        );
        ws.listen((msg) {
          if (msg == 'start') ws.add(<int>[0xff, 0xd8, 0xff, 0xd9]);
        });
      });
      var fallbackHits = 0;
      final fallback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => fallback.close(force: true));
      fallback.listen((req) {
        fallbackHits++;
        req.response.statusCode = HttpStatus.notFound;
        req.response.close();
      });

      final controller = RemotePreviewController(
        host: '127.0.0.1',
        endpoints: [
          RemotePreviewEndpoint(once.port, '/remotepreview'),
          RemotePreviewEndpoint(fallback.port, '/'),
        ],
      );
      addTearDown(controller.dispose);
      final frame = controller.states.first;
      controller.start();
      expect(
        await frame.timeout(const Duration(seconds: 5)),
        isA<RemotePreviewFrame>(),
      );

      final unavailable = controller.states.firstWhere(
        (s) => s is RemotePreviewUnavailable,
      );
      controller.retry();
      await unavailable.timeout(const Duration(seconds: 5));
      expect(fallbackHits, 0);
    });

    test('a refused connect does not try the next endpoint', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final state = await firstState([
        RemotePreviewEndpoint(port, '/remotepreview'),
        RemotePreviewEndpoint(preview.port, '/'),
      ]);
      expect(state, isA<RemotePreviewUnavailable>());
    });
  });

  test('a host without either status page is not probed again', () async {
    var hits = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) {
      hits++;
      req.response.statusCode = HttpStatus.notFound;
      req.response.close();
    });
    final service = ProjectorWebStatusService();
    addTearDown(service.dispose);
    final host = '127.0.0.1:${server.port}';

    expect(await service.fetchSignalStatus(host, 'admin', 'pw'), isNull);
    expect(hits, 2);
    expect(await service.fetchSignalStatus(host, 'admin', 'pw'), isNull);
    expect(hits, 2);
  });

  group('parseWebSignalStatus', () {
    test('PT-RZ34K preview_input.cgi rows', () {
      // Trimmed from a live PT-RZ34KE page.
      const html =
          '<tr class="input_right_table_tr"><td class="td_left"><span '
          'class="common_stringcolW">INPUT</span></td><td class="td_right">'
          '<span class="common_stringcolW">HDMI</span></td></tr>'
          '<tr class="input_right_table_tr"><td class="td_left"><span '
          'class="common_stringcolW">SIGNAL NAME</span></td><td '
          'class="td_right"><span class="common_stringcolW">1920x1200/50'
          '</span></td></tr><tr class="input_right_table_tr"><td '
          'class="td_left"><span class="common_stringcolW">SIGNAL FREQUENCY'
          '</span></td><td class="td_right"><span class="common_stringcolW">'
          '62.25kHz/50.00Hz</span></td></tr>';
      final status = parseWebSignalStatus(html)!;
      expect(status.input, 'HDMI');
      expect(status.signalName, '1920x1200/50');
      expect(status.signalFrequency, '62.25kHz/50.00Hz');
      expect(status.hasSignal, isTrue);
    });

    test('rows without INPUT are not a status', () {
      // simple_status.cgi has td_left/td_right rows too (LIGHT SOURCE, ...).
      const html =
          '<td class="td_left"><span class="common_stringcolW">LIGHT SOURCE'
          '</span></td><td class="td_right"><span>2169H</span>';
      expect(parseWebSignalStatus(html), isNull);
    });
  });
}
