import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../../domain/geometry_corners.dart';

/// Degrees go out with one decimal; slider positions drift otherwise.
double roundDegrees(double v) => double.parse(v.toStringAsFixed(1));

/// Keystone registers as last read or set. The dialog rebuilds on each
/// change, so the preview follows the sliders.
class KeystoneSettings {
  double throwRatio = 1.5; // GMKS0
  int verticalBalance = 0; // GMKI4
  int horizontalBalance = 0; // GMKI7
  double vertical = 0; // GMKS8
  double horizontal = 0; // GMKS9

  /// What Reset writes (keystoneResetRegisters); the throw ratio stays.
  void resetCorrection() {
    vertical = 0;
    horizontal = 0;
    verticalBalance = 0;
    horizontalBalance = 0;
  }
}

/// Curved Correction registers as last read or set.
class CurvedSettings {
  double throwRatio = 1.5; // GMCS0
  int verticalBalance = 0; // GMCI2
  int verticalArc = 0; // GMCI3
  int horizontalBalance = 0; // GMCI6
  int horizontalArc = 0; // GMCI7
  double vertical = 0; // GMCS8
  double horizontal = 0; // GMCS9
  bool keepAspect = false; // GMCIA

  /// What Reset writes (curvedResetRegisters); throw ratio and aspect stay.
  void resetCorrection() {
    verticalBalance = 0;
    verticalArc = 0;
    horizontalBalance = 0;
    horizontalArc = 0;
    vertical = 0;
    horizontal = 0;
  }
}

/// Corner Correction values and the corner selection, shared by the canvas
/// and the controls card. A listenable rather than dialog state: a drag
/// repaints the canvas and the corner fields many times a second, and the
/// rest of the dialog doesn't need to rebuild for it.
class CornerModel extends ChangeNotifier {
  /// Tier A: the wider inward range. Set once the model is known.
  bool extended = false;

  final Map<GeometryCorner, int> _h = {
    for (final c in GeometryCorner.values) c: 0,
  };
  final Map<GeometryCorner, int> _v = {
    for (final c in GeometryCorner.values) c: 0,
  };

  /// Linearity (GMFI5, GMFIA) and Pincushion (GMFIB to GMFIE).
  final Map<String, int> _shape = {for (final k in shapeKeys) k: 0};
  bool _manual = false; // GMFIF

  final Set<GeometryCorner> _selected = {};

  static const shapeKeys = [
    'GMFI5',
    'GMFIA',
    'GMFIB',
    'GMFIC',
    'GMFID',
    'GMFIE',
  ];

  int h(GeometryCorner c) => _h[c]!;
  int v(GeometryCorner c) => _v[c]!;
  int shape(String key) => _shape[key]!;
  bool get manual => _manual;
  Set<GeometryCorner> get selected => Set.unmodifiable(_selected);
  bool isSelected(GeometryCorner c) => _selected.contains(c);
  bool isMoved(GeometryCorner c) => _h[c] != 0 || _v[c] != 0;

  Offset positionOf(GeometryCorner c) =>
      cornerCanvasPosition(c, _h[c]!, _v[c]!, extended: extended);

  /// The `GMFI` pair that sends [c]'s position, H first.
  List<(String, int)> commandsFor(GeometryCorner c) => [
    (c.hKey, _h[c]!),
    (c.vKey, _v[c]!),
  ];

  List<(String, int)> commandsForSelected() => [
    for (final c in GeometryCorner.values)
      if (_selected.contains(c)) ...commandsFor(c),
  ];

  /// Values from a load: raw register → value.
  void load(Map<String, int> values) {
    for (final c in GeometryCorner.values) {
      _h[c] = values[c.hKey] ?? 0;
      _v[c] = values[c.vKey] ?? 0;
    }
    for (final k in shapeKeys) {
      _shape[k] = values[k] ?? 0;
    }
    _manual = (values['GMFIF'] ?? 0) == 1;
    notifyListeners();
  }

  void setRaw(GeometryCorner c, {int? h, int? v}) {
    if (h != null) _h[c] = clampCornerH(c, h, extended: extended);
    if (v != null) _v[c] = clampCornerV(c, v, extended: extended);
    notifyListeners();
  }

  /// Moves every corner in [starts] to its start plus [delta] (canvas
  /// pixels), each held inside its own bounds.
  void dragFrom(Map<GeometryCorner, Offset> starts, Offset delta) {
    for (final MapEntry(key: c, value: start) in starts.entries) {
      final (h, v) = cornerRawFromCanvas(c, start + delta, extended: extended);
      _h[c] = h;
      _v[c] = v;
    }
    notifyListeners();
  }

  /// One raw unit per arrow key for every selected corner. Raising H moves
  /// any corner right and raising V moves it down, so one signed pair works
  /// for all four, also on the doubled inward scale of Tier A.
  void step(int dh, int dv) {
    for (final c in _selected) {
      _h[c] = clampCornerH(c, _h[c]! + dh, extended: extended);
      _v[c] = clampCornerV(c, _v[c]! + dv, extended: extended);
    }
    notifyListeners();
  }

  void resetCorner(GeometryCorner c) => setRaw(c, h: 0, v: 0);

  void resetAllCorners() {
    for (final c in GeometryCorner.values) {
      _h[c] = 0;
      _v[c] = 0;
    }
    notifyListeners();
  }

  void setShape(String key, int value) {
    _shape[key] = value;
    notifyListeners();
  }

  set manual(bool value) {
    _manual = value;
    notifyListeners();
  }

  /// [additive] (Ctrl, Cmd or Shift held) toggles [c]; otherwise it becomes
  /// the only selected corner.
  void select(GeometryCorner c, {required bool additive}) {
    if (additive) {
      if (!_selected.add(c)) _selected.remove(c);
    } else {
      _selected
        ..clear()
        ..add(c);
    }
    notifyListeners();
  }

  /// Adds [c] without toggling (a drag that starts on it).
  void include(GeometryCorner c, {required bool additive}) {
    if (_selected.contains(c)) return;
    if (!additive) _selected.clear();
    _selected.add(c);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
