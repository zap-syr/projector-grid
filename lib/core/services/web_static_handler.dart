import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';

/// Where `web_ui/` builds to (`npm run build`), bundled as Flutter assets.
const webAssetRoot = 'assets/web';
const _indexKey = '$webAssetRoot/index.html';
const _hashedDir = '$webAssetRoot/assets/';

const webUiNotBuiltMessage =
    'Web UI not built — run `npm run build` in web_ui/, then rebuild the app.';

/// Asset key for a request path (relative, no leading slash): `/` is the
/// page itself, anything else maps one-to-one into [webAssetRoot].
String webAssetKeyFor(String path) =>
    path.isEmpty ? _indexKey : '$webAssetRoot/$path';

String webContentTypeFor(String key) {
  final ext = key.substring(key.lastIndexOf('.') + 1).toLowerCase();
  return switch (ext) {
    'html' => 'text/html; charset=utf-8',
    'js' => 'text/javascript; charset=utf-8',
    'css' => 'text/css; charset=utf-8',
    'json' => 'application/json; charset=utf-8',
    'svg' => 'image/svg+xml',
    'png' => 'image/png',
    'ico' => 'image/x-icon',
    'woff2' => 'font/woff2',
    'woff' => 'font/woff',
    'wav' => 'audio/wav',
    _ => 'application/octet-stream',
  };
}

/// Vite content-hashes everything under `assets/`, so those never change at
/// a given URL; the page and root files must be revalidated so a new app
/// build is picked up.
String webCacheControlFor(String key) => key.startsWith(_hashedDir)
    ? 'public, max-age=31536000, immutable'
    : 'no-cache';

/// Serves the built page from [bundle]. [assets] is the bundle's asset list;
/// only keys in it are served, so a path can't reach outside [webAssetRoot].
Handler webStaticHandler(AssetBundle bundle, Set<String> assets) {
  return (Request request) async {
    if (request.method != 'GET') {
      return Response(405, headers: {'allow': 'GET'});
    }
    final segments = request.url.pathSegments;
    if (segments.any((s) => s.startsWith('.'))) return Response.notFound(null);

    final key = webAssetKeyFor(segments.join('/'));
    if (!assets.contains(key)) {
      if (key == _indexKey) {
        return Response.ok(
          webUiNotBuiltMessage,
          headers: {
            'content-type': 'text/plain; charset=utf-8',
            'cache-control': 'no-cache',
          },
        );
      }
      return Response.notFound(null);
    }

    final data = await bundle.load(key);
    return Response.ok(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      headers: {
        'content-type': webContentTypeFor(key),
        'cache-control': webCacheControlFor(key),
      },
    );
  };
}
