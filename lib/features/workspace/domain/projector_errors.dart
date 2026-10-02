/// Decoding of the `QVX:ERRS2` self-diagnosis reply as stored in
/// `ProjectorNode.errors` (see `formatErrors`).
library;

import 'alert_rule.dart';

/// One error the projector reports. [id] is stable across polls, so the same
/// error keeps the same alert; [label] is what the operator reads.
typedef ProjectorErrorItem = ({
  String id,
  String label,
  AlertSeverity severity,
});

typedef _CodeRange = ({
  String from,
  String to,
  String label,
  AlertSeverity severity,
});

const _w = AlertSeverity.warning;
const _c = AlertSeverity.critical;

/// Error / warning codes from the PT-RQ35K operating instructions. Exact
/// codes come before the ranges that contain them (U355 inside U302–U358),
/// since the first match wins.
const List<_CodeRange> _codes = [
  (
    from: 'U081',
    to: 'U081',
    label: 'Low AC voltage warning (below 90 V)',
    severity: _w,
  ),
  (from: 'U084', to: 'U084', label: 'USB power supply error', severity: _c),
  (
    from: 'U090',
    to: 'U090',
    label: 'Projection lens not attached',
    severity: _c,
  ),
  (
    from: 'U200',
    to: 'U200',
    label: 'Intake air temperature warning',
    severity: _w,
  ),
  (
    from: 'U201',
    to: 'U201',
    label: 'Exhaust air temperature warning',
    severity: _w,
  ),
  (
    from: 'U255',
    to: 'U255',
    label: 'AC IN terminal high temperature warning',
    severity: _w,
  ),
  (
    from: 'U202',
    to: 'U254',
    label: 'Other high temperature warning',
    severity: _w,
  ),
  (from: 'U280', to: 'U280', label: 'Low temperature warning', severity: _w),
  (
    from: 'U300',
    to: 'U300',
    label: 'Intake air temperature error',
    severity: _c,
  ),
  (
    from: 'U301',
    to: 'U301',
    label: 'Exhaust air temperature error',
    severity: _c,
  ),
  (
    from: 'U355',
    to: 'U355',
    label: 'AC IN terminal high temperature error',
    severity: _c,
  ),
  (from: 'U356', to: 'U356', label: 'Peltier temperature error', severity: _c),
  (
    from: 'U302',
    to: 'U358',
    label: 'Other high temperature error',
    severity: _c,
  ),
  (from: 'U380', to: 'U380', label: 'Low temperature error', severity: _c),
  (from: 'F011', to: 'F011', label: 'Shutter error', severity: _c),
  (from: 'F015', to: 'F015', label: 'Luminance sensor error', severity: _c),
  (
    from: 'F061',
    to: 'F066',
    label: 'Light source driver communication error',
    severity: _c,
  ),
  (from: 'F096', to: 'F096', label: 'Lens mounter error', severity: _c),
  (from: 'F098', to: 'F098', label: 'Lens EEPROM error', severity: _c),
  (from: 'F110', to: 'F111', label: 'Phosphor wheel error', severity: _c),
  (from: 'F400', to: 'F461', label: 'Light source error', severity: _c),
  (from: 'F200', to: 'F228', label: 'Fan warning', severity: _w),
  (
    from: 'F250',
    to: 'F259',
    label: 'Liquid cooling pump fan error',
    severity: _c,
  ),
  (from: 'F300', to: 'F328', label: 'Fan error', severity: _c),
  (from: 'F380', to: 'F381', label: 'Peltier driver error', severity: _c),
  (
    from: 'H001',
    to: 'H001',
    label: 'Replace the internal clock battery',
    severity: _w,
  ),
  (from: 'H011', to: 'H028', label: 'Temperature sensor error', severity: _c),
];

final _codePattern = RegExp(r'[A-Z]\d{3}');

/// Every error in [errors], in reply order; empty when healthy or unknown.
///
/// Known codes get the label and severity from the table, with the code in
/// the label so two errors of one range stay apart. A reply without any code
/// in it, or a code the table doesn't know, comes through as the projector
/// sent it, as a critical error.
List<ProjectorErrorItem> decodeProjectorErrors(String errors) {
  final value = errors.trim();
  if (value == 'NO ERRORS' || value == '-' || RegExp(r'^0*$').hasMatch(value)) {
    return const [];
  }
  final codes = {for (final m in _codePattern.allMatches(value)) m.group(0)!};
  if (codes.isEmpty) return [(id: value, label: value, severity: _c)];
  return [
    for (final code in codes)
      if (_lookup(code) case final known?)
        (id: code, label: '${known.label} ($code)', severity: known.severity)
      else
        (id: code, label: code, severity: _c),
  ];
}

_CodeRange? _lookup(String code) => _codes
    .where(
      (r) =>
          code[0] == r.from[0] &&
          code.compareTo(r.from) >= 0 &&
          code.compareTo(r.to) <= 0,
    )
    .firstOrNull;
