import 'dart:io';

import 'package:flutter/foundation.dart';

/// Redirects [appConfigFilePath] to a scratch directory so tests never read
/// or overwrite the real user's settings, recent projects or custom commands.
@visibleForTesting
String? debugAppConfigDirOverride;

/// Set once at startup from `--config-dir=<path>` so a launch can use an
/// isolated profile instead of the user's real one. [debugAppConfigDirOverride]
/// still wins, so tests are unaffected.
String? appConfigDirOverride;

/// The folder [appConfigFilePath] resolves against, without a trailing
/// separator.
String get appConfigDirPath =>
    appConfigFilePath('').replaceFirst(RegExp(r'[\\/]$'), '');

/// Returns the full path to [filename] inside the app's per-platform config
/// directory (`%APPDATA%\ProjectorGrid\` on Windows, `~/Library/Application
/// Support/ProjectorGrid/` on macOS, `~/.config/ProjectorGrid/` elsewhere),
/// or inside [appConfigDirOverride] when one is set.
String appConfigFilePath(String filename) {
  final override = debugAppConfigDirOverride ?? appConfigDirOverride;
  if (override != null) {
    return '$override${Platform.pathSeparator}$filename';
  }
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '';
    return '$appData\\ProjectorGrid\\$filename';
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/ProjectorGrid/$filename';
  } else {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/ProjectorGrid/$filename';
  }
}
