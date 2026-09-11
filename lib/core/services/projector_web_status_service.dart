import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reads a projector's *live* input/signal status from its web UI when
/// NTCONTROL can't. `QIN` / `QVX:NSGS1` return `ER401` while the projector is
/// in Standby — even mid pre-show, with a real picture streaming (verified
/// against a PT-RQ35: NTCONTROL said ER401, this page said
/// `3840x2160/60p (134.99kHz/59.99Hz)`, matching the real source).
///
/// `/cgi-bin/simple_status_hidden.cgi` is the page the projector's own
/// `preview.cgi` re-fetches whenever the RemoView WebSocket sends a `SIGNAL`
/// message — it reflects the real detected signal in every power state, not
/// just NTCONTROL-reachable ones. HTTP digest auth on port 80 (the same fixed
/// port the preview WebSocket uses — not the NTCONTROL port), reusing the
/// NTCONTROL login/password: on this projector the admin account serves both
/// interfaces. If a unit uses different web credentials this just fails
/// closed (null) — callers already treat that as "couldn't refresh".
class ProjectorWebStatusService {
  static const _timeout = Duration(seconds: 4);

  Future<WebSignalStatus?> fetchSignalStatus(
    String ip,
    String login,
    String password,
  ) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    client.authenticate = (Uri url, String scheme, String? realm) async {
      client.addCredentials(
        url,
        realm ?? '',
        HttpClientDigestCredentials(login, password),
      );
      return true;
    };
    try {
      final uri = Uri.http(ip, '/cgi-bin/simple_status_hidden.cgi', {
        'lang': 'e',
      });
      final req = await client.getUrl(uri).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      return _parse(body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // The page's empty-value cells omit the <span> entirely (just a stray
  // </span>), so the value group is optional, not just its content.
  static WebSignalStatus? _parse(String html) {
    final rows = <String, String>{};
    for (final m in RegExp(
      r'<td class="td_left"><span[^>]*>([^<]*)</span></td>'
      r'<td class="td_right">(?:<span[^>]*>)?([^<]*)</span>',
      dotAll: true,
    ).allMatches(html)) {
      rows[m.group(1)!.trim()] = m.group(2)!.trim();
    }
    if (rows.isEmpty) return null;
    return WebSignalStatus(
      input: rows['INPUT'] ?? '',
      signalName: rows['SIGNAL NAME'] ?? '',
      signalFrequency: rows['SIGNAL FREQUENCY'] ?? '',
    );
  }
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
