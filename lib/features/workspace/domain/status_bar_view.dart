/// The status bar's pure parts: when it steps down to icons and counts, and
/// what the Offline tooltip lists.
library;

import 'package:flutter/foundation.dart';

import 'monitoring_layout.dart';
import 'projector_group.dart';
import 'projector_node.dart';

/// The least gap kept between the bar's left and right groups in the full
/// bar.
const double statusBarGap = 16;

/// How much more room than [statusBarGap] a narrow bar waits for before it
/// is full again, so a width or a value right at the edge doesn't flicker
/// (as the toolbar, §7f.2).
const double statusBarHysteresis = 40;

/// Whether the status bar is narrow (icons and counts, the names in
/// tooltips) in [width] when the full bar's items take [fullWidth] with the
/// current values. Chosen from what is shown, not from a fixed window width
/// (owner, 2026-10-20): a typical project's full bar takes about 920 px and
/// the longest values (three-digit counts, three alert pills, *port busy*,
/// *Web 12 (3 operators)*) about 1203, so a fixed threshold either cut a
/// roomy window to icons or let the worst case overflow. The cost: a value
/// that grows (a third alert pill) can step a tight window down to icons,
/// and back once it has the room again. [wasNarrow] is the current mode,
/// null before the first layout.
bool statusBarNarrow(
  double width, {
  required double fullWidth,
  bool? wasNarrow,
}) {
  final needs =
      fullWidth + statusBarGap + (wasNarrow ?? false ? statusBarHysteresis : 0);
  return width < needs;
}

/// One projector in the Offline tooltip.
typedef OfflineTooltipRow = ({String ip, String model});

/// The Offline tooltip: a title, up to [OfflineTooltip.maxRows] projectors
/// in Monitoring order and how many more, or when every projector is
/// offline only a hint. Value equality, so the open tooltip's `select`
/// rebuilds only when what it says changes.
class OfflineTooltip {
  static const int maxRows = 5;

  final String title;
  final List<OfflineTooltipRow> rows;

  /// `and 12 more`, or null when every offline projector is listed.
  final String? more;

  /// The hint shown instead of the list when every projector is offline.
  final String? note;

  const OfflineTooltip({
    required this.title,
    this.rows = const [],
    this.more,
    this.note,
  });

  @override
  bool operator ==(Object other) =>
      other is OfflineTooltip &&
      other.title == title &&
      listEquals(other.rows, rows) &&
      other.more == more &&
      other.note == note;

  @override
  int get hashCode => Object.hash(title, Object.hashAll(rows), more, note);
}

/// The Offline tooltip for [nodes]: the offline ones in Monitoring order
/// (by group in the project's group order, Ungrouped last, then by IP).
OfflineTooltip offlineTooltip(
  List<ProjectorNode> nodes,
  List<ProjectorGroup> groups,
) {
  final offline = [
    for (final n in nodes)
      if (n.connectionStatus == ConnectionStatus.offline) n,
  ];
  if (offline.isNotEmpty && offline.length == nodes.length) {
    return OfflineTooltip(
      title: 'All ${offline.length} offline',
      note: 'Check the network connection',
    );
  }
  final byId = {for (final n in offline) n.id: n};
  final sorted = sortMonitoringNodes(offline, 'projector', true, {
    for (final g in groups) g.id: g,
  });
  final ordered = [
    for (final s in monitoringSections(sorted, groups, true))
      for (final id in s.nodeIds) byId[id]!,
  ];
  final shown = ordered.take(OfflineTooltip.maxRows);
  final rest = ordered.length - shown.length;
  return OfflineTooltip(
    title: '${offline.length} offline',
    rows: [for (final n in shown) (ip: n.ipAddress, model: n.name)],
    more: rest > 0 ? 'and $rest more' : null,
  );
}
