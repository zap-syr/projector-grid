import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../features/workspace/domain/warp_codec.dart';
import 'app_log_file.dart';
import 'panasonic_protocol_service.dart';

enum _Op {
  checkConnection,
  sendCommand,
  sendRawCommand,
  sendRawCommandPreservingErrorCodes,
  sendQuickQuery,
  sendBinaryCommand,
  pollProjectorTelemetry,
}

class _Worker {
  final replies = ReceivePort();
  final errors = ReceivePort();
  final exits = ReceivePort();
  late final Future<Isolate> isolate;

  void close() {
    replies.close();
    errors.close();
    exits.close();
  }
}

/// [PanasonicProtocolService] with every NTCONTROL exchange run on a
/// long-lived worker isolate. A poll cycle at 150 projectors is ~2,000 TCP
/// connections; on the UI isolate their socket events kept it busy for the
/// whole cycle and card drags stalled. Here the
/// UI isolate only sees one message per call.
///
/// Overrides every public method except [scanNetwork], which the Add
/// Projectors Discover tab runs in-process: a one-off sweep while a modal
/// dialog is open, nothing else on the UI to stall. A public method
/// added to the base class must be routed here too, or it runs on the UI
/// isolate again.
class IsolateProtocolService extends PanasonicProtocolService {
  IsolateProtocolService() {
    _spawnWorker();
  }

  final _pending = <int, Completer<Object?>>{};
  // Calls made before the worker has sent its port. They are sent when it
  // arrives, not awaited per call: a call parked on a port that never comes
  // (worker died first) could not be failed by the exit handler.
  final _queued = <(int, _Op, List<Object?>)>[];
  SendPort? _workerPort;
  _Worker? _worker;
  var _nextId = 0;
  var _disposed = false;

  // Fresh ports per worker: once a dead worker's ports are closed, none of
  // its late messages can reach the replacement.
  void _spawnWorker() {
    final worker = _worker = _Worker();
    worker.replies.listen((message) => _onReply(worker, message));
    worker.errors.listen(_onUncaught);
    worker.exits.listen((_) => _onExit(worker));
    // Not fatal: an uncaught error in one exchange would otherwise kill the
    // worker, and every call after it would wait forever.
    worker.isolate = Isolate.spawn(
      _workerMain,
      worker.replies.sendPort,
      errorsAreFatal: false,
      onError: worker.errors.sendPort,
      onExit: worker.exits.sendPort,
    );
  }

  void _onReply(_Worker worker, Object? message) {
    if (!identical(worker, _worker)) return;
    switch (message) {
      case final SendPort port:
        _workerPort = port;
        for (final queued in _queued) {
          port.send(queued);
        }
        _queued.clear();
      // A call that threw in the worker: the caller gets the error, the app
      // log gets the worker's stack, which the caller's doesn't show.
      case (String error, String stack):
        AppLog.error('Protocol worker', error, stack);
      case (int id, bool ok, Object? value):
        final completer = _pending.remove(id);
        if (completer == null) return;
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

  // The worker ended although nobody asked it to (out of memory, an error it
  // could not survive). Without this every pending call waits forever and
  // polling stops silently.
  void _onExit(_Worker worker) {
    worker.close();
    if (_disposed || !identical(worker, _worker)) return;
    final failed = _failPending('Protocol worker exited');
    AppLog.error(
      'Protocol worker',
      'Worker isolate exited unexpectedly, $failed pending calls failed, '
          'starting a new one',
      null,
    );
    _spawnWorker();
  }

  int _failPending(String reason) {
    final calls = _pending.values.toList();
    _pending.clear();
    _queued.clear();
    _workerPort = null;
    for (final completer in calls) {
      completer.completeError(StateError(reason));
    }
    return calls.length;
  }

  Future<T> _call<T>(_Op op, List<Object?> args) async {
    if (_disposed) throw StateError('Protocol service disposed');
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    final message = (id, op, args);
    final port = _workerPort;
    if (port == null) {
      _queued.add(message);
    } else {
      port.send(message);
    }
    return await completer.future as T;
  }

  /// Ends the current worker as a crash would, so tests can exercise the
  /// recovery path.
  @visibleForTesting
  Future<void> debugKillWorker() async {
    (await _worker!.isolate).kill(priority: Isolate.immediate);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _failPending('Protocol service disposed');
    final worker = _worker!;
    (await worker.isolate).kill(priority: Isolate.immediate);
    worker.close();
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
  Future<Uint8List> sendBinaryCommand(
    String ip,
    int port,
    String login,
    String password,
    Uint8List frame,
  ) => _call(_Op.sendBinaryCommand, [ip, port, login, password, frame]);

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
        // Without a reply the caller's future would never complete. The warp
        // exceptions go across as objects: the caller tells a projector error
        // (and its code) from a transport failure by type.
        replies.send((
          id,
          false,
          e is WarpProtocolException || e is WarpTransportException
              ? e
              : e.toString(),
        ));
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
      _Op.sendBinaryCommand => s.sendBinaryCommand(
        ip,
        port,
        str(2),
        str(3),
        a[4] as Uint8List,
      ),
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
