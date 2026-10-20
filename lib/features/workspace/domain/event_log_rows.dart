import 'command_log.dart';
import 'event_log_fold.dart';
import 'log_event.dart';

/// One row of the event log: a single event, a command sent to several
/// projectors with its projector lines folded under it (plan §7k.3), or
/// events folded together (§7k.2): repeats, groups across projectors and
/// lens nudges.
sealed class LogRow {
  const LogRow();

  /// When the row last changed: its newest event.
  DateTime get timestamp;
  LogSeverity get severity;
  LogEventType get type;
  CommandSource? get source;

  /// Every event the row stands for, so the cap keeps or drops them whole.
  Iterable<LogEvent> get events;
}

class SingleLogRow extends LogRow {
  const SingleLogRow(this.event);

  final LogEvent event;

  @override
  DateTime get timestamp => event.timestamp;
  @override
  LogSeverity get severity => event.severity;
  @override
  LogEventType get type => event.type;
  @override
  CommandSource? get source => event.source;
  @override
  Iterable<LogEvent> get events => [event];
}

class BatchLogRow extends LogRow {
  const BatchLogRow({
    required this.batch,
    required this.lines,
    required this.summary,
    required this.timestamp,
  });

  final CommandBatch batch;

  /// The projector lines that have come in, in [CommandBatch.nodeIds]
  /// order.
  final List<LogEvent> lines;

  /// The closing event; null while replies are still coming in.
  final LogEvent? summary;

  @override
  final DateTime timestamp;

  bool get done => summary != null;

  int _count(CommandOutcome o) => lines.where((l) => l.outcome == o).length;
  int get sent => _count(CommandOutcome.sent);
  int get failed => _count(CommandOutcome.failed);
  int get skipped => _count(CommandOutcome.skipped);

  /// The projectors to send to again, by id: an IP can change.
  List<String> get failedNodeIds => [
    for (final l in lines)
      if (l.outcome == CommandOutcome.failed && l.nodeId != null) l.nodeId!,
  ];

  /// Info when every projector got it, warning when some failed or were
  /// skipped, so the row shows under *Alerts*.
  @override
  LogSeverity get severity =>
      failed + skipped > 0 ? LogSeverity.warning : LogSeverity.info;

  @override
  LogEventType get type => LogEventType.command;

  @override
  CommandSource get source => batch.source;

  /// The command's name, as the Event column shows it.
  String get commandName => commandLabel(batch.command);

  @override
  Iterable<LogEvent> get events => [?summary, ...lines];
}

/// The same event from one projector over and over, with nothing else
/// from that projector in between: *14 times, last 21:02:41*.
class RepeatLogRow extends LogRow {
  const RepeatLogRow(this.repeats);

  /// Newest first; two or more.
  final List<LogEvent> repeats;

  LogEvent get latest => repeats.first;
  int get count => repeats.length;

  @override
  DateTime get timestamp => latest.timestamp;
  @override
  LogSeverity get severity => latest.severity;
  @override
  LogEventType get type => latest.type;
  @override
  CommandSource? get source => latest.source;
  @override
  Iterable<LogEvent> get events => repeats;
}

int _rank(LogSeverity s) => switch (s) {
  LogSeverity.error => 3,
  LogSeverity.warning => 2,
  LogSeverity.success => 1,
  LogSeverity.info => 0,
};

/// The same kind of event from several projectors at once: *20 projectors,
/// Came online*. Opened, it lists each projector with its own text.
class GroupLogRow extends LogRow {
  const GroupLogRow(this.kind, this.members);

  final LogGroupKind kind;

  /// One event per projector, in the order they came; two or more.
  final List<LogEvent> members;

  /// The Projector column: the project group when every projector is in
  /// it, else *N projectors*.
  String get target {
    final groups = members.map((e) => e.projectorGroup).toSet();
    return projectorCountLabel(
      members.length,
      groups.length == 1 ? groups.first : null,
    );
  }

  @override
  DateTime get timestamp => members.last.timestamp;

  /// They are the same kind, but the Offline rule can colour one
  /// projector's line differently; the row shows the worst.
  @override
  LogSeverity get severity => members
      .map((e) => e.severity)
      .reduce((a, b) => _rank(a) >= _rank(b) ? a : b);
  @override
  LogEventType get type => members.first.type;
  @override
  CommandSource? get source => null;
  @override
  Iterable<LogEvent> get events => members;
}

/// One projector's share of a lens run sent to several projectors.
class LensRunTotal {
  const LensRunTotal({
    required this.latest,
    required this.sent,
    required this.failed,
    required this.skipped,
  });

  /// The projector's newest line: its IP, model and time.
  final LogEvent latest;
  final int sent;
  final int failed;
  final int skipped;
}

/// Lens Shift steps to the same target from the same source, each less
/// than 3 s after the previous: *Lens Shift, 8 steps, last 16:39:17*.
class LensRunLogRow extends LogRow {
  const LensRunLogRow(this.steps);

  /// Newest first; two or more, all [SingleLogRow]s to one projector or
  /// all [BatchLogRow]s to the same projectors.
  final List<LogRow> steps;

  bool get isBatch => steps.first is BatchLogRow;
  int get stepCount => steps.length;

  /// The newest step to a single projector; null for a batch run.
  LogEvent? get single => switch (steps.first) {
    SingleLogRow(:final event) => event,
    _ => null,
  };

