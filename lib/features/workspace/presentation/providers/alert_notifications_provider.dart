import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/services/desktop_notification_service.dart';
import '../../domain/alert_notifications.dart';
import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import 'active_alerts_request_provider.dart';
import 'alert_delivery_providers.dart';
import 'alerts_provider.dart';
import 'app_settings_provider.dart';

part 'alert_notifications_provider.g.dart';

/// Turns raised alerts into desktop notifications and the alert sound, per
/// Preferences → Alerts → Notify. Alerts raised within [kAlertBatchWindow]
/// of the first one make one notification and one sound. A signal coming
/// back gets its own, silent notification, batched the same way.
@Riverpod(keepAlive: true)
class AlertNotificationsNotifier extends _$AlertNotificationsNotifier {
  final List<AlertEvent> _batch = [];
  Timer? _flush;

  @override
  void build() {
    final events = ref
        .read(alertsProvider.notifier)
        .events
        .where(
          (e) =>
              e.change == AlertChange.raised ||
              e.change == AlertChange.recovered,
        )
        .listen(_add);
    ref.read(desktopNotificationServiceProvider).onClick = _onClick;
    ref.onDispose(() {
      events.cancel();
      _flush?.cancel();
    });
  }

  void _add(AlertEvent e) {
    _batch.add(e);
    // Timed from the first alert, not the last, so a steady stream still
    // reaches the operator every couple of seconds.
    _flush ??= Timer(kAlertBatchWindow, _deliver);
  }

  void _deliver() {
    _flush = null;
    final batch = List.of(_batch);
    _batch.clear();
    final settings = ref.read(appSettingsProvider).alerts;

    if (settings.desktopNotification) {
      final notifications = ref.read(desktopNotificationServiceProvider);
      final now = DateTime.now();
      final notice = alertNotice(
        noticeable(batch, settings.desktopNotifyFor),
        now,
      );
      if (notice != null) {
        unawaited(
          notifications.show(
            title: notice.title,
            body: notice.body,
            icon: notice.severity == AlertSeverity.critical
                ? NoticeIcon.critical
                : NoticeIcon.warning,
          ),
        );
      }
      // A return follows its alert's Notify for (Signal lost is critical).
      final back = recoveryNotice([
        for (final e in batch)
          if (settings.desktopNotifyFor == AlertNotifyScope.all ||
              e.alert.severity == AlertSeverity.critical)
            e,
      ], now);
      if (back != null) {
        unawaited(
          notifications.show(
            title: back.title,
            body: back.body,
            icon: NoticeIcon.recovered,
          ),
        );
      }
    }

    if (settings.sound) {
      final heard = noticeable(batch, settings.soundFor);
      if (heard.isNotEmpty) {
        unawaited(
          ref
              .read(alertSoundServiceProvider)
              .play(
                critical: heard.any(
                  (e) => e.alert.severity == AlertSeverity.critical,
                ),
              ),
        );
      }
    }
  }

  /// A clicked notification brings the app forward on Active alerts.
  Future<void> _onClick() async {
    await windowManager.show();
    await windowManager.focus();
    ref.read(activeAlertsRequestProvider.notifier).open();
  }
}
