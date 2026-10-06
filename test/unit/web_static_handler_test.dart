import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_server_service.dart';
import 'package:projector_grid/core/services/web_static_handler.dart';
import 'package:shelf/shelf.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(files[key]!));
}

Future<Response> _get(Handler handler, String path, {String method = 'GET'}) =>
    Future.value(handler(Request(method, Uri.parse('http://localhost$path'))));

void main() {
  const built = {
    'assets/web/index.html': '<!doctype html>',
    'assets/web/favicon.svg': '<svg/>',
    'assets/web/.gitkeep': '',
    'assets/web/assets/index-AbC123.js': 'console.log(1)',
    'assets/web/assets/geist-latin-wght-normal-X.woff2': 'font',
    'assets/icons/secret.png': 'not web',
  };
  final handler = webStaticHandler(_FakeBundle(built), built.keys.toSet());

  group('webAssetKeyFor', () {
    test('root is the page', () {
      expect(webAssetKeyFor(''), 'assets/web/index.html');
    });
    test('other paths map into the web root', () {
      expect(webAssetKeyFor('assets/a.js'), 'assets/web/assets/a.js');
    });
  });

  group('content type and caching', () {
    test('content types by extension', () {
      expect(webContentTypeFor('x/index.html'), 'text/html; charset=utf-8');
      expect(webContentTypeFor('x/a.JS'), 'text/javascript; charset=utf-8');
      expect(webContentTypeFor('x/a.woff2'), 'font/woff2');
      expect(webContentTypeFor('x/alert_critical-AbC.wav'), 'audio/wav');
      expect(webContentTypeFor('x/a.bin'), 'application/octet-stream');
    });
    test('hashed assets are immutable, the rest revalidates', () {
      expect(
        webCacheControlFor('assets/web/assets/index-AbC123.js'),
        contains('immutable'),
      );
      expect(webCacheControlFor('assets/web/index.html'), 'no-cache');
      expect(webCacheControlFor('assets/web/favicon.svg'), 'no-cache');
    });
  });

  group('webStaticHandler', () {
    test('serves the page at /', () async {
      final r = await _get(handler, '/');
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], 'text/html; charset=utf-8');
      expect(r.headers['cache-control'], 'no-cache');
      expect(await r.readAsString(), '<!doctype html>');
    });

    test('serves hashed assets with long caching', () async {
      final r = await _get(handler, '/assets/index-AbC123.js');
      expect(r.statusCode, 200);
      expect(r.headers['cache-control'], contains('immutable'));
      expect(await r.readAsString(), 'console.log(1)');
    });

    test(
      '404 for unknown files, dotfiles and paths outside the web root',
      () async {
        expect((await _get(handler, '/nope.js')).statusCode, 404);
        expect((await _get(handler, '/.gitkeep')).statusCode, 404);
        expect((await _get(handler, '/../icons/secret.png')).statusCode, 404);
        expect(
          (await _get(handler, '/%2E%2E/icons/secret.png')).statusCode,
          404,
        );
      },
    );

    test('only GET is allowed', () async {
      final r = await _get(handler, '/', method: 'POST');
      expect(r.statusCode, 405);
      expect(r.headers['allow'], 'GET');
    });

    test('explains how to build when the page is missing', () async {
      final empty = webStaticHandler(_FakeBundle(const {}), const {});
      final r = await _get(empty, '/');
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], startsWith('text/plain'));
      expect(await r.readAsString(), webUiNotBuiltMessage);
      expect((await _get(empty, '/assets/a.js')).statusCode, 404);
    });
  });

  test('security headers are added to every response', () async {
    final secured = const Pipeline()
        .addMiddleware(addWebSecurityHeaders())
        .addHandler(handler);
    for (final path in ['/', '/nope.js']) {
      final r = await _get(secured, path);
      webSecurityHeaders.forEach((k, v) => expect(r.headers[k], v));
    }
  });
}
