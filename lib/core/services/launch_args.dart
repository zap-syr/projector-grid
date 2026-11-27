import 'dart:io';

import 'app_config_dir.dart';

const _configDirPrefix = '--config-dir=';

/// The config folder given as `--config-dir=<path>`, as an absolute path, or
/// null when the argument is absent or empty.
///
/// Everything else in [args] is ignored: macOS and Xcode add their own
/// (`-NSDocumentRevisionsDebugMode YES`), and a launcher must never be able
/// to stop the app with an argument it does not know. The last occurrence
/// wins. A relative path is resolved once here, so a later change of the
/// working directory cannot move the profile.
String? configDirFromArgs(List<String> args) {
  String? value;
  for (final arg in args) {
    if (arg.startsWith(_configDirPrefix)) {
      value = arg.substring(_configDirPrefix.length);
    }
  }
  if (value == null || value.isEmpty) return null;
  return Directory(value).absolute.path;
}

/// Creates [path] and its parents when missing. A failure is not caught: the
/// app must not start on a different profile than the one that was asked for.
void ensureConfigDir(String path) {
  Directory(path).createSync(recursive: true);
}

/// Applies `--config-dir` from [args] to [appConfigDirOverride] and returns
/// the config folder now in use, with whether it came from the argument.
/// Must run before anything reads or writes a per-user file, the log
/// included.
({String path, bool fromArg}) applyLaunchArgs(List<String> args) {
  final dir = configDirFromArgs(args);
  if (dir == null) return (path: appConfigDirPath, fromArg: false);
  ensureConfigDir(dir);
  appConfigDirOverride = dir;
  return (path: dir, fromArg: true);
}
