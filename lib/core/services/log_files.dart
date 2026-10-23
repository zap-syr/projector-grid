/// Pure helpers of the two daily log files (ROADMAP §6): names, retention,
/// the line layout and the repeat gate of the app log.
library;

/// `events-2026-10-23.log`, `app-2026-10-23.log`.
String logFileName(String prefix, DateTime day) =>
    '$prefix-${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-'
    '${_two(day.day)}.log';

final _logFilePattern = RegExp(r'^(events|app)-(\d{4})-(\d{2})-(\d{2})\.log$');

/// The log files among [names] older than [keepDays] days, today included:
/// with 14, today's file and the 13 before it stay. Other files are left
/// alone, whatever they are.
List<String> logFilesToPrune(
  Iterable<String> names,
  DateTime today, {
  int keepDays = 14,
}) {
  final oldestKept = DateTime(
    today.year,
    today.month,
    today.day - keepDays + 1,
  );
  return [
    for (final name in names)
      if (_logFilePattern.firstMatch(name) case final m?)
        if (DateTime(
          int.parse(m[2]!),
          int.parse(m[3]!),
          int.parse(m[4]!),
        ).isBefore(oldestKept))
          name,
  ];
}

/// `21:14:05.123`: the file name holds the date.
String logTime(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.'
    '${t.millisecond.toString().padLeft(3, '0')}';

/// One line of a log: time, a fixed-width level, then [text]. Every further
/// line of [text] and of [detail] (a stack trace) is indented under it.
String logEntry(DateTime at, String level, String text, {String? detail}) {
  final lines = [
    ...text.trimRight().split('\n'),
    if (detail != null && detail.trim().isNotEmpty)
      ...detail.trimRight().split('\n'),
  ];
  final head = '${logTime(at)}  ${level.padRight(7)}  ${lines.first}';
  return [head, for (final l in lines.skip(1)) '    $l'].join('\n');
}

/// The first line of a session in each file, so the two files line up.
String logSessionHeader({
  required DateTime at,
  required String appVersion,
  required String os,
}) => '\n=== ${logTime(at)}  Projector Grid $appVersion started on $os ===';

/// What makes two errors the same for [ErrorRepeatGate]: the error's first
/// line and the first frame of its stack. [stack] is a [StackTrace], or its
/// text when it came from the protocol worker isolate.
String errorRepeatKey(Object error, Object? stack) {
  final message = error.toString().split('\n').first;
  final frame = stack
      ?.toString()
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  return '$message @ ${frame ?? ''}';
}

/// Lets an error through once per [window]: an error in `build` fires on
/// every frame and would bury everything else. The repeats held back are
/// counted and reported with the next one let through, or by [heldBack].
class ErrorRepeatGate {
  final Duration window;
  final _entries = <String, ({DateTime written, int held})>{};

  ErrorRepeatGate({this.window = const Duration(minutes: 1)});

  /// Null when [key] was written less than [window] ago (the repeat is
  /// counted); otherwise how many repeats were held back since it was.
  int? admit(String key, DateTime now) {
    final e = _entries[key];
    if (e != null && now.difference(e.written) < window) {
      _entries[key] = (written: e.written, held: e.held + 1);
      return null;
    }
    _entries[key] = (written: now, held: 0);
    return e?.held ?? 0;
  }

  /// Every key with repeats still held back, and how many; for the end of
  /// the session.
  Map<String, int> heldBack() => {
    for (final MapEntry(:key, :value) in _entries.entries)
      if (value.held > 0) key: value.held,
  };
}

String _two(int v) => v.toString().padLeft(2, '0');
