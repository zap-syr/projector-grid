import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/remote_preview_service.dart';

part 'remote_preview_provider.g.dart';

/// Live "RemoView" preview feed for one projector, keyed by its host (IP).
///
/// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
/// listen and is disposed — closing the socket — when the last widget stops
/// watching, so dismissing the preview dialog tears the feed down. Two
/// viewports on the same host (e.g. the menu and the table hit back to back)
/// share one socket. Deliberately shell-agnostic: no navigation or window
/// assumptions live here or in the controller, so the §5.3 migration to real
/// OS windows only swaps the widget wrapper.
@riverpod
class RemotePreview extends _$RemotePreview {
  RemotePreviewController? _controller;

  @override
  RemotePreviewState build(String host) {
    final controller = RemotePreviewController(host: host);
    _controller = controller;

    final sub = controller.states.listen((s) => state = s);
    ref.onDispose(() {
      sub.cancel();
      controller.dispose();
    });

    controller.start();
    return const RemotePreviewConnecting();
  }

  /// Re-open the socket after a failure.
  void retry() => _controller?.retry();

  /// Enter / leave pre-show (`preshow:1` / `preshow:0`) over the socket.
  void setPreshow(bool on) => _controller?.setPreshow(on);

  /// Fires on every WebSocket `SIGNAL` message — see
  /// [RemotePreviewController.signalEvents].
  Stream<void> get signalEvents =>
      _controller?.signalEvents ?? const Stream<void>.empty();
}
