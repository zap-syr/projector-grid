import 'event_log_rows.dart';
import 'log_event.dart';

/// The event log's filter chips (plan §7k.1).
enum EventLogFilter { all, alerts, commands, connection, osc, web }

extension EventLogFilterLabel on EventLogFilter {
  String get label => switch (this) {
    EventLogFilter.all => 'All',
    EventLogFilter.alerts => 'Alerts',
    EventLogFilter.commands => 'Commands',
    EventLogFilter.connection => 'Connection',
    EventLogFilter.osc => 'OSC',
    EventLogFilter.web => 'Web',
  };
}

/// Whether [row] shows under [filter]. *Alerts* takes every error and
/// warning of any type and every alert event, the info ones too, so an
/// alert's history (raised, acknowledged, cleared) reads in one place.
/// *Web* takes the web server's events and the commands sent from the Web
/// page.
bool rowMatchesFilter(LogRow row, EventLogFilter filter) => switch (filter) {
  EventLogFilter.all => true,
  EventLogFilter.alerts =>
    row.type == LogEventType.alert ||
        row.severity == LogSeverity.error ||
        row.severity == LogSeverity.warning,
  EventLogFilter.commands => row.type == LogEventType.command,
  EventLogFilter.connection => row.type == LogEventType.connectivity,
  EventLogFilter.osc => row.type == LogEventType.osc,
  EventLogFilter.web =>
    row.type == LogEventType.web ||
        (row.type == LogEventType.command &&
            row.source?.kind == CommandSourceKind.web),
};

bool _has(String? text, String q) => text?.toLowerCase().contains(q) ?? false;

/// Whether [e]'s IP, model, message or source contains [query] (any case).
/// An empty query matches everything.
bool eventMatchesSearch(LogEvent e, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return _has(e.projectorIp, q) ||
      _has(e.projectorName, q) ||
      _has(e.message, q) ||
      _has(e.source?.label, q) ||
      _has(e.oscSender, q);
}

/// Whether a projector line of [row] matches [query]: the row then opens,
/// so a search for an IP shows it inside its batch.
bool batchOpenedBySearch(BatchLogRow row, String query) =>
    query.isNotEmpty && row.lines.any((l) => eventMatchesSearch(l, query));

/// The lines an opened row lists, as events: a batch's projector lines, a
/// group's projectors, a batch lens run's newest line per projector. Empty
/// for a row that doesn't open.
Iterable<LogEvent> rowLineEvents(LogRow row) => switch (row) {
  BatchLogRow(:final lines) => lines,
  GroupLogRow(:final members) => members,
  LensRunLogRow(isBatch: true) => row.totals.map((t) => t.latest),
  _ => const [],
};

/// Whether [row] has lines to open.
bool rowOpens(LogRow row) => switch (row) {
  BatchLogRow() || GroupLogRow() => true,
  LensRunLogRow(:final isBatch) => isBatch,
  _ => false,
};

/// Whether one of [row]'s lines matches [query]: the row then opens, so a
/// search for an IP shows it inside its batch or group.
bool rowOpenedBySearch(LogRow row, String query) {
  if (query.isEmpty) return false;
  // A group's projectors share its title (*Came online*): a search the
  // group line itself shows doesn't need them.
  if (row is GroupLogRow && _groupLineMatches(row, query.toLowerCase())) {
    return false;
  }
  return rowLineEvents(row).any((l) => eventMatchesSearch(l, query));
}

bool _groupLineMatches(GroupLogRow row, String q) =>
    _has(row.kind.title, q) || _has(row.target, q);

/// A key that names an opening row across rebuilds, as long as it stays
/// in the log: its batch id, or its first event.
String? rowOpenKey(LogRow row) => switch (row) {
  BatchLogRow(:final batch) => 'b:${batch.id}',
  GroupLogRow(:final members) => 'g:${identityHashCode(members.first)}',
  LensRunLogRow(isBatch: true, :final steps) =>
    'l:${(steps.last as BatchLogRow).batch.id}',
  _ => null,
};

/// Whether [row] matches [query]: its own text, or for a row that opens
/// any of its lines.
bool rowMatchesSearch(LogRow row, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return switch (row) {
    SingleLogRow(:final event) => eventMatchesSearch(event, query),
    RepeatLogRow(:final latest) => eventMatchesSearch(latest, query),
    BatchLogRow() =>
      _has(row.commandName, q) ||
          _has(row.batch.target, q) ||
          _has(row.source.label, q) ||
          rowOpenedBySearch(row, query),
    GroupLogRow() => _groupLineMatches(row, q) || rowOpenedBySearch(row, query),
    LensRunLogRow() =>
      _has(lensRunTitle, q) ||
          _has(row.batchTarget, q) ||
          _has(row.source?.label, q) ||
          (row.single != null && eventMatchesSearch(row.single!, query)) ||
          rowOpenedBySearch(row, query),
  };
}

