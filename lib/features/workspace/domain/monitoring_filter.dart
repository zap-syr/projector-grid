/// The Monitoring bar's search and quick filters: which projectors the
/// table and the cards show. Session only, never saved.
library;

import 'package:flutter/foundation.dart';

import 'monitoring_status.dart';
import 'projector_node.dart';

/// One at a time, like tabs; [all] is the default. They overlap: a
/// projector in standby with a warning is Online, Attention and Standby.
enum MonitoringQuickFilter { all, online, attention, offline, standby }

class MonitoringFilter {
  final String query;
  final MonitoringQuickFilter quick;

  const MonitoringFilter({
    this.query = '',
    this.quick = MonitoringQuickFilter.all,
  });

  /// Something is hidden: a search or a quick filter other than All.
  bool get active =>
      query.trim().isNotEmpty || quick != MonitoringQuickFilter.all;

  MonitoringFilter copyWith({String? query, MonitoringQuickFilter? quick}) =>
      MonitoringFilter(query: query ?? this.query, quick: quick ?? this.quick);

  @override
  bool operator ==(Object other) =>
      other is MonitoringFilter && other.query == query && other.quick == quick;

  @override
  int get hashCode => Object.hash(query, quick);
}

bool matchesQuickFilter(MonitoringQuickFilter filter, MonitoringStatus s) =>
    switch (filter) {
      MonitoringQuickFilter.all => true,
      MonitoringQuickFilter.online => s.online,
      MonitoringQuickFilter.attention =>
        s.level == ProblemLevel.warning || s.level == ProblemLevel.error,
      MonitoringQuickFilter.offline => s.level == ProblemLevel.offline,
      MonitoringQuickFilter.standby => s.standby,
    };

/// Whether [node]'s IP, model or serial contain every word of [query],
/// ignoring case, so `rz 10.0.1` narrows to one model in one subnet.
bool matchesSearch(ProjectorNode node, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;
  final serial = node.serialNumber == '-' ? '' : node.serialNumber;
  final text = '${node.ipAddress} ${node.name} $serial'.toLowerCase();
  return words.every(text.contains);
}

/// Node ids with value equality, so a `select` of them rebuilds only when
/// the set itself changes, not on every poll.
class NodeIdSet {
  final Set<String> ids;

  const NodeIdSet(this.ids);

  bool contains(String id) => ids.contains(id);

  @override
  bool operator ==(Object other) =>
      other is NodeIdSet && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

/// The ids in [statuses] that [filter] lets through.
NodeIdSet quickFilterIds(
  Map<String, MonitoringStatus> statuses,
  MonitoringQuickFilter filter,
) => NodeIdSet({
  for (final e in statuses.entries)
    if (matchesQuickFilter(filter, e.value)) e.key,
});

/// How many projectors each quick filter shows, for the counts on the bar.
class QuickFilterCounts {
  final List<int> _counts;

  const QuickFilterCounts._(this._counts);

  int operator [](MonitoringQuickFilter filter) => _counts[filter.index];

  @override
  bool operator ==(Object other) =>
      other is QuickFilterCounts && listEquals(other._counts, _counts);

  @override
  int get hashCode => Object.hashAll(_counts);
}

QuickFilterCounts quickFilterCounts(Iterable<MonitoringStatus> statuses) {
  final counts = List.filled(MonitoringQuickFilter.values.length, 0);
  for (final s in statuses) {
    for (final f in MonitoringQuickFilter.values) {
      if (matchesQuickFilter(f, s)) counts[f.index]++;
    }
  }
  return QuickFilterCounts._(List.unmodifiable(counts));
}