  /// A batch run's Projector column, from its newest step.
  String? get batchTarget => switch (steps.first) {
    BatchLogRow(:final batch) => batch.target,
    _ => null,
  };

  /// Every projector line of every step.
  Iterable<LogEvent> get _outcomes => steps.expand(
    (s) => switch (s) {
      SingleLogRow(:final event) => [event],
      BatchLogRow(:final lines) => lines,
      _ => const <LogEvent>[],
    },
  );

  int _count(CommandOutcome o) => _outcomes.where((l) => l.outcome == o).length;
  int get sent => _count(CommandOutcome.sent);
  int get failed => _count(CommandOutcome.failed);
  int get skipped => _count(CommandOutcome.skipped);

  /// Every reply of every step is in.
  bool get done => steps.every((s) => s is! BatchLogRow || s.done);

  /// Each projector once, with its totals over the run, in the newest
  /// batch's order.
  List<LensRunTotal> get totals {
    final latest = <String, LogEvent>{};
    final counts = <String, List<int>>{};
    // Oldest first, so the newest line is the one kept.
    for (final line in _outcomes.toList().reversed) {
      final id = line.nodeId ?? line.projectorIp ?? '';
      latest[id] = line;
      final c = counts.putIfAbsent(id, () => [0, 0, 0]);
      c[line.outcome!.index]++;
    }
    final order = switch (steps.first) {
      BatchLogRow(:final batch) => batch.nodeIds,
      _ => const <String>[],
    };
    final ids = [
      for (final id in order)
        if (latest.containsKey(id)) id,
      for (final id in latest.keys)
        if (!order.contains(id)) id,
    ];
    return [
      for (final id in ids)
        LensRunTotal(
          latest: latest[id]!,
          sent: counts[id]![CommandOutcome.sent.index],
          failed: counts[id]![CommandOutcome.failed.index],
          skipped: counts[id]![CommandOutcome.skipped.index],
        ),
    ];
  }

  @override
  DateTime get timestamp => steps.first.timestamp;
  @override
  LogSeverity get severity =>
      failed + skipped > 0 ? LogSeverity.warning : LogSeverity.info;
  @override
  LogEventType get type => LogEventType.command;
  @override
  CommandSource? get source => steps.first.source;
  @override
  Iterable<LogEvent> get events => steps.expand((s) => s.events);
}

/// The rows of [events] (newest first, as the provider keeps them). A batch
/// takes the place of its newest event, so it is there from its first
/// reply and stays where it is while the others come in. Repeats, groups
/// across projectors and lens runs are then folded (`foldLogRows`), each
/// in the place of its newest event too.
List<LogRow> buildLogRows(List<LogEvent> events) =>
    foldLogRows(_batchRows(events));

List<LogRow> _batchRows(List<LogEvent> events) {
  final rows = <LogRow>[];
  final batchAt = <String, int>{};
  final linesOf = <String, List<LogEvent>>{};
  final summaryOf = <String, LogEvent>{};
  for (final e in events) {
    final batch = e.batch;
    if (batch == null) {
      rows.add(SingleLogRow(e));
      continue;
    }
    if (!batchAt.containsKey(batch.id)) {
      batchAt[batch.id] = rows.length;
      linesOf[batch.id] = [];
      // A placeholder, replaced once every event of the batch is read.
      rows.add(SingleLogRow(e));
    }
    if (e.isBatchSummary) {
      summaryOf[batch.id] = e;
    } else {
      linesOf[batch.id]!.add(e);
    }
  }
  for (final MapEntry(key: id, value: at) in batchAt.entries) {
    final first = (rows[at] as SingleLogRow).event;
    final batch = first.batch!;
    final order = {for (final (i, n) in batch.nodeIds.indexed) n: i};
    final lines = linesOf[id]!
      ..sort((a, b) => (order[a.nodeId] ?? 0).compareTo(order[b.nodeId] ?? 0));
    rows[at] = BatchLogRow(
      batch: batch,
      lines: lines,
      summary: summaryOf[id],
      timestamp: first.timestamp,
    );
  }
  return rows;
}

/// [events] (newest first) cut to the newest [maxRows] rows, rows as the
/// log shows them: a batch, a repeat, a group or a lens run is one row
/// however many events it holds, and is kept or dropped whole, so a
/// command to 100 projectors doesn't take 101 places or lose half its
/// lines at the end of the log.
List<LogEvent> capLogRows(List<LogEvent> events, int maxRows) {
  // A row holds at least one event: under the cap in events is under it
  // in rows, without building them.
  if (events.length <= maxRows) return events;
  final rows = buildLogRows(events);
  if (rows.length <= maxRows) return events;
  final kept = Set<LogEvent>.identity()
    ..addAll(rows.take(maxRows).expand((r) => r.events));
  return [
    for (final e in events)
      if (kept.contains(e)) e,
  ];
}

/// The projectors *Retry failed* sends to: [failedIds] still in the
/// workspace ([existingIds]); a projector removed since is skipped.
List<String> retryTargets(
  Iterable<String> failedIds,
  Iterable<String> existingIds,
) {
  final existing = existingIds.toSet();
  return [
    for (final id in failedIds)
      if (existing.contains(id)) id,
  ];
}