/// The rows the log shows: [filter] and [query] applied, order kept.
List<LogRow> visibleRows(
  List<LogRow> rows,
  EventLogFilter filter,
  String query,
) => [
  for (final r in rows)
    if (rowMatchesFilter(r, filter) && rowMatchesSearch(r, query)) r,
];

/// Each chip's count, in rows: a batch counts once. The search doesn't
/// change them: they say what each filter holds, not what the current
/// search finds in it.
Map<EventLogFilter, int> rowFilterCounts(List<LogRow> rows) => {
  for (final f in EventLogFilter.values)
    f: rows.where((r) => rowMatchesFilter(r, f)).length,
};

/// A batch row's pills, in order, those at zero left out:
/// `4 sent`, `1 failed`, `1 skipped`.
List<(CommandOutcome, String)> batchPills(BatchLogRow row) =>
    outcomePills(row.sent, row.failed, row.skipped);

/// Outcome pills from counts, those at zero left out.
List<(CommandOutcome, String)> outcomePills(
  int sent,
  int failed,
  int skipped,
) => [
  if (sent > 0) (CommandOutcome.sent, '$sent sent'),
  if (failed > 0) (CommandOutcome.failed, '$failed failed'),
  if (skipped > 0) (CommandOutcome.skipped, '$skipped skipped'),
];

/// A lens run's pills: a batch run always shows them (*52 sent*, *1
/// failed*); a run to one projector only when a step didn't get through,
/// since *8 steps* already says the rest.
List<(CommandOutcome, String)> lensRunPills(LensRunLogRow row) =>
    !row.isBatch && row.failed + row.skipped == 0
    ? const []
    : outcomePills(row.sent, row.failed, row.skipped);

/// A lens run's command, H and V together.
const String lensRunTitle = 'Lens Shift';

/// The soft pill of a lens run: `8 steps, last 16:39:17`.
String lensRunCountText(LensRunLogRow row, DateTime now) =>
    '${row.stepCount} steps, last ${formatLogTime(row.timestamp, now)}';

/// The soft pill of a repeat: `14 times, last 21:02:41`.
String repeatCountText(RepeatLogRow row, DateTime now) =>
    '${row.count} times, last ${formatLogTime(row.timestamp, now)}';

/// One projector's totals in an opened lens run: `13 sent`, `12 sent, 1
/// failed`.
String lensTotalText(LensRunTotal t) =>
    outcomePills(t.sent, t.failed, t.skipped).map((p) => p.$2).join(', ');

/// Where [query] occurs in [text], any case, as `(start, end)` pairs that
/// don't overlap. Empty for an empty query.
List<(int, int)> searchMatchRanges(String text, String query) {
  if (query.isEmpty) return const [];
  final hay = text.toLowerCase();
  final needle = query.toLowerCase();
  final ranges = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = hay.indexOf(needle, from);
    if (i < 0) break;
    ranges.add((i, i + needle.length));
    from = i + needle.length;
  }
  return ranges;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// `21:04:12` for an event of [now]'s day, `19 Oct 23:58:04` for an earlier
/// one: the log isn't cleared at midnight, so a night shift would otherwise
/// mix two days under the same hours.
String formatLogTime(DateTime t, DateTime now) {
  final time = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) return time;
  return '${t.day} ${_months[t.month - 1]} $time';
}

/// The Source column's word for an event type.
String logSourceLabel(LogEventType type) => switch (type) {
  LogEventType.command => 'Command',
  LogEventType.osc => 'OSC',
  LogEventType.connectivity => 'Connection',
  LogEventType.alert => 'Alert',
  LogEventType.web => 'Web',
};

/// The Projector column as text: IP and model, or *App* for an event with
/// no projector.
String logProjectorText(LogEvent e) {
  final ip = e.projectorIp;
  final model = e.projectorName;
  if (ip == null) return model ?? 'App';
  return model == null || model.isEmpty ? ip : '$ip $model';
}

/// The OSC sender after an address: `from 10.0.0.20`.
String oscSenderLabel(String sender) => 'from $sender';

/// The Event column as text: the message, and where a command or an OSC
/// message came from.
String logEventText(LogEvent e) {
  final sender = e.oscSender;
  final from =
      e.source?.label ?? (sender == null ? null : oscSenderLabel(sender));
  return from == null ? e.message : '${e.message} $from';
}

String _copyFields(
  DateTime at,
  LogSeverity severity,
  String projector,
  LogEventType type,
  String event,
  DateTime now,
) => [
  formatLogTime(at, now),
  severity.name,
  projector,
  logSourceLabel(type),
  event,
].join('  ');

