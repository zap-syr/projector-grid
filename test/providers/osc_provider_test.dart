import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osc/osc.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/osc_status.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/osc_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

// These bind real UDP sockets on loopback, as osc_service_test does. A bind
// failure is made with an address this machine doesn't have (TEST-NET-1).
void main() {
  useTempConfigDir();

  group('oscProvider', () {
    test('a failed bind is kept for the session although the setting turns '
        'off; a successful start clears it', () async {
      final c = makeContainer(FakeProtocolService());
      final settings = c.read(appSettingsProvider.notifier)
        ..setOscNetworkDevice('192.0.2.123')
        ..setOscReceivePort(9555);
      final osc = c.read(oscProvider.notifier);
      expect(c.read(oscProvider), const OscOff());

      await osc.start();
      expect(c.read(oscProvider), const OscBindFailed(9555));
      expect(c.read(appSettingsProvider).oscActive, isFalse);

      settings
        ..setOscNetworkDevice('127.0.0.1')
        ..setOscReceivePort(0);
      final states = <OscStatus>[];
      c.listen(oscProvider, (_, s) => states.add(s));
      final starting = osc.start();
      // While the new bind is pending the old failure doesn't show.
      expect(c.read(oscProvider), const OscOff());
      await starting;
      expect(c.read(oscProvider), const OscListening(0));
      expect(c.read(appSettingsProvider).oscActive, isTrue);
      expect(states.whereType<OscBindFailed>(), isEmpty);

      await osc.stop();
      expect(c.read(oscProvider), const OscOff());
    });

    test('a stop sent while a start is pending wins', () async {
      final c = makeContainer(FakeProtocolService());
      c.read(appSettingsProvider.notifier)
        ..setOscNetworkDevice('127.0.0.1')
        ..setOscReceivePort(0);
      final osc = c.read(oscProvider.notifier);

      final starting = osc.start();
      await osc.stop();
      await starting;
      expect(c.read(oscProvider), const OscOff());
      expect(c.read(appSettingsProvider).oscActive, isFalse);
    });

    test('a restart never reports a bind failure', () async {
      final c = makeContainer(FakeProtocolService());
      c.read(appSettingsProvider.notifier)
        ..setOscNetworkDevice('127.0.0.1')
        ..setOscReceivePort(0);
      final osc = c.read(oscProvider.notifier);
      await osc.start();
      final states = <OscStatus>[];
      c.listen(oscProvider, (_, s) => states.add(s));

      await osc.restart();
      expect(states.whereType<OscBindFailed>(), isEmpty);
      expect(c.read(oscProvider), const OscListening(0));
      await osc.stop();
    });
  });

  group('oscProvider targeting', () {
    late ProviderContainer c;
    late FakeProtocolService fake;
    late RawDatagramSocket sender;
    late int port;

    setUp(() async {
      fake = FakeProtocolService();
      for (final id in ['1', '2', '3', '4']) {
        fake.pollResults['10.0.0.$id'] = (ProbeResult.online, telemetry());
      }
      c = makeContainer(fake);
      c.read(workspaceProvider.notifier)
        ..addGroup(
          const ProjectorGroup(
            id: 'g1',
            name: 'Stage',
            color: 0,
            oscAddress: '/group/stage',
          ),
        )
        ..addGroup(
          const ProjectorGroup(
            id: 'g2',
            name: 'Side',
            color: 0,
            oscAddress: '/group/side',
          ),
        )
        ..setNodes([
          node('1', groupId: 'g1'),
          node('2', groupId: 'g1'),
          node('3', groupId: 'g2'),
          node('4'),
        ]);
      // The provider reports the port it was given, so take a free one.
      final probe = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      port = probe.port;
      probe.close();
      c.read(appSettingsProvider.notifier)
        ..setOscNetworkDevice('127.0.0.1')
        ..setOscReceivePort(port);
      await c.read(oscProvider.notifier).start();
      expect(c.read(oscProvider), OscListening(port));
      sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(sender.close);
      addTearDown(() => c.read(oscProvider.notifier).stop());
    });

    void send(String address) => sender.send(
      OSCMessage(address, arguments: const []).toBytes(),
      InternetAddress.loopbackIPv4,
      port,
    );

    Future<void> until(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) fail('timed out');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    Set<String> sentTo(String cmd) => {
      for (final (ip, sent) in fake.sentCommands)
        if (sent == cmd) ip,
    };

    Set<String> locked() => {
      for (final n in c.read(workspaceProvider))
        if (n.lensLocked) n.id,
    };

    test('a command reaches its group, or every projector', () async {
      send('/pgrid/group/stage/shutter/close');
      await until(() => sentTo('OSH:1').length >= 2);
      send('/pgrid/all/shutter/open');
      await until(() => sentTo('OSH:0').length >= 4);
      expect(sentTo('OSH:1'), {'10.0.0.1', '10.0.0.2'});
      expect(sentTo('OSH:0'), {'10.0.0.1', '10.0.0.2', '10.0.0.3', '10.0.0.4'});
    });

    test('Lens lock targets the same projectors as a command', () async {
      send('/pgrid/group/stage/lens/lock');
      await until(() => locked().isNotEmpty);
      expect(locked(), {'1', '2'});

      send('/pgrid/all/lens/lock');
      await until(() => locked().length == 4);
      send('/pgrid/group/side/lens/unlock');
      await until(() => locked().length == 3);
      expect(locked(), {'1', '2', '4'});
    });
  });
}
