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

/// Whether [e] shows under [filter]. *Alerts* takes every error and warning
/// of any type and every alert event, the info ones too, so an alert's
/// history (raised, acknowledged, cleared) reads in one place.
bool eventMatchesFilter(LogEvent e, EventLogFilter filter) => switch (filter) {
  EventLogFilter.all => true,
  EventLogFilter.alerts =>
    e.type == LogEventType.alert ||
        e.severity == LogSeverity.error ||
        e.severity == LogSeverity.warning,
  EventLogFilter.commands => e.type == LogEventType.command,
  EventLogFilter.connection => e.type == LogEventType.connectivity,
  EventLogFilter.osc => e.type == LogEventType.osc,
  EventLogFilter.web => e.type == LogEventType.web,
};

/// Whether [e]'s IP, model or message contains [query] (any case). An empty
/// query matches everything.
bool eventMatchesSearch(LogEvent e, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return (e.projectorIp?.toLowerCase().contains(q) ?? false) ||
      (e.projectorName?.toLowerCase().contains(q) ?? false) ||
      e.message.toLowerCase().contains(q);
}

/// The rows the log shows: [filter] and [query] applied, order kept.
List<LogEvent> visibleEvents(
  List<LogEvent> events,
  EventLogFilter filter,
  String query,
) => [
  for (final e in events)
    if (eventMatchesFilter(e, filter) && eventMatchesSearch(e, query)) e,
];

/// Each chip's count. The search doesn't change them: they say what each
/// filter holds, not what the current search finds in it.
Map<EventLogFilter, int> eventFilterCounts(List<LogEvent> events) => {
  for (final f in EventLogFilter.values)
    f: events.where((e) => eventMatchesFilter(e, f)).length,
};

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

/// One copied row:
/// `21:04:12  error  10.0.1.33 PT-RZ120  Projector  Error F305: exhaust fan stopped`.
String logCopyLine(LogEvent e, DateTime now) => [
  formatLogTime(e.timestamp, now),
  e.severity.name,
  logProjectorText(e),
  logSourceLabel(e.type),
  e.message,
].join('  ');

/// What Copy puts on the clipboard: one line per row shown.
String logCopyText(List<LogEvent> events, DateTime now) =>
    events.map((e) => logCopyLine(e, now)).join('\n');

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
