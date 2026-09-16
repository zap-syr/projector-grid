import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/projector_web_status_service.dart';
import '../../../../core/services/remote_preview_service.dart';
import 'remote_preview_provider.dart';

part 'preview_signal_status_provider.g.dart';

/// Live input/signal for one projector's Remote Preview, driven by the
/// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
/// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
/// fully on (Standby, mid pre-show, still starting up), so the preview's
/// signal tag can't depend on them. This mirrors what the projector's own
/// `preview.cgi` does: it holds this value until the WebSocket sends a
/// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
/// may have opened onto an already-live signal), every `SIGNAL` event, and
/// every transition into a live frame (covers e.g. STARTINGUP → picture,
/// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
/// per *actual* signal change on this one projector, independent of frame
/// rate and of how many other tiles a multiview has open.
@riverpod
class PreviewSignalStatus extends _$PreviewSignalStatus {
  final _webStatus = ProjectorWebStatusService();
  late String _host;
  late String _login;
  late String _password;
  bool _fetching = false;
  bool _refreshQueued = false;
  DateTime? _lastSuccessAt;

  // How long a stale value keeps being shown once fetches start failing. A
  // one-off blip (network hiccup) should keep the last good read — see
  // _refresh's comment — but a genuinely dead endpoint (web credentials
  // changed, firmware update) should eventually surface as "unknown" so
  // consumers fall back to their NTCONTROL path instead of freezing on a
  // reading that may no longer be true, with nothing to tell them apart.
  static const _maxStaleness = Duration(minutes: 2);

  @override
  WebSignalStatus? build(String host, String login, String password) {
    _host = host;
    _login = login;
    _password = password;

    final notifier = ref.watch(remotePreviewProvider(host).notifier);
    final sub = notifier.signalEvents.listen((_) => _refresh());
    ref.onDispose(sub.cancel);

    var wasFrame = ref.read(remotePreviewProvider(host)) is RemotePreviewFrame;
    ref.listen(remotePreviewProvider(host), (previous, next) {
      final isFrame = next is RemotePreviewFrame;
      if (isFrame && !wasFrame) _refresh();
      wasFrame = isFrame;
    });

    // Best-effort initial read — don't block build() on it.
    _refresh();
    return null;
  }

  // Coalesces a burst of events (e.g. an HDMI handshake flapping) into at
  // most one extra fetch after the in-flight one finishes, so this node never
  // has more than one status request in the air at once.
  Future<void> _refresh() async {
    if (_fetching) {
      _refreshQueued = true;
      return;
    }
    _fetching = true;
    try {
      do {
        _refreshQueued = false;
        final result = await _webStatus.fetchSignalStatus(
          _host,
          _login,
          _password,
        );
        // The provider may have been torn down (dialog closed) mid-request.
        if (!ref.mounted) return;
        // A transient fetch failure (result == null) keeps the last known
        // value instead of clearing it — otherwise a single dropped request
        // sends every consumer back to their NTCONTROL fallback (stale/ER401
        // in the exact power states this provider exists to cover) with no
        // time bound, until the next SIGNAL event happens to succeed. But
        // that grace has a limit (_maxStaleness): once it's been too long
        // since the last successful fetch, drop back to null rather than
        // keep asserting a value that's had no chance to be re-confirmed.
        if (result != null) {
          _lastSuccessAt = DateTime.now();
          state = result;
        } else if (_lastSuccessAt == null ||
            DateTime.now().difference(_lastSuccessAt!) > _maxStaleness) {
          state = null;
        }
      } while (_refreshQueued);
    } finally {
      _fetching = false;
    }
  }
}
