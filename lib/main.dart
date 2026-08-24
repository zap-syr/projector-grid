import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/services/window_prefs_service.dart';

import 'dart:io' show Platform;

/// Whether a window at [prefs]'s saved geometry would land visibly on one of
/// the currently-connected displays.
///
/// `WindowPrefs.fromJson`'s own sanity clamp only rejects wildly-off-range
/// numbers, not a position that's valid but on a display that's since been
/// disconnected (e.g. an external monitor unplugged since last launch) — so
/// this is checked separately, against live monitor bounds, right before the
/// saved position would actually be applied. Fails open (returns true) on
/// any platform-call error, so a transient screen_retriever failure can't
/// discard otherwise-valid saved prefs.
Future<bool> _isPositionOnScreen(WindowPrefs prefs) async {
  try {
    final windowRect = Rect.fromLTWH(
      prefs.x,
      prefs.y,
      prefs.width,
      prefs.height,
    );
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final position = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      if (windowRect.overlaps(position & size)) return true;
    }
    return false;
  } catch (_) {
    return true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    var savedPrefs = WindowPrefsService.load();
    if (savedPrefs != null && !await _isPositionOnScreen(savedPrefs)) {
      savedPrefs = null;
    }

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
      final prefs = savedPrefs;
      if (prefs != null) {
        await windowManager.setPosition(Offset(prefs.x, prefs.y));
        if (prefs.isMaximized) {
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
/// enough for one final synchronous save on close.
///
/// This listener deliberately only ever saves — it never calls
/// `windowManager.destroy()` itself. `_MainWorkspaceScreenState.onWindowClose`
/// (main_workspace_screen.dart) is the sole place that decides whether the
/// window is actually allowed to close, since it shows an unsaved-changes
/// confirmation dialog first. `window_manager` dispatches a close event to
/// every registered listener without awaiting any of them, so if this
/// listener also destroyed the window, its much faster save-only chain
/// could win the race and close the app before that confirmation dialog
/// ever has a chance to appear — silently discarding unsaved changes.
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
  }
}
