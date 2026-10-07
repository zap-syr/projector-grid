import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/isolate_protocol_service.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';

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
