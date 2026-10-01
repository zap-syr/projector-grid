/// The Monitoring table's column catalogue: ids, labels, default widths,
/// canonical order, the default visible set and the presets. Read by the
/// Flutter table and by the Web UI (via `/api/config`) so the two can't drift;
/// how a cell renders stays per side, keyed by [MonitoringColumnSpec.id].
library;

class MonitoringColumnSpec {
  final String id;
  final String label;
  final double defaultWidth;

  const MonitoringColumnSpec(this.id, this.label, this.defaultWidth);
}

const kColConnection = MonitoringColumnSpec('connection', 'Connection', 130);
const kColModel = MonitoringColumnSpec('model', 'Model', 160);
const kColSerial = MonitoringColumnSpec('serial', 'Serial Number', 160);

/// A button per row that opens Remote Preview; not sortable.
const kColPreview = MonitoringColumnSpec('preview', 'Preview', 92);
const kColGroup = MonitoringColumnSpec('group', 'Group', 150);
const kColIp = MonitoringColumnSpec('ip', 'IP Address', 130);
const kColPower = MonitoringColumnSpec('power', 'Power', 130);
const kColShutter = MonitoringColumnSpec('shutter', 'Shutter', 110);
const kColInput = MonitoringColumnSpec('input', 'Input', 90);
const kColSignal = MonitoringColumnSpec('signal', 'Signal', 140);
const kColTestPattern = MonitoringColumnSpec(
  'testPattern',
  'Test Pattern',
  170,
);
const kColRuntime = MonitoringColumnSpec('runtime', 'Projector Runtime', 150);
const kColLightRuntime = MonitoringColumnSpec(
  'lightRuntime',
  'Light Runtime',
  130,
);
const kColIntake = MonitoringColumnSpec('intake', 'Intake Temp', 130);
const kColExhaust = MonitoringColumnSpec('exhaust', 'Exhaust Temp', 150);
const kColVoltage = MonitoringColumnSpec('voltage', 'AC Voltage', 130);
const kColErrors = MonitoringColumnSpec('errors', 'Errors', 140);

/// Every column, in canonical order.
const List<MonitoringColumnSpec> kMonitoringColumns = [
  kColConnection,
  kColModel,
  kColSerial,
  kColPreview,
  kColGroup,
  kColIp,
  kColPower,
  kColShutter,
  kColInput,
  kColSignal,
  kColTestPattern,
  kColRuntime,
  kColLightRuntime,
  kColIntake,
  kColExhaust,
  kColVoltage,
  kColErrors,
];

/// Shown before the user customises anything: all but Group and Test Pattern.
const List<String> kMonitoringDefaultColumns = [
  'connection',
  'model',
  'serial',
  'preview',
  'ip',
  'power',
  'shutter',
  'input',
  'signal',
  'runtime',
  'lightRuntime',
  'intake',
  'exhaust',
  'voltage',
  'errors',
];

/// Named presets for the Columns menu (*Show all* is every column, not listed).
const Map<String, List<String>> kMonitoringPresets = {
  'Essentials': [
    'connection',
    'model',
    'ip',
    'power',
    'shutter',
    'input',
    'errors',
  ],
  'Thermal': [
    'connection',
    'model',
    'ip',
    'intake',
    'exhaust',
    'runtime',
    'voltage',
  ],
  'Signal': [
    'connection',
    'model',
    'ip',
    'input',
    'signal',
    'preview',
    'power',
    'shutter',
  ],
};

/// Floor for auto-fit and manual column resize.
const double kMonitoringMinColumnWidth = 60;

/// The visible columns (ordered) for a saved id list: empty or all-unknown
/// means the default set, unknown ids are dropped.
List<String> resolveMonitoringColumns(List<String> saved) {
  final ids = saved.isEmpty ? kMonitoringDefaultColumns : saved;
  final known = [
    for (final id in ids)
      if (kMonitoringColumns.any((c) => c.id == id)) id,
  ];
  return known.isEmpty ? List.of(kMonitoringDefaultColumns) : known;
}
