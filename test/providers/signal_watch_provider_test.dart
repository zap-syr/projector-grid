import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/signal_watch_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  const signal = 'NSGS1=1080/60p';
  const noSignal = 'NSGS1=NO SIGNAL';
  const powerOn = 'POWI1=+00003';
  const standby = 'POWI1=+00001';

  ProjectorNode on(String id) => node(id).copyWith(powerStatus: PowerStatus.on);

  late FakeProtocolService fake;

  ProviderContainer start(FakeAsync async, List<ProjectorNode> nodes) {
    final c = makeContainer(fake);
    c.listen(signalWatchProvider, (_, _) {});
    c.listen(alertsProvider, (_, _) {});
    c.read(workspaceProvider.notifier).setNodes(nodes);
    async.flushMicrotasks();
    return c;
  }

  void reply(String ip, String cmd, String? value) =>
      (fake.rawResponsesByIp[ip] ??= {})[cmd] = value;

  int queriesTo(String ip) =>
      fake.sentQuick.where((q) => q.$1 == ip && q.$2 == 'QVX:NSGS1').length;

  setUp(() => fake = FakeProtocolService()..rawResponses['QVX:NSGS1'] = signal);

  test('150 projectors: each once per period, spread over it', () {
    fakeAsync((async) {
      final ids = [for (var i = 1; i <= 150; i++) '$i'];
      start(async, [
        for (final id in ids) on(id).copyWith(ipAddress: '10.0.$id.1'),
      ]);
      var before = 0;
      var maxPerTick = 0;
      for (var t = 0; t < 40; t++) {
        async.elapse(SignalWatchNotifier.tick);
        final n = fake.sentQuick.length;
        if (n - before > maxPerTick) maxPerTick = n - before;
        before = n;
      }
      expect(fake.sentQuick.length, 150);
      expect({for (final q in fake.sentQuick) q.$1}.length, 150);
      expect(maxPerTick, lessThanOrEqualTo(4));

      async.elapse(SignalWatchNotifier.period);
      expect(fake.sentQuick.length, 300);
    });
  });

  test('only powered-on, reachable projectors, and only with the rule on', () {
    fakeAsync((async) {
      final c = start(async, [
        on('1'),
        node('2'),
        on('3').copyWith(connectionStatus: ConnectionStatus.offline),
      ]);
      async.elapse(const Duration(seconds: 4));
      expect({for (final q in fake.sentQuick) q.$1}, {'10.0.0.1'});

      c
          .read(appSettingsProvider.notifier)
          .setAlertSettings(const AlertSettings(enabled: {AlertRule.offline}));
      final sent = fake.sentQuick.length;
      async.elapse(const Duration(seconds: 4));
      expect(fake.sentQuick.length, sent);
    });
  });

  test('a dropout raises Signal lost after checking power, latched', () {
    fakeAsync((async) {
      final c = start(async, [on('1').copyWith(input: 'HDMI 1')]);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(alertsProvider), isEmpty);

      reply('10.0.0.1', 'QVX:NSGS1', noSignal);
      reply('10.0.0.1', 'QVX:POWI1', powerOn);
      async.elapse(const Duration(seconds: 2));
      final alert = c.read(alertsProvider).values.single;
      expect(alert.rule, AlertRule.signalLost);
      expect(alert.value, 'No signal on HDMI 1');
      expect(c.read(workspaceProvider).single.signal, 'NO SIGNAL');

      reply('10.0.0.1', 'QVX:NSGS1', signal);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(alertsProvider).values.single.restoredAt, isNotNull);

      c.read(alertsProvider.notifier).acknowledgeAll();
      expect(c.read(alertsProvider), isEmpty);
      expect(c.read(signalWatchProvider), isEmpty);
    });
  });

  test('no signal before a signal was seen raises nothing', () {
    fakeAsync((async) {
      reply('10.0.0.1', 'QVX:NSGS1', 'ER401');
      reply('10.0.0.1', 'QVX:POWI1', powerOn);
      final c = start(async, [on('1')]);
      async.elapse(const Duration(seconds: 6));
      expect(c.read(alertsProvider), isEmpty);
    });
  });

  test('ER401 from a projector gone to standby by itself raises nothing', () {
    fakeAsync((async) {
      final c = start(async, [on('1')]);
      async.elapse(const Duration(seconds: 2));
      reply('10.0.0.1', 'QVX:NSGS1', 'ER401');
      reply('10.0.0.1', 'QVX:POWI1', standby);
      fake.pollResults['10.0.0.1'] = (
        ProbeResult.online,
        telemetry(power: standby, signal: 'ER401'),
      );
      async.elapse(const Duration(seconds: 6));
      expect(c.read(alertsProvider), isEmpty);
      // The regular poll is asked to catch up on the power state.
      expect(c.read(workspaceProvider).single.powerStatus, PowerStatus.standby);
    });
  });

  test('switching the input from the app needs a new signal first', () {
    fakeAsync((async) {
      final c = start(async, [on('1')]);
      async.elapse(const Duration(seconds: 2));
      reply('10.0.0.1', 'QVX:NSGS1', noSignal);
      reply('10.0.0.1', 'QVX:POWI1', powerOn);
      c.read(workspaceProvider.notifier).sendCommandToNodes(['1'], 'IIS:HD2');
      async.elapse(const Duration(seconds: 6));
      expect(c.read(alertsProvider), isEmpty);
    });
  });

  test('a reading that crossed an input switch is dropped', () {
    fakeAsync((async) {
      final c = start(async, [on('1')]);
      async.elapse(const Duration(seconds: 2));
      // A query is out when the operator switches to an input with nothing
      // connected; it comes back with the new input's answer.
      final hold = fake.holdQueries['10.0.0.1'] = Completer<void>();
      async.elapse(const Duration(seconds: 2));
      reply('10.0.0.1', 'QVX:NSGS1', 'ER401');
      reply('10.0.0.1', 'QVX:POWI1', powerOn);
      c.read(workspaceProvider.notifier).sendCommandToNodes(['1'], 'IIS:HD2');
      async.flushMicrotasks();
      fake.holdQueries.remove('10.0.0.1');
      hold.complete();
      async.elapse(const Duration(seconds: 6));
      expect(c.read(alertsProvider), isEmpty);
      expect(c.read(workspaceProvider).single.input, 'HDMI 2');
    });
  });

  test('a signal on the input switched to recovers an open dropout', () {
    fakeAsync((async) {
      final c = start(async, [on('1')]);
      async.elapse(const Duration(seconds: 2));
      reply('10.0.0.1', 'QVX:NSGS1', noSignal);
      reply('10.0.0.1', 'QVX:POWI1', powerOn);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(alertsProvider).values.single.restoredAt, isNull);

      c.read(workspaceProvider.notifier).sendCommandToNodes(['1'], 'IIS:HD2');
      reply('10.0.0.1', 'QVX:NSGS1', signal);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(alertsProvider).values.single.restoredAt, isNotNull);
    });
  });

  test('a signal change reads the input switched on the projector', () {
    fakeAsync((async) {
      final c = start(async, [on('1').copyWith(input: 'HDMI 1')]);
      async.elapse(const Duration(seconds: 2));
      expect(fake.sentQuick.where((q) => q.$2 == 'QIN'), isEmpty);

      reply('10.0.0.1', 'QVX:NSGS1', 'NSGS1=1920x1080/60p');
      reply('10.0.0.1', 'QIN', 'HD2');
      async.elapse(const Duration(seconds: 2));
      expect(c.read(workspaceProvider).single.input, 'HDMI 2');
      expect(c.read(workspaceProvider).single.signal, '1920x1080/60p');
    });
  });

  test('skips a projector the app is already talking to', () {
    fakeAsync((async) {
      final c = start(async, [on('1')]);
      c.read(workspaceProvider.notifier).claimNodeForExternalPoll('1');
      async.elapse(const Duration(seconds: 4));
      expect(queriesTo('10.0.0.1'), 0);

      c.read(workspaceProvider.notifier).releaseNodeFromExternalPoll('1');
      async.elapse(const Duration(seconds: 2));
      expect(queriesTo('10.0.0.1'), 1);
    });
  });

  test('a projector that does not answer gets no second query meanwhile', () {
    fakeAsync((async) {
      final hold = fake.holdQueries['10.0.0.1'] = Completer<void>();
      start(async, [on('1'), on('2')]);
      async.elapse(const Duration(seconds: 6));
      expect(queriesTo('10.0.0.1'), 1);
      expect(queriesTo('10.0.0.2'), 3);
      hold.complete();
    });
  });
}
