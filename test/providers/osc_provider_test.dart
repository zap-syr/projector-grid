import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/osc_status.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/osc_provider.dart';

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
}
