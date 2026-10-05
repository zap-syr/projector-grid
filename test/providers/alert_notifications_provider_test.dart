import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/alert_sound_service.dart';
import 'package:projector_grid/core/services/desktop_notification_service.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/signal_watch.dart';
import 'package:projector_grid/features/workspace/presentation/providers/signal_watch_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alert_delivery_providers.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alert_notifications_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

class _FakeNotifications implements DesktopNotificationService {
  final shown = <String>[];

  @override
  void Function()? onClick;

  @override
  Future<void> show({
    required String title,
    required String body,
    required NoticeIcon icon,
  }) async => shown.add('$title | $body | ${icon.name}');
}

/// Dropouts set by the test instead of queried from projectors.
class _FakeWatch extends SignalWatchNotifier {
  @override
  Map<String, SignalLoss> build() => const {};

  void set(Map<String, SignalLoss> losses) => state = losses;
}

class _FakeSound implements AlertSoundService {
  final played = <bool>[];

  @override
  Future<void> play({required bool critical}) async => played.add(critical);

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  late _FakeNotifications notifications;
  late _FakeSound sound;

  ProviderContainer container() {
    notifications = _FakeNotifications();
    sound = _FakeSound();
    final c = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(FakeProtocolService()),
        desktopNotificationServiceProvider.overrideWithValue(notifications),
        alertSoundServiceProvider.overrideWithValue(sound),
        signalWatchProvider.overrideWith(_FakeWatch.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(workspaceProvider, (_, _) {});
    c.listen(alertsProvider, (_, _) {});
    c.read(alertNotificationsProvider);
    return c;
  }

  test('alerts within the window make one notification and one sound', () {
    fakeAsync((async) {
      final c = container();
      c
          .read(appSettingsProvider.notifier)
          .setAlertSettings(
            const AlertSettings(sound: true, soundFor: AlertNotifyScope.all),
          );
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1').copyWith(exhaustTemp: '58°C')]);
      async.elapse(const Duration(milliseconds: 500));
      ws.setNodes([
        node('1').copyWith(exhaustTemp: '58°C'),
        node('2').copyWith(errors: 'F305'),
      ]);
      async.elapse(const Duration(seconds: 2));

      // Notify for: Critical (the default) leaves the warning out.
      expect(notifications.shown, [
        'Projector error on Proj 2 (10.0.0.2) | Fan error (F305) since '
            '${_hhmm(DateTime.now())} | critical',
      ]);
      expect(sound.played, [true]);
    });
  });

  test('a signal coming back gets its own silent notification', () {
    fakeAsync((async) {
      final c = container();
      c
          .read(appSettingsProvider.notifier)
          .setAlertSettings(const AlertSettings(sound: true));
      c.read(workspaceProvider.notifier).setNodes([node('1')]);
      final watch = c.read(signalWatchProvider.notifier) as _FakeWatch;
      final since = DateTime.now();
      final lost = SignalLoss(since: since, input: 'HDMI 1');
      watch.set({'1': lost});
      async.elapse(const Duration(seconds: 3));
      watch.set({'1': lost.restored(since.add(const Duration(seconds: 3)))});
      async.elapse(const Duration(seconds: 3));

      expect(notifications.shown, [
        'Signal lost on Proj 1 (10.0.0.1) | No signal on HDMI 1 since '
            '${_hhmm(since)} | critical',
        'Signal back on Proj 1 (10.0.0.1) | Back after 3 s, lost at '
            '${_hhmm(since)} | recovered',
      ]);
      expect(sound.played, [true]);
    });
  });

  test('no signal-back notification with notifications off', () {
    fakeAsync((async) {
      final c = container();
      c
          .read(appSettingsProvider.notifier)
          .setAlertSettings(const AlertSettings(desktopNotification: false));
      c.read(workspaceProvider.notifier).setNodes([node('1')]);
      final watch = c.read(signalWatchProvider.notifier) as _FakeWatch;
      final lost = SignalLoss(since: DateTime.now(), input: 'HDMI 1');
      watch.set({'1': lost});
      async.elapse(const Duration(seconds: 3));
      watch.set({'1': lost.restored(DateTime.now())});
      async.elapse(const Duration(seconds: 3));
      expect(notifications.shown, isEmpty);
    });
  });

  test('nothing when notifications and sound are off', () {
    fakeAsync((async) {
      final c = container();
      c
          .read(appSettingsProvider.notifier)
          .setAlertSettings(const AlertSettings(desktopNotification: false));
      c.read(workspaceProvider.notifier).setNodes([
        node('1').copyWith(errors: 'F305'),
      ]);
      async.elapse(const Duration(seconds: 3));
      expect(notifications.shown, isEmpty);
      expect(sound.played, isEmpty);
    });
  });
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
