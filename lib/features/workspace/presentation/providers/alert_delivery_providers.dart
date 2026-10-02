import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/alert_sound_service.dart';
import '../../../../core/services/desktop_notification_service.dart';

part 'alert_delivery_providers.g.dart';

/// The services alerts reach the operator through, as providers so tests
/// can override them with fakes that show and play nothing.
@Riverpod(keepAlive: true)
DesktopNotificationService desktopNotificationService(Ref ref) =>
    DesktopNotificationService();

@Riverpod(keepAlive: true)
AlertSoundService alertSoundService(Ref ref) {
  final service = AlertSoundService();
  ref.onDispose(service.dispose);
  return service;
}
