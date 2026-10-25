import 'dart:async';
import 'dart:io';

import 'app_config_dir.dart';
import 'log_files.dart';

/// Both daily logs live here, next to the settings.
String get logsFolderPath => appConfigFilePath('logs');

/// One of the daily files: entries are buffered and appended at most once a
/// second, so a burst of events is one write, and the file follows the date
/// of each entry.
class DailyLogFile {
  final String folder;
  final String prefix;

  /// About how large a day's file may grow; past it only errors go in.
  final int? maxBytes;

  DailyLogFile(this.folder, this.prefix, {this.maxBytes});

  final _buffer = StringBuffer();
  DateTime? _bufferDay;
  DateTime? _sizeDay;
  int _size = 0;
  bool _capNoted = false;
  Timer? _flushTimer;

  String pathFor(DateTime day) =>
      '$folder${Platform.pathSeparator}${logFileName(prefix, day)}';

  void write(DateTime at, String entry, {bool isError = false}) {
    final day = DateTime(at.year, at.month, at.day);
    if (day != _bufferDay) {
      flush();
      _bufferDay = day;
    }
    if (day != _sizeDay) {
      _sizeDay = day;
      _size = _existingSize(day);
      _capNoted = false;
    }
    final cap = maxBytes;
    if (cap != null && _size >= cap) {
      if (!isError) return;
      if (!_capNoted) {
        _capNoted = true;
        _append(
          logEntry(
            at,
            'NOTE',
            'This file reached ${cap ~/ (1024 * 1024)} MB, only errors are '
                'written from here on',
          ),
        );
      }
    }
    _append(entry);
    _flushTimer ??= Timer(const Duration(seconds: 1), flush);
  }

  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final day = _bufferDay;
    if (day == null || _buffer.isEmpty) return;
    final text = _buffer.toString();
    _buffer.clear();
    try {
      final file = File(pathFor(day));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text, mode: FileMode.append);
    } on FileSystemException {
      // A full or locked disk: there is nowhere left to report it, and a
      // log must never take the app down.
    }
  }

  // Characters, not bytes: the cap is a guard against runaway growth, not
  // an exact size.
  void _append(String entry) {
    _buffer
      ..write(entry)
      ..write('\n');
    _size += entry.length + 1;
  }

  int _existingSize(DateTime day) {
    try {
      final file = File(pathFor(day));
      return file.existsSync() ? file.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }
}

/// The event log and the app log (ROADMAP §6). The event log file gets every
/// line of the in-app Event Log; the app log gets internal errors with their
/// stack and diagnostics, and is never shown in the UI. Nothing is written
/// before [start], so tests, which never call it, write no files.
abstract final class AppLog {
  static DailyLogFile? _events;
  static DailyLogFile? _app;
  static var _gate = ErrorRepeatGate();

  static const _appCapBytes = 20 * 1024 * 1024;

  /// Prunes files past the 14 days and opens both logs with a session
  /// header.
  static void start({required String appVersion, required String os}) {
    final now = DateTime.now();
    final folder = logsFolderPath;
    _prune(folder, now);
    _gate = ErrorRepeatGate();
    _events = DailyLogFile(folder, 'events');
    _app = DailyLogFile(folder, 'app', maxBytes: _appCapBytes);
    final header = logSessionHeader(at: now, appVersion: appVersion, os: os);
    _events!.write(now, header);
    _app!.write(now, header, isError: true);
  }

  /// One line of the Event Log, already laid out.
  static void event(DateTime at, String entry) => _events?.write(at, entry);

  /// A line for both files, such as the project that was opened, so either
  /// one reads on its own.
  static void note(String text) {
    final now = DateTime.now();
    final entry = logEntry(now, 'NOTE', text);
    _events?.write(now, entry);
    _app?.write(now, entry, isError: true);
  }

  /// A diagnostic for the developer: app log only.
  static void info(String text) {
    final now = DateTime.now();
    _app?.write(now, logEntry(now, 'INFO', text));
  }

  /// An internal error with its stack: app log only, the same error at most
  /// once a minute. [stack] is a [StackTrace] or, from the protocol worker
  /// isolate, its text.
  static void error(String source, Object error, Object? stack) {
    final app = _app;
    if (app == null) return;
    final now = DateTime.now();
    final held = _gate.admit(errorRepeatKey(error, stack), now);
    if (held == null) return;
    final repeats = held > 0
        ? ' (repeated $held times since last written)'
        : '';
    app.write(
      now,
      logEntry(
        now,
        'ERROR',
        '$source: $error$repeats',
        detail: stack?.toString(),
      ),
      isError: true,
    );
  }

  /// Writes the repeats still held back and the session end, then flushes.
  /// Called right before the window is destroyed.
  static void stop() {
    final events = _events;
    final app = _app;
    if (events == null || app == null) return;
    final now = DateTime.now();
    for (final MapEntry(:key, :value) in _gate.heldBack().entries) {
      app.write(
        now,
        logEntry(now, 'ERROR', 'Repeated $value more times: $key'),
        isError: true,
      );
    }
    final end = '=== ${logTime(now)}  Projector Grid stopped ===';
    events.write(now, end);
    app.write(now, end, isError: true);
    events.flush();
    app.flush();
    _events = null;
    _app = null;
  }

  /// Help → Open logs folder.
  static Future<void> openFolder() async {
    final folder = Directory(logsFolderPath);
    await folder.create(recursive: true);
    if (Platform.isWindows) {
      await Process.run('explorer', [folder.path]);
    } else {
      await Process.run('open', [folder.path]);
    }
  }

  static void _prune(String folder, DateTime now) {
    try {
      final dir = Directory(folder);
      if (!dir.existsSync()) return;
      final names = [
        for (final f in dir.listSync().whereType<File>())
          f.uri.pathSegments.last,
      ];
      for (final name in logFilesToPrune(names, now)) {
        try {
          File('$folder${Platform.pathSeparator}$name').deleteSync();
        } on FileSystemException {
          // Open elsewhere (an editor holds it on Windows): it goes on a
          // later launch, and the files after it go now.
        }
      }
    } on FileSystemException {
      // The folder itself can't be listed; pruning waits for a later launch.
    }
  }
}
