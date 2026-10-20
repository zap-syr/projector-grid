/// The status bar's pure parts: when it steps down to icons and counts, and
/// what the Offline tooltip lists.
library;

import 'package:flutter/foundation.dart';

import 'monitoring_layout.dart';
import 'projector_group.dart';
import 'projector_node.dart';

/// Below this window width the status bar is narrow: icons and counts, the
/// names in tooltips. Measured in Inter and IBM Plex Mono: the full bar with
/// its longest values (three-digit projector counts, all three alert pills
/// at two digits, OSC *65535 port busy*, *Web 12 (3 operators)*, the time)
/// needs 1199 px (1192 with port 9000, 1222 with three-digit pills); this
/// keeps about 40 px of margin, and three-digit pills still fit. The narrow
/// bar with the same values needs 702 px.
const double statusBarNarrowBelow = 1240;

/// Above this width it is full again. The band in between keeps the current
/// mode, so resizing across the edge doesn't flicker (as the toolbar, §7f.2).
const double statusBarFullAbove = 1280;

/// Whether the status bar is narrow at [windowWidth]. Chosen from the
/// window, not the bar's content, so a count can never switch the mode.
/// [wasNarrow] is the current mode (null on the first build, when the band
/// splits at its middle).
bool statusBarNarrow(double windowWidth, {bool? wasNarrow}) {
  if (windowWidth < statusBarNarrowBelow) return true;
  if (windowWidth > statusBarFullAbove) return false;
  return wasNarrow ??
      windowWidth < (statusBarNarrowBelow + statusBarFullAbove) / 2;
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
