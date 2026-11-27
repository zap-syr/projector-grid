import 'dart:math' as math;
import 'dart:typed_data';

/// Table geometry of one projector model: the panel the control points live
/// on and the dense table the projector stores.
///
/// Node (c, r) of the table sits nominally at (c * stepX, r * stepY). The
/// table reaches past the panel, so nodes beyond [lastInsideColumn] or
/// [lastInsideRow] are outside it.
class WarpGeometry {
  const WarpGeometry({
    required this.panelWidth,
    required this.panelHeight,
    required this.columns,
    required this.rows,
    required this.stepX,
    required this.stepY,
  });

  final int panelWidth;
  final int panelHeight;

  /// Number of table nodes per row and per column.
  final int columns;
  final int rows;

  /// Nominal distance between table nodes, in panel pixels.
  final int stepX;
  final int stepY;

  /// The last table column at or left of the panel edge. A table that is
  /// shorter than the panel ends the inside area at its own last column.
  int get lastInsideColumn => math.min(panelWidth ~/ stepX, columns - 1);

  int get lastInsideRow => math.min(panelHeight ~/ stepY, rows - 1);
}

/// One plane of a table: x and y of every node, row-major, interleaved.
///
/// Treat the points as immutable once the plane is built; functions that
/// change a table return a new plane.
class WarpPlane {
  WarpPlane({
    required this.name,
    required this.columns,
    required this.rows,
    required this.points,
  }) : assert(
         points.length == columns * rows * 2,
         'points must hold x and y for every node',
       );

  /// Builds a plane by asking [point] for every node.
  factory WarpPlane.generate({
    required String name,
    required int columns,
    required int rows,
    required (double, double) Function(int column, int row) point,
  }) {
    final points = Float64List(columns * rows * 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final (x, y) = point(c, r);
        points[(r * columns + c) * 2] = x;
        points[(r * columns + c) * 2 + 1] = y;
      }
    }
    return WarpPlane(name: name, columns: columns, rows: rows, points: points);
  }

  /// "W" for a table with one plane for all colours, "R", "G" or "B" for a
  /// table with one plane per colour.
  final String name;
  final int columns;
  final int rows;
  final Float64List points;

  double x(int column, int row) => points[(row * columns + column) * 2];

  double y(int column, int row) => points[(row * columns + column) * 2 + 1];
}

/// A table as the projector stores it: the node counts, the header block and
/// one plane (all colours) or three (R, G, B).
class WarpTable {
  const WarpTable({
    required this.columns,
    required this.rows,
    required this.header,
    required this.planes,
  });

  final int columns;
  final int rows;

  /// The header block, kept exactly as it was read: its fields are not
  /// understood, so a table that goes back to the projector carries the
  /// header that came from it.
  final Uint8List header;
  final List<WarpPlane> planes;
}

/// Header length for a table with [planes] planes: 20 groups of one 16-bit
/// word per plane, plus one trailing byte.
int warpHeaderLength(int planes) => planes == 1 ? 41 : 121;

/// Last header byte of a full table (the table stored to a memory).
const int warpHeaderLastFull = 0x21;

/// Last header byte of an FPGA (delta) table.
const int warpHeaderLastFpga = 0xA1;

/// The header that Panasonic's software writes for a table it creates:
/// group 0 is 20, group 15 is 100, group 17 is 1, the rest are 0. The
/// meaning of the fields is unknown, so prefer the header read from the
/// projector whenever there is one.
Uint8List defaultWarpHeader(int planes, {int last = warpHeaderLastFull}) {
  assert(planes == 1 || planes == 3, 'a table has one or three planes');
  final words = List<int>.filled(20 * planes, 0);
  void group(int index, int value) {
    for (var c = 0; c < planes; c++) {
      words[index * planes + c] = value;
    }
  }

  group(0, 20);
  group(15, 100);
  group(17, 1);
  final out = Uint8List(words.length * 2 + 1);
  final data = ByteData.sublistView(out);
  for (var i = 0; i < words.length; i++) {
    data.setUint16(i * 2, words[i], Endian.little);
  }
  out[out.length - 1] = last;
  return out;
}

/// [header] with its last byte replaced; the input is not modified.
Uint8List warpHeaderWithLast(Uint8List header, int last) {
  final out = Uint8List.fromList(header);
  out[out.length - 1] = last;
  return out;
}

/// A table with every node at its nominal position: no correction.
WarpTable identityWarpTable(
  WarpGeometry geometry, {
  int planes = 1,
  int headerLast = warpHeaderLastFull,
}) {
  const colours = ['R', 'G', 'B'];
  return WarpTable(
    columns: geometry.columns,
    rows: geometry.rows,
    header: defaultWarpHeader(planes, last: headerLast),
    planes: [
      for (var p = 0; p < planes; p++)
        WarpPlane.generate(
          name: planes == 1 ? 'W' : colours[p],
          columns: geometry.columns,
          rows: geometry.rows,
          point: (c, r) => (
            (c * geometry.stepX).toDouble(),
            (r * geometry.stepY).toDouble(),
          ),
        ),
    ],
  );
}

/// The FPGA table of a full table: unchanged inside the panel, and outside
/// it the value of the nearest inside node plus the overshoot in pixels.
/// Panasonic's software sends exactly this next to every stored table.
WarpPlane fpgaPlaneFromFull(WarpPlane full, WarpGeometry geometry) {
  final lastColumn = geometry.lastInsideColumn;
  final lastRow = geometry.lastInsideRow;
  final out = Float64List(full.points.length);
  for (var r = 0; r < full.rows; r++) {
    for (var c = 0; c < full.columns; c++) {
      final i = (r * full.columns + c) * 2;
      if (c <= lastColumn && r <= lastRow) {
        out[i] = full.points[i];
        out[i + 1] = full.points[i + 1];
        continue;
      }
      final cc = math.min(c, lastColumn);
      final rr = math.min(r, lastRow);
      out[i] = full.x(cc, rr) + (c - cc) * geometry.stepX;
      out[i + 1] = full.y(cc, rr) + (r - rr) * geometry.stepY;
    }
  }
  return WarpPlane(
    name: full.name,
    columns: full.columns,
    rows: full.rows,
    points: out,
  );
}

/// [fpgaPlaneFromFull] for every plane, with the header ending in the FPGA
/// marker. Everything else in the header is kept as it was read.
WarpTable fpgaTableFromFull(WarpTable full, WarpGeometry geometry) => WarpTable(
  columns: full.columns,
  rows: full.rows,
  header: warpHeaderWithLast(full.header, warpHeaderLastFpga),
  planes: [for (final p in full.planes) fpgaPlaneFromFull(p, geometry)],
);

/// Bilinear sample of [plane] at panel position (x, y). This is what the
/// vendor software shows for a control point after a reload: the table
/// sampled at the point's nominal position.
({double x, double y}) sampleWarpPlane(
  WarpPlane plane,
  double x,
  double y,
  WarpGeometry geometry,
) {
  final c = math.min(
    plane.columns - 2,
    math.max(0, (x / geometry.stepX).floor()),
  );
  final r = math.min(plane.rows - 2, math.max(0, (y / geometry.stepY).floor()));
  final u = x / geometry.stepX - c;
  final v = y / geometry.stepY - r;
  double f(double Function(int c, int r) at) =>
      (1 - u) * (1 - v) * at(c, r) +
      u * (1 - v) * at(c + 1, r) +
      (1 - u) * v * at(c, r + 1) +
      u * v * at(c + 1, r + 1);
  return (x: f(plane.x), y: f(plane.y));
}
