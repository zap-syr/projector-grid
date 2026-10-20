import 'log_event.dart';

/// One row of the event log: a single event, or a command sent to several
/// projectors with its projector lines folded under it (plan §7k.3).
sealed class LogRow {
  const LogRow();

  /// When the row last changed: its newest event.
  DateTime get timestamp;
  LogSeverity get severity;
  LogEventType get type;
  CommandSource? get source;
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
}

/// The rows of [events] (newest first, as the provider keeps them). A batch
/// takes the place of its newest event, so it is there from its first
/// reply and stays where it is while the others come in.
List<LogRow> buildLogRows(List<LogEvent> events) {
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

/// [events] (newest first) cut to the newest [maxRows] rows. A batch is one
/// row however many projector lines it has, and is kept or dropped whole,
/// so a command to 100 projectors doesn't take 101 places or lose half its
/// lines at the end of the log.
List<LogEvent> capLogRows(List<LogEvent> events, int maxRows) {
  final batchRow = <String, int>{};
  var rowCount = 0;
  final kept = <LogEvent>[];
  for (final e in events) {
    final id = e.batch?.id;
    final int row;
    if (id == null) {
      row = rowCount++;
    } else {
      row = batchRow.putIfAbsent(id, () => rowCount++);
    }
    if (row < maxRows) kept.add(e);
  }
  return kept.length == events.length ? events : kept;
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
