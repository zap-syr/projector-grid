import 'dart:convert';
import 'dart:io';

import 'app_log_file.dart';

/// Writes [contents] to [path] so a crash or power loss never leaves a
/// truncated file: the full text goes to `<path>.tmp` in the same folder
/// (same volume, so the rename is one filesystem operation) and the temp file
/// then replaces [path]. A stale `.tmp` from an earlier crash is simply
/// overwritten. Throws when the write or the rename fails; the temp file is
/// removed and [path] keeps its old contents.
void writeFileAtomicSync(String path, String contents) {
  File(path).parent.createSync(recursive: true);
  final tmp = File('$path.tmp');
  try {
    tmp.writeAsStringSync(contents, flush: true);
    tmp.renameSync(path);
  } catch (_) {
    _deleteQuietly(tmp);
    rethrow;
  }
}

/// [writeFileAtomicSync] for callers that are already async.
Future<void> writeFileAtomic(String path, String contents) async {
  await File(path).parent.create(recursive: true);
  final tmp = File('$path.tmp');
  try {
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(path);
  } catch (_) {
    _deleteQuietly(tmp);
    rethrow;
  }
}

/// Saves a settings-type file atomically. A failure goes to the app log and
/// is not thrown: these files are rewritten on every change and a full or
/// locked disk must not break the action that triggered the save. [what]
/// names the file in the log, for example `App settings`.
void saveConfigFileSync(String path, String what, String contents) {
  try {
    writeFileAtomicSync(path, contents);
  } catch (e, stack) {
    AppLog.error('$what save', e, stack);
  }
}

/// Reads a settings-type JSON file and hands the decoded value to [parse].
///
/// Returns null when the file does not exist (the normal first run, nothing
/// logged) and when it cannot be used: unreadable, not valid JSON, or [parse]
/// throws. In the second case the file is renamed to `<name>.bad-<timestamp>`
/// so the next save does not overwrite what the user had, and the log names
/// the file, the reason and the new path. The caller falls back to defaults.
/// A [parse] that returns normally is trusted, even if it dropped some
/// values.
T? readJsonConfigOrQuarantine<T>(
  String path,
  String what,
  T Function(Object? json) parse,
) {
  final file = File(path);
  try {
    if (!file.existsSync()) return null;
    return parse(jsonDecode(file.readAsStringSync()));
  } catch (e, stack) {
    _quarantine(file, what, e, stack);
    return null;
  }
}

void _quarantine(File file, String what, Object cause, StackTrace stack) {
  // The reason is part of the logged error, not only of the stack: the log
  // collapses a repeated error, and two bad files can fail with the same
  // text.
  final String outcome;
  try {
    final bad = _badCopyPath(file.path, DateTime.now());
    file.renameSync(bad);
    outcome = 'moved to $bad';
  } catch (renameError) {
    AppLog.error(
      '$what load',
      '${file.path} is unusable ($cause), and it could not be moved aside '
          '($renameError)',
      stack,
    );
    return;
  }
  AppLog.error(
    '$what load',
    '${file.path} is unusable ($cause), $outcome, defaults are used',
    stack,
  );
}

// Two loads in the same second must not overwrite each other's copy.
String _badCopyPath(String path, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  var candidate = '$path.bad-$stamp';
  for (var n = 2; File(candidate).existsSync(); n++) {
    candidate = '$path.bad-$stamp-$n';
  }
  return candidate;
}

void _deleteQuietly(File file) {
  try {
    file.deleteSync();
  } on FileSystemException {
    // The temp file is already gone or locked; the write error is the one
    // worth reporting.
  }
}
