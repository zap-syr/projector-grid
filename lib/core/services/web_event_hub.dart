import 'dart:async';
import 'dart:convert';

typedef WebEvent = ({String name, Object? data});

List<int> encodeSseEvent(WebEvent e) =>
    utf8.encode('event: ${e.name}\ndata: ${jsonEncode(e.data)}\n\n');

class _Client {
  final String token;
  final StreamController<List<int>> controller;
  _Client(this.token, this.controller);
}

/// Server-Sent Events fan-out: one stream per connected page, a heartbeat
/// comment so proxies and phones keep idle connections open.
class WebEventHub {
  WebEventHub({this.heartbeat = const Duration(seconds: 15), this.onHeartbeat});

  final Duration heartbeat;

  /// Called per client on every heartbeat — keeps the session of a page
  /// that only listens from idling out. Returning false (session gone)
  /// ends that client's stream.
  final bool Function(String token)? onHeartbeat;

  final _clients = <_Client>[];
  Timer? _timer;

  int get clientCount => _clients.length;

  Stream<List<int>> subscribe(String token, Iterable<WebEvent> initial) {
    late final _Client client;
    final controller = StreamController<List<int>>(
      onCancel: () => _remove(client),
    );
    client = _Client(token, controller);
    _clients.add(client);
    _timer ??= Timer.periodic(heartbeat, (_) => _beat());
    controller.add(utf8.encode('retry: 3000\n\n'));
    initial.map(encodeSseEvent).forEach(controller.add);
    return controller.stream;
  }

  void broadcast(WebEvent event) {
    if (_clients.isEmpty) return;
    final bytes = encodeSseEvent(event);
    for (final c in _clients) {
      c.controller.add(bytes);
    }
  }

  /// Sends [event] to [token]'s pages only (every tab sharing that session).
  void sendTo(String token, WebEvent event) {
    final bytes = encodeSseEvent(event);
    for (final c in _clients.where((c) => c.token == token)) {
      c.controller.add(bytes);
    }
  }

  /// Ends the streams of [token]'s pages, after sending [last] if given.
  void close(String token, {WebEvent? last}) =>
      _closeWhere((c) => c.token == token, last);

  void closeAll({WebEvent? last}) => _closeWhere((_) => true, last);

  void _closeWhere(bool Function(_Client) test, WebEvent? last) {
    for (final c in _clients.where(test).toList()) {
      if (last != null) c.controller.add(encodeSseEvent(last));
      c.controller.close();
      _remove(c);
    }
  }

  void _remove(_Client c) {
    _clients.remove(c);
    if (_clients.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _beat() {
    final ping = utf8.encode(': ping\n\n');
    for (final c in List.of(_clients)) {
      if (onHeartbeat?.call(c.token) ?? true) {
        c.controller.add(ping);
      } else {
        c.controller.close();
        _remove(c);
      }
    }
  }
}
