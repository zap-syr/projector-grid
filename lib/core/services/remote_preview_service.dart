import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A single "RemoView" preview session for one projector.
///
/// The Panasonic web UI opens `ws://<ip>/remotepreview` (subprotocol
/// `pj-cast-protocol`), sends `start`, keeps it alive with `alive` every 5 s,
/// and receives either binary JPEG frames (~480x270, ~1 fps) or one-word text
/// status messages. This mirrors that exchange and reduces it to a stream of
/// [RemotePreviewState]. Transport only — no Riverpod, no UI. The endpoint is
/// unauthenticated on every fleet model, `ws://` on port 80 (not the NTCONTROL
/// port). Full write-up in REMOTE_PREVIEW_PLAN.md.
class RemotePreviewController {
  RemotePreviewController({required this.host, this.port = 80});

  final String host;
  final int port;

  static const _connectTimeout = Duration(seconds: 5);
  static const _aliveInterval = Duration(seconds: 5);
  // Grace period to receive the first usable frame after connecting (or after
  // the last text status while still frame-less). Once a frame has arrived the
  // watchdog is disarmed for good: the projector legitimately goes silent for
  // tens of seconds when the source image is static, and a genuinely dropped
  // socket surfaces as onError/onDone instead.
  static const _firstFrameTimeout = Duration(seconds: 15);

  final _states = StreamController<RemotePreviewState>.broadcast();
  Stream<RemotePreviewState> get states => _states.stream;

  // Fires (no payload) on every WebSocket `SIGNAL` message — the projector's
  // own cue that its detected input signal just changed, in any power state.
  // Consumers use this to re-check signal/input without polling.
  final _signalEvents = StreamController<void>.broadcast();
  Stream<void> get signalEvents => _signalEvents.stream;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _aliveTimer;
  Timer? _firstFrameTimer;
  // Set once the first frame arrives; the first-frame watchdog never re-arms.
  bool _hadFrame = false;

  Uint8List? _lastFrame;
  RemotePreviewOverlay? _overlay;

  bool _started = false;
  bool _disposed = false;
  // Bumped on every (re)connect so a stale socket's callbacks are ignored.
  int _attempt = 0;

