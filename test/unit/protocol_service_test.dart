import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';

import '../helpers/fake_projector_server.dart';

void main() {
  late FakeProjectorServer projector;
  final service = PanasonicProtocolService();

  setUp(() async {
    projector = await FakeProjectorServer.start();
  });
  tearDown(() => projector.close());

  Future<String?> raw(String cmd) => service.sendRawCommand(
    projector.host,
    projector.port,
    'admin1',
    'panasonic',
    cmd,
  );

  /// A port nothing listens on — connect fails instantly with 'Timeout'.
  Future<int> closedPort() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    return port;
  }

  group('response prefix stripping', () {
    test('strips exactly the leading 00', () async {
      projector.responses['QID'] = 'PT-RQ25K';
      expect(await raw('QID'), 'PT-RQ25K');
    });

    test('keeps a 00 that is part of the model name', () async {
      projector.responses['QID'] = '00PT-RZ1000';
      expect(await raw('QID'), '00PT-RZ1000');
    });

    test('keeps 00 inside the value', () async {
      projector.responses['QVX:RTMS1'] = 'RTMS1=1000';
      expect(await raw('QVX:RTMS1'), 'RTMS1=1000');
    });
  });

  group('authentication', () {
    test('unprotected mode sends a bare 00 prefix', () async {
      await raw('QID');
      expect(projector.received.single, '00QID');
    });

    test('protected mode prefixes MD5(login:password:token)', () async {
      projector.greeting = 'NTCONTROL 1 1a2b3c4d';
      projector.responses['PON'] = 'PON';
      await service.sendCommand(
        projector.host,
        projector.port,
        'admin1',
        'panasonic',
        'PON',
      );
      final expected = FakeProjectorServer.md5Prefix(
        'admin1',
        'panasonic',
        '1a2b3c4d',
      );
      expect(projector.received.single, '${expected}00PON');
      // Known-answer check so a change to the hash input order is caught.
      expect(expected, '31414862293de76966f47eefb8f365f3');
    });

    test('malformed token in protected mode is not sent', () async {
      projector.greeting = 'NTCONTROL 1 nothex!!';
      expect(await raw('QID'), isNull);
      expect(projector.received, isEmpty);
    });
  });

  group('failure classification', () {
    test('projector ER codes are failures for sendCommand', () async {
      projector.responses['PON'] = 'ERR3';
      expect(
        await service.sendCommand(
          projector.host,
          projector.port,
          '',
          '',
          'PON',
        ),
        isFalse,
      );
    });

    test('sendRawCommand drops ER401', () async {
      projector.responses['QVX:NSGS1'] = 'ER401';
      expect(await raw('QVX:NSGS1'), isNull);
    });

    test('preserving variant keeps ER401 as data', () async {
      projector.responses['QVX:NSGS1'] = 'ER401';
      expect(
        await service.sendRawCommandPreservingErrorCodes(
          projector.host,
          projector.port,
          '',
          '',
          'QVX:NSGS1',
        ),
        'ER401',
      );
    });

    test('preserving variant still drops a bad handshake', () async {
      projector.greeting = 'HELLO';
      expect(
        await service.sendRawCommandPreservingErrorCodes(
          projector.host,
          projector.port,
          '',
          '',
          'QVX:NSGS1',
        ),
        isNull,
      );
    });

    test('connection refused is a transport failure', () async {
      final port = await closedPort();
      expect(
        await service.sendRawCommandPreservingErrorCodes(
          projector.host,
          port,
          '',
          '',
          'QID',
        ),
        isNull,
      );
      expect(
        await service.sendCommand(projector.host, port, '', '', 'PON'),
        isFalse,
      );
    });
  });

  group('checkConnection', () {
    test('true when the port accepts', () async {
      expect(
        await service.checkConnection(projector.host, projector.port),
        isTrue,
      );
    });

    test('false when refused', () async {
      expect(
        await service.checkConnection(projector.host, await closedPort()),
        isFalse,
      );
    });
  });

  group('pollProjectorTelemetry', () {
    Future<(ProbeResult, Map<String, dynamic>?)> poll() =>
        service.pollProjectorTelemetry(
          projector.host,
          projector.port,
          'admin1',
          'panasonic',
        );

    test('unprotected projector reports all fields', () async {
      projector.responses.addAll({
        'QID': 'PT-RQ25K',
        'QSN': 'SN123',
        'QVX:POWI1': 'POWI1=+00003',
        'QSH': '0',
        'QIN': 'HD1',
        'QVX:NSGS1': 'NSGS1=1080/60p',
        'QVX:RTMS1': 'RTMS1=2185',
        'QVX:LRTS3=00': 'LRTS3=00:1577',
        'QTM:0': '0030/0086',
        'QTM:1': '0041/0106',
        'QVX:VMOI2': 'VMOI2=+00230',
        'QVX:ERRS2': 'ERRS2=',
        'QTS': '07',
      });
      final (probe, t) = await poll();
      expect(probe, ProbeResult.unprotected);
      expect(t, {
        'modelName': 'PT-RQ25K',
        'serialNumber': 'SN123',
        'power': 'POWI1=+00003',
        'shutter': '0',
        'input': 'HD1',
        'signal': 'NSGS1=1080/60p',
        'runtime': 'RTMS1=2185',
        'lightRuntime': 'LRTS3=00:1577',
        'intakeTemp': '0030/0086',
        'exhaustTemp': '0041/0106',
        'acVoltage': 'VMOI2=+00230',
        'errors': 'ERRS2=',
        'testPattern': '07',
      });
    });

    test('protected projector reports online', () async {
      projector.greeting = 'NTCONTROL 1 0badf00d';
      projector.responses.addAll({'QID': 'PT-RQ25K', 'QSH': '1'});
      final (probe, t) = await poll();
      expect(probe, ProbeResult.online);
      expect(t!['shutter'], '1');
    });

    test('ER codes on follow-up queries stay as data', () async {
      projector.responses.addAll({'QID': 'PT-RQ25K', 'QSH': '1'});
      final (probe, t) = await poll();
      expect(probe, ProbeResult.unprotected);
      expect(t!['signal'], 'ER401');
      expect(t['lightRuntime'], 'ER401');
    });

    test('every follow-up answering an ER code is offline', () async {
      projector.responses['QID'] = 'PT-RQ25K';
      expect(await poll(), (ProbeResult.offline, null));
    });

    test('ERRA on QID is unauthorized', () async {
      projector.responses['QID'] = 'ERRA';
      expect(await poll(), (ProbeResult.unauthorized, null));
    });

    test('malformed auth token is unauthorized, not offline', () async {
      projector.greeting = 'NTCONTROL 1 zz';
      expect(await poll(), (ProbeResult.unauthorized, null));
    });

    test('ER code on QID is offline', () async {
      projector.responses['QID'] = 'ERR3';
      expect(await poll(), (ProbeResult.offline, null));
    });

    test('unreachable projector is offline', () async {
      final (probe, t) = await service.pollProjectorTelemetry(
        projector.host,
        await closedPort(),
        '',
        '',
      );
      expect(probe, ProbeResult.offline);
      expect(t, isNull);
    });

    test('QID ok but every follow-up failing is offline', () async {
      projector.responses['QID'] = 'PT-RQ25K';
      projector.validHandshakes = 1;
      expect(await poll(), (ProbeResult.offline, null));
    });

    test('a single transport failure becomes null, not a sentinel', () async {
      projector.responses.addAll({'QID': 'PT-RQ25K', 'QSN': 'SN123'});
      // QID + QSN handshake fine; with concurrency 1 the remaining 10
      // queries fail in order.
      projector.validHandshakes = 2;
      final (probe, t) = await service.pollProjectorTelemetry(
        projector.host,
        projector.port,
        '',
        '',
        concurrency: 1,
      );
      expect(probe, ProbeResult.unprotected);
      expect(t!['serialNumber'], 'SN123');
      expect(t['power'], isNull);
      expect(t['errors'], isNull);
    });
  });
}
