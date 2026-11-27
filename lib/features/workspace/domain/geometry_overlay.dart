import 'dart:typed_data';

import 'warp_codec.dart';

// Frames that make the projector show where the control points are: a cursor
// on the selected point, a grid through all points and a highlight on the
// selected ones. They only build bytes; sending them is up to the caller.

/// DISPLAY CURSOR: shows the cursor at the panel position ([x], [y]) in
/// integer pixels, or hides it. The app sends the current position of the
/// selected control point and kind 0. Coordinates are 16 bit
/// big-endian, a negative one is sent as two's complement.
Uint8List buildCursorFrame({
  required bool on,
  required int x,
  required int y,
  int kind = 0,
}) => Uint8List.fromList([
  0x02,
  0x00,
  0xAC,
  0x07,
  on ? 1 : 0,
  (x >> 8) & 0xFF,
  x & 0xFF,
  (y >> 8) & 0xFF,
  y & 0xFF,
  kind & 0xFF,
  0x03,
]);

/// DISPLAY GRID: shows a grid through the control points ([columns] by
/// [rows] points) in the colour [rgb] (0xRRGGBB), or hides it.
Uint8List buildGridOverlayFrame({
  required bool on,
  required int columns,
  required int rows,
  required int rgb,
}) => Uint8List.fromList([
  0x02,
  0x00,
  0xAB,
  0x07,
  on ? 1 : 0,
  columns,
  rows,
  (rgb >> 16) & 0xFF,
  (rgb >> 8) & 0xFF,
  rgb & 0xFF,
  0x03,
]);

/// The marks of [count] control points, row-major: [value] for the indexes in
/// [selected], 0 for the rest.
List<int> gridPointMarks(int count, Iterable<int> selected, {int value = 1}) {
  final marks = List<int>.filled(count, 0);
  for (final i in selected) {
    marks[i] = value;
  }
  return marks;
}

/// Two bits per control point, packed the way the projector expects: the
/// first byte holds points 0 to 2, every further byte four points.
Uint8List packGridPointMarks(List<int> marks) {
  final n = marks.length;
  final length = (n + 4) ~/ 4;
  int v(int i) => i < n ? marks[i] & 3 : 0;
  final out = Uint8List(length);
  out[0] = (v(0) << 4) | (v(1) << 2) | v(2);
  for (var k = 1; k < length; k++) {
    out[k] =
        (v(4 * k - 1) << 6) |
        (v(4 * k) << 4) |
        (v(4 * k + 1) << 2) |
        v(4 * k + 2);
  }
  return out;
}

/// WRITE GRID POINT (type 0x90): highlights the control points whose mark is
/// 1. Send the cursor frame first, then this one.
Uint8List buildGridPointMarksFrame(List<int> marks) =>
    buildWriteFrame(0x90, 0x00, 3, packGridPointMarks(marks));