/// One copied row:
/// `21:04:12  error  10.0.1.33 PT-RZ120  Projector  Error F305: exhaust fan stopped`.
String logCopyLine(LogEvent e, DateTime now) => _copyFields(
  e.timestamp,
  e.severity,
  logProjectorText(e),
  e.type,
  logEventText(e),
  now,
);

/// A batch copied: its summary line, then each projector line indented
/// under it.
String logBatchCopyText(BatchLogRow row, DateTime now) => [
  _copyFields(
    row.timestamp,
    row.severity,
    row.batch.target,
    LogEventType.command,
    [
      '${row.commandName} ${row.source.label}',
      ...batchPills(row).map((p) => p.$2),
    ].join(', '),
    now,
  ),
  for (final l in row.lines) '  ${logCopyLine(l, now)}',
].join('\n');

/// A repeat copied: its newest event with the count after it.
String logRepeatCopyText(RepeatLogRow row, DateTime now) => _copyFields(
  row.timestamp,
  row.severity,
  logProjectorText(row.latest),
  row.type,
  '${logEventText(row.latest)}, ${repeatCountText(row, now)}',
  now,
);

/// A group copied: the group line, then each projector's line under it.
String logGroupCopyText(GroupLogRow row, DateTime now) => [
  _copyFields(
    row.timestamp,
    row.severity,
    row.target,
    row.type,
    row.kind.title,
    now,
  ),
  for (final e in row.lines) '  ${logCopyLine(e, now)}',
].join('\n');

/// A lens run copied: the run line and, for a batch run, each projector's
/// totals under it.
String logLensRunCopyText(LensRunLogRow row, DateTime now) {
  final single = row.single;
  return [
    _copyFields(
      row.timestamp,
      row.severity,
      single == null ? row.batchTarget! : logProjectorText(single),
      LogEventType.command,
      [
        '$lensRunTitle ${row.source?.label ?? ''}'.trimRight(),
        lensRunCountText(row, now),
        ...lensRunPills(row).map((p) => p.$2),
      ].join(', '),
      now,
    ),
    if (row.isBatch)
      for (final t in row.totals)
        '  ${_copyFields(t.latest.timestamp, lensTotalSeverity(t), logProjectorText(t.latest), LogEventType.command, lensTotalText(t), now)}',
  ].join('\n');
}

/// One projector's result over a lens run: error when a step failed.
LogSeverity lensTotalSeverity(LensRunTotal t) => t.failed > 0
    ? LogSeverity.error
    : t.sent > 0
    ? LogSeverity.success
    : LogSeverity.info;

/// One row as Copy writes it, with its lines when it has any.
String logRowCopyText(LogRow row, DateTime now) => switch (row) {
  SingleLogRow(:final event) => logCopyLine(event, now),
  BatchLogRow() => logBatchCopyText(row, now),
  RepeatLogRow() => logRepeatCopyText(row, now),
  GroupLogRow() => logGroupCopyText(row, now),
  LensRunLogRow() => logLensRunCopyText(row, now),
};

/// What Copy puts on the clipboard: every row shown, a batch or group
/// with its projector lines.
String logCopyText(List<LogRow> rows, DateTime now) =>
    rows.map((r) => logRowCopyText(r, now)).join('\n');

/// The line under *No events match*: what hides the rows, e.g.
/// `OSC, search "10.0.9.99"`.
String noMatchDescription(EventLogFilter filter, String query) {
  final parts = [
    if (filter != EventLogFilter.all) filter.label,
    if (query.isNotEmpty) 'search "$query"',
  ];
  final text = parts.join(', ');
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// Below this panel width the header is narrow: no title text, chips as
/// icon and count, a narrower search.
const double eventLogNarrowBelow = 1120;

/// Above this width it is full again. The band in between keeps the current
/// mode, so resizing across the edge doesn't flicker (as the toolbar, §7f.2).
const double eventLogFullAbove = 1200;

/// Whether the header is narrow at [width]. [wasNarrow] is the current mode,
/// null on the first build (the band then splits at its middle).
bool eventLogNarrow(double width, {bool? wasNarrow}) {
  if (width < eventLogNarrowBelow) return true;
  if (width > eventLogFullAbove) return false;
  return wasNarrow ?? width < (eventLogNarrowBelow + eventLogFullAbove) / 2;
}

/// Below this width the Source column hides (the 800 px window).
const double eventLogSourceColumnBelow = 900;

/// The panel's height: the saved [saved] within [min] and [max]. The saved
/// value isn't changed by a small window, so it comes back when the window
/// grows.
double eventLogPanelHeight(
  double saved, {
  required double min,
  required double max,
}) {
  final top = max < min ? min : max;
  return saved.clamp(min, top);
}
