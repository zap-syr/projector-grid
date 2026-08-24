import 'dart:io';

/// Returns the full path to [filename] inside the app's per-platform config
/// directory (`%APPDATA%\ProjectorGrid\` on Windows, `~/Library/Application
/// Support/ProjectorGrid/` on macOS, `~/.config/ProjectorGrid/` elsewhere).
String appConfigFilePath(String filename) {
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
