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

  /// Windows takes toast images from files, not from the exe's resources,
  /// so they point at the bundled assets next to the exe.
  static String _bundledAsset(List<String> path) => [
    File(Platform.resolvedExecutable).parent.path,
    'data',
    'flutter_assets',
    'assets',
    ...path,
  ].join(Platform.pathSeparator);

  static String get _windowsIconPath =>
      _bundledAsset(['launcher_icon', 'app_icon.png']);

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
            // The installer's Start menu shortcut carries the same ID and
            // GUID (installer/projector_grid.iss); without it the toast's
            // header shows the name but no icon.
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

  /// [critical] picks the Windows toast's severity logo (red circle or
  /// orange triangle, `assets/alert_icons/`); macOS always shows the app
  /// icon there.
  Future<void> show({
    required String title,
    required String body,
    required bool critical,
  }) async {
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
          images: [
            WindowsImage(
              Uri.file(
                _bundledAsset([
                  'alert_icons',
                  critical ? 'critical.png' : 'warning.png',
                ]),
                windows: true,
              ),
              altText: critical ? 'Critical' : 'Warning',
              placement: WindowsImagePlacement.appLogoOverride,
            ),
          ],
        ),
      ),
    );
  }
}
