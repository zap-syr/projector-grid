/// The desktop Monitoring table's column catalogue (§7i.2 of the redesign
/// plan): the two-line columns shown by default, then the fields none of
/// them shows. The old single columns a two-line one replaces (Model, IP,
/// Input, Signal, the runtimes, the temperatures, Error codes) are gone, and
/// so is Preview, which the row's own Remote Preview button replaces. Serial
/// number went too: the projector panel's header shows it.
///
/// Separate from `monitoring_columns.dart`, which is the Web UI's catalogue
/// (sent in `/api/config`): the two-line columns exist on the desktop only,
/// so the Web UI never receives an id it can't render.
library;

class MonitoringTableColumn {
  final String id;
  final String label;
  final double defaultWidth;

  const MonitoringTableColumn(this.id, this.label, this.defaultWidth);
}

/// Every column, in canonical order: the default ones first, the extra
/// fields after them.
const List<MonitoringTableColumn> kMonitoringTableColumns = [
  MonitoringTableColumn('projector', 'Projector', 190),
  MonitoringTableColumn('group', 'Group', 150),
  MonitoringTableColumn('power', 'Power', 120),
  MonitoringTableColumn('shutter', 'Shutter', 110),
  MonitoringTableColumn('inputSignal', 'Input, signal', 180),
  MonitoringTableColumn('temperature', 'Temperature', 150),
  MonitoringTableColumn('runtimes', 'Runtime', 130),
  MonitoringTableColumn('voltage', 'AC', 80),
  MonitoringTableColumn('errors', 'Errors', 160),
  MonitoringTableColumn('connection', 'Connection', 130),
  MonitoringTableColumn('testPattern', 'Test pattern', 160),
];

/// The nine columns of the redesign. Group shows only with *Group by: none*;
/// grouped, the group rows say it.
const List<String> kMonitoringTableDefaultColumns = [
  'projector',
  'group',
  'power',
  'shutter',
  'inputSignal',
  'temperature',
  'runtimes',
  'voltage',
  'errors',
];

/// Named presets for the Columns menu (*Show all* is every column).
const Map<String, List<String>> kMonitoringTablePresets = {
  'Default': kMonitoringTableDefaultColumns,
  'Essentials': ['projector', 'group', 'power', 'shutter', 'errors'],
  'Thermal': [
    'projector',
    'group',
    'temperature',
    'runtimes',
    'voltage',
    'errors',
  ],
  'Signal': ['projector', 'group', 'power', 'shutter', 'inputSignal'],
};

/// Floor for auto-fit and manual column resize.
const double kMonitoringTableMinColumnWidth = 60;

/// The right-hand cell with the row actions (Remote Preview, ⋮): not a
/// column of the chooser, never resized.
const double kMonitoringActionsWidth = 76;

MonitoringTableColumn? monitoringTableColumn(String id) {
  for (final c in kMonitoringTableColumns) {
    if (c.id == id) return c;
  }
  return null;
}

/// The visible columns (ordered) for a saved id list: empty or all-unknown
/// means the default set, unknown ids are dropped.
List<String> resolveMonitoringTableColumns(List<String> saved) {
  final known = [
    for (final id in saved)
      if (monitoringTableColumn(id) != null) id,
  ];
  return known.isEmpty ? List.of(kMonitoringTableDefaultColumns) : known;
}

/// [saved] with [id] shown or hidden. Shown again, a column goes back to its
/// canonical place among the visible ones. Null when it would hide the last
/// column.
List<String>? toggleMonitoringTableColumn(List<String> saved, String id) {
  final visible = resolveMonitoringTableColumns(saved);
  if (visible.contains(id)) {
    if (visible.length == 1) return null;
    return [
      for (final c in visible)
        if (c != id) c,
    ];
  }
  final rank = _rank(id);
  final next = List.of(visible);
  var insertAt = next.length;
  for (var i = 0; i < next.length; i++) {
    if (_rank(next[i]) > rank) {
      insertAt = i;
      break;
    }
  }
  next.insert(insertAt, id);
  return next;
}

int _rank(String id) => kMonitoringTableColumns.indexWhere((c) => c.id == id);

/// [ids] with [dragged] moved to [target]'s place: after it when dragged
/// rightwards, before it when dragged leftwards. Unchanged when either is
/// missing.
List<String> reorderMonitoringTableColumn(
  List<String> ids,
  String dragged,
  String target,
) {
  final from = ids.indexOf(dragged);
  final to = ids.indexOf(target);
  if (from < 0 || to < 0 || from == to) return ids;
  // `to` from the list before the removal, or a left-to-right drop would
  // land the column back where it started.
  return List.of(ids)
    ..removeAt(from)
    ..insert(to, dragged);
}
