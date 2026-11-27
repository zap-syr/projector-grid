import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/isolate_protocol_service.dart';

import '../helpers/fake_projector_server.dart';

// A worker that ends on its own (out of memory, an error it can't survive)
// must not leave callers waiting. Killing the isolate raises the same exit
// event a crash does.
void main() {
  const timeout = Timeout(Duration(seconds: 15));

  late FakeProjectorServer projector;
  late IsolateProtocolService service;

  setUp(() async {
    projector = await FakeProjectorServer.start(responses: {'QSH': '1'});
    service = IsolateProtocolService();
  });
  tearDown(() async {
    await service.dispose();
    await projector.close();
  });

  Future<String?> query() =>
      service.sendRawCommand(projector.host, projector.port, '', '', 'QSH');

  // Lets the worker take the request off the wire before it is killed.
  Future<void> startInFlight(Future<String?> call) async {
    call.ignore();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  test('a call in flight fails when the worker exits', () async {
    projector.replyDelay = const Duration(seconds: 5);
    final call = query();
    final failure = expectLater(call, throwsStateError);
    await startInFlight(call);
    await service.debugKillWorker();
    await failure;
  }, timeout: timeout);

  test('the next call after an exit succeeds on a new worker', () async {
    expect(await query(), '1');
    projector.replyDelay = const Duration(seconds: 5);
    final call = query();
    final failure = expectLater(call, throwsStateError);
    await startInFlight(call);
    await service.debugKillWorker();
    await failure;

    projector.replyDelay = null;
    expect(await query(), '1');
  }, timeout: timeout);

  test(
    'a call made right after the exit, before the new port arrives, completes',
    () async {
      projector.replyDelay = const Duration(seconds: 5);
      final call = query();
      final failure = expectLater(call, throwsStateError);
      await startInFlight(call);
      await service.debugKillWorker();
      await failure;

      projector.replyDelay = null;
      expect(await query(), '1');
      expect(await query(), '1');
    },
    timeout: timeout,
  );

  test(
    'a call made before the first worker port arrives survives a kill',
    () async {
      // No await since construction: the worker has not sent its port yet.
      final first = query();
      final failure = expectLater(first, throwsStateError);
      await service.debugKillWorker();
      await failure;
      expect(await query(), '1');
    },
    timeout: timeout,
  );

  test('dispose fails pending calls', () async {
    projector.replyDelay = const Duration(seconds: 5);
    final call = query();
    final failure = expectLater(call, throwsStateError);
    await startInFlight(call);
    await service.dispose();
    await failure;
  }, timeout: timeout);

  test('a call after dispose fails instead of hanging', () async {
    await service.dispose();
    await expectLater(query(), throwsStateError);
  }, timeout: timeout);
}
