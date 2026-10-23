import '../../../core/services/log_files.dart';
import 'log_event.dart';

// Fits an IP with a model (`192.168.100.200 (PT-RQ35K2)`), so the text
// column starts in one place; a longer target pushes only its own line.
const _whoWidth = 28;

/// Turns Event Log events into lines of the event log file (ROADMAP §6). A
/// command to several projectors is written compactly: a line only for each
/// projector that failed or was skipped, and the summary with the counts,
/// so a show day's lens steps on 100 projectors don't bury what went wrong.
/// One instance per session: it counts each batch's lines until its summary.
class EventLogFileLines {
  final _tally = <String, Map<CommandOutcome, int>>{};

  /// The file line for [e], or null for a projector that a batch reached
  /// (only its count goes in, on the summary).
  String? lineFor(LogEvent e) {
    final batch = e.batch;
    if (batch == null) return eventLogLine(e);
    if (e.outcome case final outcome?) {
      final counts = _tally.putIfAbsent(batch.id, () => {});
      counts[outcome] = (counts[outcome] ?? 0) + 1;
      return outcome == CommandOutcome.sent ? null : eventLogLine(e);
    }
    return eventLogLine(e, counts: _tally.remove(batch.id) ?? const {});
  }
}

/// An Event Log event as a line of the event log file: time, severity, type,
/// the projector (or a batch's target), then the text with what the in-app
/// row shows around it, the command of a batch line, where a command came
/// from and, on a batch's summary, its [counts]; then the command's code. A
/// batch's lines and summary share its number, so they can be found
/// together.
String eventLogLine(LogEvent e, {Map<CommandOutcome, int>? counts}) {
  final batch = e.batch;
  final who = switch (e.projectorIp) {
    final ip? when (e.projectorName ?? '').isNotEmpty =>
      '$ip (${e.projectorName})',
    final ip? => ip,
    null => batch?.target ?? '',
  };
  final text = [
    if (batch != null && e.outcome != null)
      '${commandLabel(batch.command)}: ${e.message}'
    else
      e.message,
    if (e.source case final source?) source.label,
    if (e.oscSender case final sender?) 'from $sender',
    if (counts != null) ...[
      '${counts[CommandOutcome.sent] ?? 0} sent',
      if (counts[CommandOutcome.failed] case final n?) '$n failed',
      if (counts[CommandOutcome.skipped] case final n?) '$n skipped',
    ],
  ].join(', ');
  // The NTCONTROL code, which the app never shows: a lens step's name alone
  // doesn't say which way or how far.
  final command = batch?.command ?? e.command;
  final marks = [
    if (command != null) '[$command]',
    if (batch != null) '[batch ${batch.id.split('-').last}]',
  ];
  return logEntry(
    e.timestamp,
    e.severity.name.toUpperCase(),
    [
      e.type.name.padRight(12),
      who.padRight(_whoWidth),
      text,
      ...marks,
    ].join('  '),
  );
}
