/// Corner Correction: the four corners, their protocol limits per Quad Pixel
/// Drive tier, and the mapping between protocol values and the logical
/// 480×300 canvas the dialog draws them on.
library;

import 'dart:ui' show Offset, Rect, Size;

import 'geometry_values.dart';

enum GeometryCorner {
  ul('Upper left', 'GMFI6', 'GMFI1', left: true, top: true),
  ur('Upper right', 'GMFI7', 'GMFI2', left: false, top: true),
  ll('Lower left', 'GMFI8', 'GMFI3', left: true, top: false),
  lr('Lower right', 'GMFI9', 'GMFI4', left: false, top: false);

  const GeometryCorner(
    this.label,
    this.hKey,
    this.vKey, {
    required this.left,
    required this.top,
  });

  final String label;

  /// Horizontal and vertical displacement registers.
  final String hKey;
  final String vKey;
  final bool left;
  final bool top;

  /// Positive H moves a left corner inward (right), a right corner outward.
  bool get inwardHPositive => left;

  /// Positive V moves a top corner inward (down), a bottom corner outward.
  bool get inwardVPositive => top;
}

typedef CornerRange = ({int min, int max});

CornerRange cornerRangeH(GeometryCorner c, {required bool extended}) {
  final inward = cornerInwardH(extended: extended);
  return c.inwardHPositive
      ? (min: -cornerOutwardH, max: inward)
      : (min: -inward, max: cornerOutwardH);
}

CornerRange cornerRangeV(GeometryCorner c, {required bool extended}) {
  final inward = cornerInwardV(extended: extended);
  return c.inwardVPositive
      ? (min: -cornerOutwardV, max: inward)
      : (min: -inward, max: cornerOutwardV);
}

int clampCornerH(GeometryCorner c, int raw, {required bool extended}) {
  final r = cornerRangeH(c, extended: extended);
  return raw.clamp(r.min, r.max);
}

int clampCornerV(GeometryCorner c, int raw, {required bool extended}) {
  final r = cornerRangeV(c, extended: extended);
  return raw.clamp(r.min, r.max);
}

/// The logical canvas: the 1920×1200 panel is the 320×200 default frame at
/// [cornerCanvasScale], with room around it for the outward reach.
const cornerCanvasSize = Size(480, 300);

/// The uncorrected panel on the canvas.
const cornerDefaultFrame = Rect.fromLTRB(80, 50, 400, 250);

Offset cornerDefaultPosition(GeometryCorner c) => Offset(
  c.left ? cornerDefaultFrame.left : cornerDefaultFrame.right,
  c.top ? cornerDefaultFrame.top : cornerDefaultFrame.bottom,
);

/// Where a corner can be dragged, in canvas pixels. The same on every
/// model: Quad Pixel Drive doubles the inward protocol range because it
/// doubles the addressing resolution, not the reach (see [cornerToCanvas]).
Rect cornerBounds(GeometryCorner c) {
  // Outward 64 / 40 canvas pixels (384 / 240 raw), inward 80 / 50.
  final d = cornerDefaultPosition(c);
  final left = c.left ? d.dx - 64 : d.dx - 80;
  final right = c.left ? d.dx + 80 : d.dx + 64;
  final top = c.top ? d.dy - 40 : d.dy - 50;
  final bottom = c.top ? d.dy + 50 : d.dy + 40;
  return Rect.fromLTRB(left, top, right, bottom);
}

/// The union of every corner's reach: the dashed outer limit.
final Rect cornerOuterLimit = Rect.fromLTRB(
  cornerBounds(GeometryCorner.ul).left,
  cornerBounds(GeometryCorner.ul).top,
  cornerBounds(GeometryCorner.lr).right,
  cornerBounds(GeometryCorner.lr).bottom,
);

/// Canvas position of [c] at raw displacement [h], [v].
Offset cornerCanvasPosition(
  GeometryCorner c,
  int h,
  int v, {
  required bool extended,
}) {
  final d = cornerDefaultPosition(c);
  return Offset(
    d.dx +
        cornerToCanvas(
          h,
          inwardIsPositive: c.inwardHPositive,
          extended: extended,
        ),
    d.dy +
        cornerToCanvas(
          v,
          inwardIsPositive: c.inwardVPositive,
          extended: extended,
        ),
  );
}

/// Raw `(h, v)` for [c] dragged to [position], held inside its bounds and
/// its protocol range.
(int, int) cornerRawFromCanvas(
  GeometryCorner c,
  Offset position, {
  required bool extended,
}) {
  final bounds = cornerBounds(c);
  final d = cornerDefaultPosition(c);
  final dx = position.dx.clamp(bounds.left, bounds.right) - d.dx;
  final dy = position.dy.clamp(bounds.top, bounds.bottom) - d.dy;
  return (
    clampCornerH(
      c,
      cornerToRaw(dx, inwardIsPositive: c.inwardHPositive, extended: extended),
      extended: extended,
    ),
    clampCornerV(
      c,
      cornerToRaw(dy, inwardIsPositive: c.inwardVPositive, extended: extended),
      extended: extended,
    ),
  );
}

/// The canvas header pill: the corner's name, `2 selected`, or null.
String? cornerSelectionLabel(Set<GeometryCorner> selected) =>
    switch (selected.length) {
      0 => null,
      1 => selected.single.label,
      final n => '$n selected',
    };
