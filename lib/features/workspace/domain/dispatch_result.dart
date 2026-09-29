import 'log_event.dart';
import 'projector_node.dart';

/// Outcome of sending one command to several projectors at once.
class DispatchResult {
  final String command;
  final int ok;
  final List<ProjectorNode> failed;

  /// Not connected (offline / unauthorized) — the command was never sent.
  final List<ProjectorNode> skipped;

  const DispatchResult({
    required this.command,
    required this.ok,
    this.failed = const [],
    this.skipped = const [],
  });

  int get total => ok + failed.length + skipped.length;
  bool get allOk => failed.isEmpty && skipped.isEmpty;
}

/// Summary line for the Event Log, e.g.
/// `Power On — 28/30 OK · 2 failed · 1 skipped. Failed: A, B. Skipped: C`.
String dispatchSummary(DispatchResult r) {
  final counts = [
    '${r.ok}/${r.total} OK',
    if (r.failed.isNotEmpty) '${r.failed.length} failed',
    if (r.skipped.isNotEmpty) '${r.skipped.length} skipped',
  ].join(' · ');
  String names(List<ProjectorNode> nodes) =>
      nodes.map((n) => n.name).join(', ');
  return [
    '${commandLabel(r.command)} — $counts',
    if (r.failed.isNotEmpty) 'Failed: ${names(r.failed)}',
    if (r.skipped.isNotEmpty) 'Skipped: ${names(r.skipped)}',
  ].join('. ');
}
