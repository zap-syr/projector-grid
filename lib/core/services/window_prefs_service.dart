import 'dart:convert';
import 'dart:io';

import 'app_config_dir.dart';

/// Persisted window geometry (size, position, maximized state).
///
/// Deliberately independent of `AppSettingsNotifier`/Riverpod — it must be
/// readable from `main()` before `runApp`/`ProviderScope` exist, so it keeps
/// its own tiny JSON file next to `app_settings.json` instead of going
/// through a provider.
class WindowPrefs {
  final double width;
  final double height;
  final double x;
  final double y;
  final bool isMaximized;

  const WindowPrefs({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.isMaximized,
  });

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'x': x,
    'y': y,
    'isMaximized': isMaximized,
  };

  /// Returns null on missing/malformed fields, or on values sane-checked to
  /// be corrupt (e.g. an absurdly large position). This only guards against
  /// clearly-broken data — real multi-monitor validation (is this position
  /// actually on a connected display) happens downstream, against live
  /// display bounds, via `_isPositionOnScreen` in `main.dart`. The x/y range
  /// is deliberately wide and symmetric (not just barely-negative) because a
  /// monitor positioned left of or above the primary display — a completely
  /// normal setup — produces legitimately large negative coordinates; a
  /// tight lower bound here would reject those before the real per-display
  /// check downstream ever got a chance to evaluate them correctly.
  static WindowPrefs? fromJson(Map<String, dynamic> json) {
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    final x = (json['x'] as num?)?.toDouble();
    final y = (json['y'] as num?)?.toDouble();
    if (width == null || height == null || x == null || y == null) {
      return null;
    }
    if (width < 400 ||
        height < 300 ||
        x < -20000 ||
        y < -20000 ||
        x > 20000 ||
        y > 20000) {
      return null;
    }
    return WindowPrefs(
      width: width,
      height: height,
      x: x,
      y: y,
      isMaximized: (json['isMaximized'] as bool?) ?? false,
    );
  }
}

class WindowPrefsService {
  static String get _filePath => appConfigFilePath('window_prefs.json');

  static WindowPrefs? load() {
    try {
      final file = File(_filePath);
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return WindowPrefs.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static void save(WindowPrefs prefs) {
    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(prefs.toJson()));
    } catch (_) {}
  }
}
