import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The system's own notifications: a Windows toast, a macOS Notification
/// Center banner. Always silent; the alert sound is the app's own
/// (`AlertSoundService`), so it still plays under Focus or Do Not Disturb.
/// Transport only, no Riverpod.
class DesktopNotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  var _permissionAsked = false;
  var _nextId = 0;

  /// Called when the operator clicks a notification.
  void Function()? onClick;

  /// Windows takes the toast's app icon from a file, not from the exe's own
  /// icon resource, so it points at the bundled copy next to the exe.
  static String get _windowsIconPath => [
    File(Platform.resolvedExecutable).parent.path,
    'data',
    'flutter_assets',
    'assets',
    'launcher_icon',
    'app_icon.png',
  ].join(Platform.pathSeparator);

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: InitializationSettings(
          // macOS asks for permission on first use, not at launch.
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: 'Projector Grid',
            appUserModelId: 'ProjectorGrid.ProjectorGrid',
            // Identifies the app's activation callback to Windows; fixed for
            // the app's lifetime.
            guid: 'b6c4a1e2-5f3d-4e8a-9c71-2d0f8e6a4b13',
            iconPath: Platform.isWindows ? _windowsIconPath : null,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onClick?.call(),
      )
      .then((_) {});

  Future<void> show({required String title, required String body}) async {
    await _init();
    if (Platform.isMacOS && !_permissionAsked) {
      _permissionAsked = true;
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true);
    }
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        macOS: const DarwinNotificationDetails(presentSound: false),
        windows: WindowsNotificationDetails(
          audio: WindowsNotificationAudio.silent(),
        ),
      ),
    );
  }
}
