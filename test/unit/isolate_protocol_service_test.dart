import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/isolate_protocol_service.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

import '../helpers/fake_projector_server.dart';

// The wire behaviour itself is covered by protocol_service_test.dart; this
// only checks that each call makes the round trip through the worker isolate
// and comes back with the same result types.
void main() {
  late FakeProjectorServer projector;
  final service = IsolateProtocolService();

  setUp(() async {
    projector = await FakeProjectorServer.start(
      responses: {'QID': 'PT-RQ25K', 'QSH': '1', 'OSH:1': 'OSH:1'},
    );
  });
  tearDown(() => projector.close());
  tearDownAll(service.dispose);

  test('pollProjectorTelemetry returns the probe and telemetry', () async {
    final (probe, t) = await service.pollProjectorTelemetry(
      projector.host,
      projector.port,
      '',
      '',
      concurrency: 3,
    );
    expect(probe, ProbeResult.unprotected);
    expect(t!['modelName'], 'PT-RQ25K');
    expect(t['shutter'], '1');
    expect(t['signal'], 'ER401');
    expect(t.containsKey('serialNumber'), isTrue);
  });

  test('pollProjectorTelemetry passes withSerial to the worker', () async {
    final (_, t) = await service.pollProjectorTelemetry(
      projector.host,
      projector.port,
      '',
      '',
      withSerial: false,
    );
    expect(t!.containsKey('serialNumber'), isFalse);
  });

  test('raw commands and their error-code handling', () async {
    expect(
      await service.sendRawCommand(
        projector.host,
        projector.port,
        '',
        '',
        'QSH',
      ),
      '1',
    );
    expect(
      await service.sendRawCommand(
        projector.host,
        projector.port,
        '',
        '',
        'QIN',
      ),
      isNull,
    );
    expect(
      await service.sendRawCommandPreservingErrorCodes(
        projector.host,
        projector.port,
        '',
        '',
        'QIN',
      ),
      'ER401',
    );
    expect(
      await service.sendQuickQuery(
        projector.host,
        projector.port,
        '',
        '',
        'QSH',
      ),
      '1',
    );
  });

  test('sendCommand and checkConnection', () async {
    expect(
      await service.sendCommand(
        projector.host,
        projector.port,
        '',
        '',
        'OSH:1',
      ),
      isTrue,
    );
    expect(
      await service.checkConnection(projector.host, projector.port),
      isTrue,
    );
  });

  group('sendBinaryCommand', () {
    Future<Uint8List> binary(Uint8List frame, {int? port}) =>
        service.sendBinaryCommand(
          projector.host,
          port ?? projector.port,
          '',
          '',
          frame,
        );

    test('the reply frame comes back as bytes', () async {
      final reply = await binary(buildSaveFrame(WarpSlot.pc2));
      expect(reply, warpHexToBytes('0200AAE20003'));
      expect(projector.received.single, '010200AAE203');
    });

    test('a projector error keeps its type and code', () async {
      await expectLater(
        binary(buildReadFrame(0x72, top: true)),
        throwsA(
          isA<WarpProtocolException>()
              .having((e) => e.code, 'code', 0x8B)
              .having((e) => e.message, 'message', contains('0x8b')),
        ),
      );
    });

    test('a projector error without a code keeps its type', () async {
      projector.warp.script(0, 'ERRA');
      await expectLater(
        binary(buildSaveFrame(WarpSlot.pc1)),
        throwsA(
          isA<WarpProtocolException>().having((e) => e.code, 'code', isNull),
        ),
      );
    });

    test('a transport failure keeps its type', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      await expectLater(
        binary(buildSaveFrame(WarpSlot.pc1), port: port),
        throwsA(isA<WarpTransportException>()),
      );
    });

    test('the worker still answers after an error', () async {
      await expectLater(
        binary(buildReadFrame(0x72, top: true)),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(await binary(buildSaveFrame(WarpSlot.pc1)), isNotEmpty);
    });
  });

  test('concurrent calls each get their own reply', () async {
    final results = await Future.wait([
      for (var i = 0; i < 20; i++)
        service.sendRawCommand(
          projector.host,
          projector.port,
          '',
          '',
          i.isEven ? 'QSH' : 'QID',
        ),
    ]);
    expect(results, [for (var i = 0; i < 20; i++) i.isEven ? '1' : 'PT-RQ25K']);
  });
}
