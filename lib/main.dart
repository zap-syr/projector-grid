import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/services/window_prefs_service.dart';

import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final savedPrefs = WindowPrefsService.load();

    final windowOptions = WindowOptions(
      size: savedPrefs != null
          ? Size(savedPrefs.width, savedPrefs.height)
          : const Size(1280, 720),
      minimumSize: const Size(800, 600),
      // Only center on first run / no saved geometry — otherwise restore to
      // wherever the user last left the window.
      center: savedPrefs == null,
      title: 'Projector Grid',
    );

    windowManager.addListener(_WindowGeometryPersistence());
    await windowManager.setPreventClose(true);

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (savedPrefs != null) {
        await windowManager.setPosition(Offset(savedPrefs.x, savedPrefs.y));
        if (savedPrefs.isMaximized) {
          await windowManager.maximize();
        }
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Persists window size/position/maximized-state across launches.
///
/// Resize/move events fire continuously while the user is actively dragging,
/// so writes are debounced rather than saved on every event. Close is
/// special-cased: `setPreventClose(true)` above holds the window open long
/// enough for one final synchronous save before we destroy it ourselves,
/// otherwise a resize immediately followed by closing could be lost.
class _WindowGeometryPersistence with WindowListener {
  Timer? _debounce;

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    final isMaximized = await windowManager.isMaximized();
    final bounds = await windowManager.getBounds();
    WindowPrefsService.save(
      WindowPrefs(
        width: bounds.width,
        height: bounds.height,
        x: bounds.left,
        y: bounds.top,
        isMaximized: isMaximized,
      ),
    );
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowClose() async {
    _debounce?.cancel();
    await _saveNow();
    await windowManager.destroy();
  }
}
