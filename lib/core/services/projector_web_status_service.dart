import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reads a projector's *live* input/signal status from its web UI when
/// NTCONTROL can't. `QIN` / `QVX:NSGS1` return `ER401` while the projector is
/// in Standby — even mid pre-show, with a real picture streaming (verified
/// against a PT-RQ25K: NTCONTROL said ER401, this page said
/// `3840x2160/60p (134.99kHz/59.99Hz)`, matching the real source).
///
/// `/cgi-bin/simple_status_hidden.cgi` is the page the projector's own
/// `preview.cgi` re-fetches whenever the RemoView WebSocket sends a `SIGNAL`
/// message — it reflects the real detected signal in every power state, not
/// just NTCONTROL-reachable ones. PT-RZ34K firmware has no such page (404);
/// its `preview_input.cgi` carries the same INPUT / SIGNAL NAME / SIGNAL
/// FREQUENCY rows in the same markup. HTTP digest auth on port 80 (not the
/// NTCONTROL port), reusing the NTCONTROL login/password: on these projectors
/// the admin account serves both interfaces. If a unit uses different web
/// credentials this just fails closed (null) — callers already treat that as
/// "couldn't refresh".
class ProjectorWebStatusService {
  static const _timeout = Duration(seconds: 4);
  static const _pages = [
    '/cgi-bin/simple_status_hidden.cgi',
    '/cgi-bin/preview_input.cgi',
  ];

  // Per host: the page that answered last, so the 404 on the first page is
  // paid once per service, not on every SIGNAL event.
  final _pageByHost = <String, int>{};

  // Reused across calls so Digest auth's credential/nonce cache actually
  // helps — a fresh HttpClient per call paid the 401-challenge round trip
  // every single time, doubling latency on the SIGNAL-event-driven fetch
  // path this service exists to keep fast.
  HttpClient? _client;

  HttpClient _clientFor(String login, String password) {
    final client = _client ??= (HttpClient()..connectionTimeout = _timeout);
    client.authenticate = (Uri url, String scheme, String? realm) async {
      client.addCredentials(
        url,
        realm ?? '',
        HttpClientDigestCredentials(login, password),
      );
      return true;
    };
    return client;
  }

  void dispose() {
    _client?.close(force: true);
    _client = null;
  }

  Future<WebSignalStatus?> fetchSignalStatus(
    String ip,
    String login,
    String password,
  ) async {
    final client = _clientFor(login, password);
    final first = _pageByHost[ip] ?? 0;
    try {
      for (var i = 0; i < _pages.length; i++) {
        final page = (first + i) % _pages.length;
        final uri = Uri.http(ip, _pages[page], {'lang': 'e'});
        final req = await client.getUrl(uri).timeout(_timeout);
        final res = await req.close().timeout(_timeout);
        if (res.statusCode == HttpStatus.notFound) {
          await res.drain<void>();
          continue;
        }
        if (res.statusCode != 200) {
          await res.drain<void>();
          return null;
        }
        _pageByHost[ip] = page;
        final body = await res.transform(utf8.decoder).join();
        return parseWebSignalStatus(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// The INPUT / SIGNAL NAME / SIGNAL FREQUENCY rows of either status page.
/// The page's empty-value cells omit the <span> entirely (just a stray
/// </span>), so the value group is optional, not just its content. Tags are
/// usually byte-adjacent but tolerate whitespace between them in case a
/// firmware revision pretty-prints the page. Null when the page has no
/// INPUT row: `preview_input.cgi` also has td_left/td_right rows of its own.
WebSignalStatus? parseWebSignalStatus(String html) {
  final rows = <String, String>{};
  for (final m in RegExp(
    r'<td class="td_left"><span[^>]*>([^<]*)</span></td>\s*'
    r'<td class="td_right">(?:<span[^>]*>)?([^<]*)</span>',
    dotAll: true,
  ).allMatches(html)) {
    rows[m.group(1)!.trim()] = m.group(2)!.trim();
  }
  final input = rows['INPUT'];
  if (input == null) return null;
  return WebSignalStatus(
    input: input,
    signalName: rows['SIGNAL NAME'] ?? '',
    signalFrequency: rows['SIGNAL FREQUENCY'] ?? '',
  );
}

/// A row from the web UI's status page. No detected signal (not a fetch
/// failure — that's `null`) shows as either an empty [signalName] or a
/// dash-run placeholder (`---`, likewise `---kHz/---Hz` for [signalFrequency])
/// — check [hasSignal] rather than `signalName.isEmpty`.
class WebSignalStatus {
  const WebSignalStatus({
    required this.input,
    required this.signalName,
    required this.signalFrequency,
  });

  final String input;
  final String signalName;
  final String signalFrequency;

  bool get hasSignal {
    final s = signalName.trim();
    return s.isNotEmpty && !RegExp(r'^-+$').hasMatch(s);
  }
}