  /// Opens the socket. Safe to call once; further calls are no-ops.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _connect();
  }

  /// Enter / leave pre-show over this socket. The projector reports the actual
  /// state only over NTCONTROL (`QVX:PSMI1`), never here, so the caller tracks
  /// it separately.
  void setPreshow(bool on) => _send(on ? 'preshow:1' : 'preshow:0');

  /// Drops the current socket and connects again (the "Retry" button).
  void retry() {
    if (_disposed) return;
    _teardownSocket();
    _lastFrame = null;
    _overlay = null;
    _hadFrame = false;
    _emit(const RemotePreviewConnecting());
    _connect();
  }

  void dispose() {
    _disposed = true;
    _teardownSocket();
    unawaited(_states.close());
    unawaited(_signalEvents.close());
  }

  Future<void> _connect() async {
    final attempt = ++_attempt;
    final connectFuture = WebSocket.connect(
      'ws://$host:$port/remotepreview',
      protocols: const ['pj-cast-protocol'],
    );

    final WebSocket ws;
    try {
      ws = await connectFuture.timeout(_connectTimeout);
    } catch (_) {
      // The timed-out connect may still complete later — make sure that
      // socket is closed and any error is swallowed, then report failure.
      unawaited(connectFuture.then((s) => s.close()).catchError((_) {}));
      if (!_disposed && attempt == _attempt) {
        _emit(const RemotePreviewUnavailable());
      }
      return;
    }

    if (_disposed || attempt != _attempt) {
      unawaited(ws.close());
      return;
    }

    _ws = ws;
    _wsSub = ws.listen(
      _onData,
      onError: (_) => _onClosed(attempt),
      onDone: () => _onClosed(attempt),
      cancelOnError: false,
    );
    _send('start');
    _aliveTimer = Timer.periodic(_aliveInterval, (_) => _send('alive'));
    _armFirstFrame();
  }

  void _onData(dynamic data) {
    if (data is List<int>) {
      _hadFrame = true;
      _firstFrameTimer?.cancel();
      _firstFrameTimer = null;
      final frame = data is Uint8List ? data : Uint8List.fromList(data);
      _lastFrame = frame;
      _emit(RemotePreviewFrame(frame, overlay: _overlay));
      _send('receive');
      return;
    }
    if (data is! String) return;

    // A text status while still frame-less: keep waiting for that first frame.
    _armFirstFrame();

    switch (data) {
      case 'PING':
        _send('PONG');
        return;
      // ASPECT and TESTPATTERN keep the image (this firmware keeps streaming
      // test-pattern frames) and just annotate it; NONE clears the annotation.
      case 'NONE':
        _setOverlay(null);
      case 'ASPECT':
        _setOverlay(RemotePreviewOverlay.aspectMismatch);
      case 'TESTPATTERN':
        _setOverlay(RemotePreviewOverlay.testPattern);
      case 'NOSIGNAL':
        _emit(const RemotePreviewNotice(RemotePreviewNoticeKind.noSignal));
      case 'HDCP':
        _emit(const RemotePreviewNotice(RemotePreviewNoticeKind.hdcp));
      case 'STARTINGUP':
        _emit(const RemotePreviewNotice(RemotePreviewNoticeKind.startingUp));
      case 'ROTATE':
        _emit(const RemotePreviewNotice(RemotePreviewNoticeKind.rotating));
      case 'BLANK':
        _emit(const RemotePreviewNotice(RemotePreviewNoticeKind.blank));
      case 'IMPOSSIBLE':
      case 'CLOSE':
        // IMPOSSIBLE = projector can't produce an image; CLOSE = projector is
        // ending the stream (reboot, input switch). Either way the feed is
        // over — no auto-reconnect, the user can hit Retry.
        _teardownSocket();
        _emit(const RemotePreviewUnavailable());
        return;
      case 'SIGNAL':
        // The projector's own detected-signal state just changed — this is
        // the cue its web UI uses to re-fetch simple_status_hidden.cgi. We
        // don't fetch it ourselves (that's an HTTP concern, not transport),
        // just relay the event; see signalEvents.
        _signalEvents.add(null);
      case 'REFRESH':
      case 'CHANGING_PRE':
        // Refresh hints meant for the projector's own multi-frame page.
        break;
      default:
        break;
    }
    _send('receive');
  }

  // Update the frame annotation and, if a frame is already on screen, re-emit
  // it with the new tag. While frame-less the tag just waits for the next
  // frame.
  void _setOverlay(RemotePreviewOverlay? overlay) {
    _overlay = overlay;
    final frame = _lastFrame;
    if (frame != null) _emit(RemotePreviewFrame(frame, overlay: overlay));
  }

  void _onClosed(int attempt) {
    if (_disposed || attempt != _attempt) return;
    _teardownSocket();
    _emit(const RemotePreviewUnavailable());
  }

  void _armFirstFrame() {
    if (_hadFrame) return;
    _firstFrameTimer?.cancel();
    _firstFrameTimer = Timer(_firstFrameTimeout, () {
      if (_disposed || _hadFrame) return;
      _teardownSocket();
      _emit(const RemotePreviewUnavailable());
    });
  }

  void _send(String message) {
    try {
      _ws?.add(message);
    } catch (_) {
      // Socket already gone; _onClosed will have fired.
    }
  }

  void _emit(RemotePreviewState state) {
    if (!_states.isClosed) _states.add(state);
  }

  void _teardownSocket() {
    _aliveTimer?.cancel();
    _aliveTimer = null;
    _firstFrameTimer?.cancel();
    _firstFrameTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    final ws = _ws;
    _ws = null;
    if (ws != null) unawaited(ws.close());
  }
}

/// What the preview surface should show right now.
sealed class RemotePreviewState {
  const RemotePreviewState();
}

/// Opening (or re-opening) the socket.
class RemotePreviewConnecting extends RemotePreviewState {
  const RemotePreviewConnecting();
}

/// A decoded JPEG frame is available. [overlay] is set while the projector last
/// reported `TESTPATTERN` or `ASPECT` — the frame still shows, with a small
/// corner tag. Cleared by `NONE`.
class RemotePreviewFrame extends RemotePreviewState {
  const RemotePreviewFrame(this.jpeg, {this.overlay});

  final Uint8List jpeg;
  final RemotePreviewOverlay? overlay;
}

/// The feed is up but there is no image — the projector sent a status word.
class RemotePreviewNotice extends RemotePreviewState {
  const RemotePreviewNotice(this.kind);

  final RemotePreviewNoticeKind kind;
}

/// No feed: connect failed / timed out, the socket closed, the projector sent
/// `IMPOSSIBLE` or `CLOSE`, or the first frame never arrived within
/// [_firstFrameTimeout].
class RemotePreviewUnavailable extends RemotePreviewState {
  const RemotePreviewUnavailable();
}

/// A tag drawn over a still-visible frame.
enum RemotePreviewOverlay {
  testPattern('Test pattern'),
  aspectMismatch('Aspect differs');

  const RemotePreviewOverlay(this.label);

  final String label;
}

/// A status shown as centred text on the black plane, no image.
enum RemotePreviewNoticeKind {
  noSignal('No signal'),
  hdcp('HDCP-protected content'),
  startingUp('Starting up'),
  rotating('Image rotating'),
  blank('');

  const RemotePreviewNoticeKind(this.label);

  final String label;
}
