/// The order of the Monitoring view: the sort per table column and the
/// group sections the table and the cards share.
library;

import 'package:flutter/foundation.dart';

import 'ip_sort.dart';
import 'projector_group.dart';
import 'projector_node.dart';
import 'test_patterns.dart';

/// The leading number of a display value (`1,644H`, `25°C`, `230V`),
/// thousands separators ignored; `-` and other non-readings sort first
/// (ascending).
num leadingNumber(String display) {
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(display.replaceAll(',', ''));
  return m == null ? double.negativeInfinity : num.parse(m.group(0)!);
}

/// The sort key of [n] for the table column [columnId]. One type per column
/// (num, int or String), so `Comparable.compare` never mixes types.
Comparable monitoringSortKey(
  String columnId,
  ProjectorNode n,
  Map<String, ProjectorGroup> groups,
) => switch (columnId) {
  'projector' || 'ip' => ipSortKey(n.ipAddress),
  // Ungrouped sorts last (ascending).
  'group' => (groups[n.groupId]?.name ?? '￿').toLowerCase(),
  'power' => switch (n.powerStatus) {
    PowerStatus.on => 0,
    PowerStatus.turningOn => 1,
    PowerStatus.cooling => 2,
    PowerStatus.standby => 3,
  },
  'shutter' => n.shutterStatus == ShutterStatus.open ? 0 : 1,
  'inputSignal' || 'input' => n.input.toLowerCase(),
  'signal' => n.signal.toLowerCase(),
  'temperature' =>
    leadingNumber(n.exhaustTemp) > leadingNumber(n.intakeTemp)
        ? leadingNumber(n.exhaustTemp)
        : leadingNumber(n.intakeTemp),
  'runtimes' || 'runtime' => leadingNumber(n.runtime),
  'lightRuntime' => leadingNumber(n.lightRuntime),
  'voltage' => leadingNumber(n.acVoltage),
  'intake' => leadingNumber(n.intakeTemp),
  'exhaust' => leadingNumber(n.exhaustTemp),
  // Faulted first (ascending); not polled yet sorts with the healthy ones.
  'errors' || 'errorCodes' =>
    n.errors == '-' || n.errors == 'NO ERRORS' || n.errors.isEmpty
        ? '1'
        : '0${n.errors}',
  'connection' => switch (n.connectionStatus) {
    ConnectionStatus.connected => 0,
    ConnectionStatus.unprotected => 1,
    ConnectionStatus.unauthorized => 2,
    ConnectionStatus.offline => 3,
  },
  'model' => n.name.toLowerCase(),
  'serial' => n.serialNumber.toLowerCase(),
  'testPattern' =>
    (n.testPattern == null ? '-' : testPatternLabel(n.testPattern!))
        .toLowerCase(),
  _ => 0,
};

/// [nodes] sorted by [columnId]; ties keep their IP order, so rows don't
/// swap places between polls.
List<ProjectorNode> sortMonitoringNodes(
  List<ProjectorNode> nodes,
  String columnId,
  bool ascending,
  Map<String, ProjectorGroup> groups,
) {
  final sorted = List.of(nodes);
  mergeSort(
    sorted,
    compare: (a, b) {
      final c = Comparable.compare(
        monitoringSortKey(columnId, a, groups),
        monitoringSortKey(columnId, b, groups),
      );
      if (c != 0) return ascending ? c : -c;
      return ipSortKey(a.ipAddress).compareTo(ipSortKey(b.ipAddress));
    },
  );
  return sorted;
}

/// One block of the view: a group's projectors under its group row, the
/// Ungrouped ones ([group] null), or with *Group by: none* the whole list
/// ([flat]).
class MonitoringSection {
  final ProjectorGroup? group;
  final List<String> nodeIds;
  final bool flat;

  const MonitoringSection(this.group, this.nodeIds, {this.flat = false});

  /// The key [MonitoringViewSettings.collapsed] stores: the group id, or ''
  /// for Ungrouped.
  String get key => group?.id ?? '';

  @override
  bool operator ==(Object other) =>
      other is MonitoringSection &&
      other.group == group &&
      other.flat == flat &&
      listEquals(other.nodeIds, nodeIds);

  @override
  int get hashCode => Object.hash(group, flat, Object.hashAll(nodeIds));
}

/// What the table and the cards lay out: the sections, and the project's
/// groups for the Group column. Value equality, so a poll that doesn't
/// change the order rebuilds nothing.
class MonitoringLayout {
  final List<ProjectorGroup> groups;
  final List<MonitoringSection> sections;

  const MonitoringLayout(this.groups, this.sections);

  Map<String, ProjectorGroup> get groupsById => {
    for (final g in groups) g.id: g,
  };

  @override
  bool operator ==(Object other) =>
      other is MonitoringLayout &&
      listEquals(other.groups, groups) &&
      listEquals(other.sections, sections);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(groups), Object.hashAll(sections));
}

/// [nodes] sorted by [columnId] and split into sections.
MonitoringLayout monitoringLayout(
  List<ProjectorNode> nodes,
  List<ProjectorGroup> groups, {
  required String columnId,
  required bool ascending,
  required bool byGroup,
}) {
  final sorted = sortMonitoringNodes(nodes, columnId, ascending, {
    for (final g in groups) g.id: g,
  });
  return MonitoringLayout(
    List.unmodifiable(groups),
    monitoringSections(sorted, groups, byGroup),
  );
}

/// [sorted] split into sections. Grouped: one per group in the project's
/// group order (Manage Groups), each keeping the sort inside it, then
/// Ungrouped (with any node whose group no longer exists); empty groups are
/// left out. Not grouped: one flat section.
List<MonitoringSection> monitoringSections(
  List<ProjectorNode> sorted,
  List<ProjectorGroup> groups,
  bool byGroup,
) {
  if (!byGroup) {
    return [
      MonitoringSection(null, [for (final n in sorted) n.id], flat: true),
    ];
  }
  final known = {for (final g in groups) g.id};
  final byGroupId = <String?, List<String>>{};
  for (final n in sorted) {
    final key = known.contains(n.groupId) ? n.groupId : null;
    (byGroupId[key] ??= []).add(n.id);
  }
  return [
    for (final g in groups)
      if (byGroupId[g.id] case final ids?) MonitoringSection(g, ids),
    if (byGroupId[null] case final ids?) MonitoringSection(null, ids),
  ];
}
