import 'dart:async';
import 'dart:isolate';

import 'app_log_file.dart';
import 'panasonic_protocol_service.dart';

enum _Op {
  checkConnection,
  sendCommand,
  sendRawCommand,
  sendRawCommandPreservingErrorCodes,
  sendQuickQuery,
  pollProjectorTelemetry,
}

/// [PanasonicProtocolService] with every NTCONTROL exchange run on a
/// long-lived worker isolate. A poll cycle at 150 projectors is ~2,000 TCP
/// connections; on the UI isolate their socket events kept it busy for the
/// whole cycle and card drags stalled (OPTIMIZATION_PLAN.md §3.3). Here the
/// UI isolate only sees one message per call.
///
/// Overrides every public method except [scanNetwork], which the Add
/// Projectors Discover tab runs in-process: a one-off sweep while a modal
/// dialog is open, nothing else on the UI to stall. A public method
/// added to the base class must be routed here too, or it runs on the UI
/// isolate again.
class IsolateProtocolService extends PanasonicProtocolService {
  IsolateProtocolService() {
    _replies.listen(_onReply);
    _errors.listen(_onUncaught);
    // Not fatal: an uncaught error in one exchange would otherwise kill the
    // worker, and every call after it would wait forever.
    _worker = Isolate.spawn(
      _workerMain,
      _replies.sendPort,
      errorsAreFatal: false,
      onError: _errors.sendPort,
    );
  }

  final _replies = ReceivePort();
  final _errors = ReceivePort();
  final _pending = <int, Completer<Object?>>{};
  final _workerPort = Completer<SendPort>();
  late final Future<Isolate> _worker;
  var _nextId = 0;

  void _onReply(Object? message) {
    switch (message) {
      case final SendPort port:
        _workerPort.complete(port);
      // A call that threw in the worker: the caller gets the error, the app
      // log gets the worker's stack, which the caller's doesn't show.
      case (String error, String stack):
        AppLog.error('Protocol worker', error, stack);
      case (int id, bool ok, Object? value):
        final completer = _pending.remove(id)!;
        if (ok) {
          completer.complete(value);
        } else {
          completer.completeError(value!);
        }
    }
  }

  // The worker's uncaught errors arrive as `[error, stack]`, both text.
  void _onUncaught(Object? message) {
    final [error, stack] = message as List<Object?>;
    AppLog.error('Protocol worker, uncaught', error!, stack);
  }

  Future<T> _call<T>(_Op op, List<Object?> args) async {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    (await _workerPort.future).send((id, op, args));
    return await completer.future as T;
  }

  Future<void> dispose() async {
    (await _worker).kill(priority: Isolate.immediate);
    _replies.close();
    _errors.close();
  }

  @override
  Future<bool> checkConnection(String ip, int port) =>
      _call(_Op.checkConnection, [ip, port]);

  @override
  Future<bool> sendCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) => _call(_Op.sendCommand, [ip, port, login, password, cmd]);

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) => _call(_Op.sendRawCommand, [ip, port, login, password, cmd]);

  @override
  Future<String?> sendRawCommandPreservingErrorCodes(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) => _call(_Op.sendRawCommandPreservingErrorCodes, [
    ip,
    port,
    login,
    password,
    cmd,
  ]);

  @override
  Future<String?> sendQuickQuery(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) => _call(_Op.sendQuickQuery, [ip, port, login, password, cmd]);

  @override
  Future<(ProbeResult, Map<String, dynamic>?)> pollProjectorTelemetry(
    String ip,
    int port,
    String login,
    String password, {
    int concurrency = 2,
    bool withSerial = true,
  }) => _call(_Op.pollProjectorTelemetry, [
    ip,
    port,
    login,
    password,
    concurrency,
    withSerial,
  ]);

  static void _workerMain(SendPort replies) {
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    final service = PanasonicProtocolService();
    requests.listen((message) async {
      final (id, op, a) = message as (int, _Op, List<Object?>);
      try {
        final result = await _dispatch(service, op, a);
        replies.send((id, true, result));
      } catch (e, stack) {
        // Without a reply the caller's future would never complete.
        replies.send((id, false, e.toString()));
        replies.send((e.toString(), stack.toString()));
      }
    });
  }

  static Future<Object?> _dispatch(
    PanasonicProtocolService s,
    _Op op,
    List<Object?> a,
  ) {
    String str(int i) => a[i] as String;
    final ip = str(0);
    final port = a[1] as int;
    return switch (op) {
      _Op.checkConnection => s.checkConnection(ip, port),
      _Op.sendCommand => s.sendCommand(ip, port, str(2), str(3), str(4)),
      _Op.sendRawCommand => s.sendRawCommand(ip, port, str(2), str(3), str(4)),
      _Op.sendRawCommandPreservingErrorCodes =>
        s.sendRawCommandPreservingErrorCodes(ip, port, str(2), str(3), str(4)),
      _Op.sendQuickQuery => s.sendQuickQuery(ip, port, str(2), str(3), str(4)),
      _Op.pollProjectorTelemetry => s.pollProjectorTelemetry(
        ip,
        port,
        str(2),
        str(3),
        concurrency: a[4] as int,
        withSerial: a[5] as bool,
      ),
    };
  }
}
