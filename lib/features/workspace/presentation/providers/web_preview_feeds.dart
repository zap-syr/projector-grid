import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/remote_preview_service.dart';
import '../../../../core/services/web_api.dart' show Json;
import '../../../../core/services/web_event_hub.dart';
import '../../domain/preview_signal_tag.dart';
import '../../domain/projector_node.dart';
import '../../domain/web_api_dto.dart';
import 'pre_show_provider.dart';
import 'preview_signal_status_provider.dart';
import 'remote_preview_provider.dart';
import 'workspace_provider.dart';

/// Remote Preview relayed to web pages (`GET /api/preview/{id}`, ROADMAP §5
/// *Remote Preview on the web*). The browser never opens the projector's
/// socket itself: every page — and the app's own preview dialog — shares the
/// one [remotePreviewProvider] feed per projector, which these subscriptions
/// keep alive while a page watches and release [grace] after the last one
/// leaves (so stepping ◀ ▶ back doesn't reconnect).
class WebPreviewFeeds {
  WebPreviewFeeds(
    this._ref, {
    required this.onHeartbeat,
    this.grace = const Duration(seconds: 5),
  });

  final Ref _ref;

  /// Keeps the session of a page that only watches from idling out; false
  /// (signed out) ends its stream.
  final bool Function(String token) onHeartbeat;
  final Duration grace;

  final Map<String, _Feed> _feeds = {};

  ProjectorNode? _node(String id) =>
      _ref.read(workspaceProvider).where((n) => n.id == id).firstOrNull;

  /// The projector's preview stream for one page; null for an unknown id.
  Stream<List<int>>? subscribe(String token, String nodeId) {
    final node = _node(nodeId);
    if (node == null) return null;
    final feed = _feeds[nodeId] ??= _open(node);
    feed.closing?.cancel();
    feed.closing = null;
    final frame = feed.frame;
    return feed.hub.subscribe(token, [
      (name: WebPreviewEvents.status, data: feed.status),
      if (frame != null)
        (name: WebPreviewEvents.frame, data: previewFrameJson(frame)),
    ]);
  }

  /// Whether a page is watching [nodeId] — Retry and Pre-show act on that
  /// feed, so without one there's nothing to act on.
  bool isOpen(String nodeId) => _feeds.containsKey(nodeId);

  /// Power, shutter or signal changed: the status may follow.
  void refresh() => _feeds.values.toList().forEach(_pushStatus);

  void closeAll() {
    for (final feed in _feeds.values.toList()) {
      _dispose(feed);
    }
  }

  _Feed _open(ProjectorNode node) {
    final id = node.id;
    late final _Feed feed;
    feed = _Feed(
      id,
      WebEventHub(
        onHeartbeat: onHeartbeat,
        onIdle: () {
          feed.closing?.cancel();
          feed.closing = Timer(grace, () => _dispose(feed));
        },
      ),
    );
    feed.subs.addAll([
      _ref.listen<RemotePreviewState>(
        remotePreviewProvider(node.ipAddress),
        (_, s) => _onPreview(feed, s),
      ),
      _ref.listen(
        previewSignalStatusProvider(node.ipAddress, node.login, node.password),
        (_, _) => _pushStatus(feed),
      ),
      _ref.listen(preShowProvider(id), (_, _) => _pushStatus(feed)),
    ]);
    final preview = _ref.read(remotePreviewProvider(node.ipAddress));
    if (preview is RemotePreviewFrame) feed.frame = preview.jpeg;
    feed.status = _status(node);
    return feed;
  }

  void _onPreview(_Feed feed, RemotePreviewState s) {
    _pushStatus(feed);
    if (s is! RemotePreviewFrame) {
      feed.frame = null;
      return;
    }
    // An overlay change re-emits the same image; only new ones go out.
    if (identical(s.jpeg, feed.frame)) return;
    feed.frame = s.jpeg;
    feed.hub.broadcast((
      name: WebPreviewEvents.frame,
      data: previewFrameJson(s.jpeg),
    ));
  }

  void _pushStatus(_Feed feed) {
    final node = _node(feed.nodeId);
    if (node == null) {
      // Removed from the project: nothing left to watch.
      _dispose(feed);
      return;
    }
    final status = _status(node);
    if (samePreviewStatusJson(feed.status, status)) return;
    feed.status = status;
    feed.hub.broadcast((name: WebPreviewEvents.status, data: status));
  }

  Json _status(ProjectorNode node) => previewStatusJson(
    preview: _ref.read(remotePreviewProvider(node.ipAddress)),
    signal: previewSignalTag(
      node,
      _ref.read(
        previewSignalStatusProvider(node.ipAddress, node.login, node.password),
      ),
    ),
    preShow: _ref.read(preShowProvider(node.id)),
  );

  void _dispose(_Feed feed) {
    if (_feeds[feed.nodeId] != feed) return;
    _feeds.remove(feed.nodeId);
    feed.closing?.cancel();
    for (final s in feed.subs) {
      s.close();
    }
    feed.hub.closeAll();
  }
}

class _Feed {
  _Feed(this.nodeId, this.hub);

  final String nodeId;
  final WebEventHub hub;
  final List<ProviderSubscription<Object?>> subs = [];
  Timer? closing;
  Json? status;
  Uint8List? frame;
}
