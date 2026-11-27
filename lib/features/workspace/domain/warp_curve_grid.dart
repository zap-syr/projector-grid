import 'dart:typed_data';

import 'warp_control_grid.dart';
import 'warp_table.dart';

/// The two handles of a curved edge, relative to the edge's own end points:
/// [h1x], [h1y] belong to the first point (left or top), [h2x], [h2y] to the
/// second. The edge is the cubic Bezier P0, P0 + h1, P1 + h2, P1. Moving a
/// point moves its handles with it. The projector never receives the handles;
/// only the dense table they produce.
class WarpEdgeCurve {
  const WarpEdgeCurve({
    required this.h1x,
    required this.h1y,
    required this.h2x,
    required this.h2y,
  });

  final double h1x;
  final double h1y;
  final double h2x;
  final double h2y;

  @override
  bool operator ==(Object other) =>
      other is WarpEdgeCurve &&
      other.h1x == h1x &&
      other.h1y == h1y &&
      other.h2x == h2x &&
      other.h2y == h2y;

  @override
  int get hashCode => Object.hash(h1x, h1y, h2x, h2y);

  @override
  String toString() => 'WarpEdgeCurve(($h1x, $h1y), ($h2x, $h2y))';
}

/// The edges between neighbouring control points. [hor] has one list per
/// grid row, each with `columns - 1` edges running left to right; [ver] has
/// `rows - 1` lists of `columns` edges running top to bottom. A null edge is
/// straight.
class WarpCurves {
  const WarpCurves({required this.hor, required this.ver});

  /// All edges straight.
  factory WarpCurves.straight(int columns, int rows) => WarpCurves(
    hor: [
      for (var j = 0; j < rows; j++)
        List<WarpEdgeCurve?>.filled(columns - 1, null),
    ],
    ver: [
      for (var j = 0; j < rows - 1; j++)
        List<WarpEdgeCurve?>.filled(columns, null),
    ],
  );

  /// Every edge curved, with the default handles of an edge that is
  /// switched to a curve without being dragged: a third of the
  /// nominal cell along the edge. On a grid that has not been moved this
  /// leaves the image unchanged.
  factory WarpCurves.defaults(
    int columns,
    int rows,
    int panelWidth,
    int panelHeight,
  ) {
    final cw = panelWidth / (columns - 1) / 3;
    final ch = panelHeight / (rows - 1) / 3;
    final horizontal = WarpEdgeCurve(h1x: cw, h1y: 0, h2x: -cw, h2y: 0);
    final vertical = WarpEdgeCurve(h1x: 0, h1y: ch, h2x: 0, h2y: -ch);
    return WarpCurves(
      hor: [
        for (var j = 0; j < rows; j++)
          List<WarpEdgeCurve?>.filled(columns - 1, horizontal),
      ],
      ver: [
        for (var j = 0; j < rows - 1; j++)
          List<WarpEdgeCurve?>.filled(columns, vertical),
      ],
    );
  }

  final List<List<WarpEdgeCurve?>> hor;
  final List<List<WarpEdgeCurve?>> ver;

  /// How many edges are curved.
  int get curvedCount =>
      hor.fold(0, (n, row) => n + row.where((e) => e != null).length) +
      ver.fold(0, (n, row) => n + row.where((e) => e != null).length);

  /// A copy with one edge replaced: [vertical] edges run from the point at
  /// ([column], [row]) down to the one below, the others to the one on the
  /// right.
  WarpCurves withEdge({
    required bool vertical,
    required int row,
    required int column,
    required WarpEdgeCurve? curve,
  }) {
    List<List<WarpEdgeCurve?>> copy(List<List<WarpEdgeCurve?>> source) => [
      for (final r in source) [...r],
    ];
    final newHor = copy(hor);
    final newVer = copy(ver);
    (vertical ? newVer : newHor)[row][column] = curve;
    return WarpCurves(hor: newHor, ver: newVer);
  }
}

/// A control grid with its curved edges.
class WarpCurveGrid {
  const WarpCurveGrid({required this.grid, required this.curves});

  final WarpControlGrid grid;
  final WarpCurves curves;
}

// ------------------------------------------------------------ the engine

/// Round half away from zero to a multiple of 1/[k]: the rounding of the
/// engine's edge samples (1/64 px) and cell fill (1/256 px).
double _roundTo(double v, int k) {
  var l = (v * k * 2).truncate();
  l += l < 0 ? -1 : 1;
  return (l ~/ 2) / k;
}

/// The positions along an edge from [a] to [b] (in table-node units, possibly
/// fractional) at which the dense table has a node: the edge parameter t for
/// every table line it crosses, from 0 at [a] to 1 at [b].
List<double> edgeParams(double a, double b) {
  final t = <double>[0];
  for (var k = 1; ; k++) {
    final u = k + a.truncate();
    if (u >= b) {
      t.add(1);
      return t;
    }
    t.add((u - a) / (b - a));
  }
}

class _EdgeSamples {
  _EdgeSamples(int length) : x = Float64List(length), y = Float64List(length);

  final Float64List x;
  final Float64List y;
}

_EdgeSamples _edgeSamples(
  double p0x,
  double p0y,
  double p1x,
  double p1y,
  WarpEdgeCurve? curve,
  List<double> t,
) {
  final out = _EdgeSamples(t.length);
  for (var k = 0; k < t.length; k++) {
    final tt = t[k];
    final s = 1 - tt;
    if (curve == null) {
      out.x[k] = _roundTo(tt * p1x + s * p0x, 64);
      out.y[k] = _roundTo(p0y * s + p1y * tt, 64);
      continue;
    }
    final b0 = s * s * s;
    final b1 = 3 * s * s * tt;
    final b2 = 3 * tt * s * tt;
    final b3 = tt * tt * tt;
    out.x[k] = _roundTo(
      b1 * (p0x + curve.h1x) + b0 * p0x + b2 * (p1x + curve.h2x) + b3 * p1x,
      64,
    );
    out.y[k] = _roundTo(
      b1 * (p0y + curve.h1y) + b0 * p0y + b2 * (p1y + curve.h2y) + b3 * p1y,
      64,
    );
  }
  return out;
}

/// The dense table of a curve grid: each edge is sampled where it crosses a table line and rounded to
/// 1/64 px, then every cell is filled from its four edges and rounded to
/// 1/256 px. Nodes outside the panel stay on the nominal lattice. With four
/// straight edges per cell this is bilinear interpolation apart from the
/// rounding.
WarpPlane curveEngineDense(WarpCurveGrid curveGrid, WarpGeometry geometry) {
  final grid = curveGrid.grid;
  final curves = curveGrid.curves;
  final h = grid.columns;
  final v = grid.rows;
  final gx = geometry.columns;
  final gy = geometry.rows;
  final nx = grid.panelWidth / geometry.stepX;
  final ny = grid.panelHeight / geometry.stepY;
  double nomX(int i) => (nx * i) / (h - 1);
  double nomY(int j) => (ny * j) / (v - 1);

  final out = Float64List(gx * gy * 2);
  for (var r = 0; r < gy; r++) {
    for (var c = 0; c < gx; c++) {
      out[(r * gx + c) * 2] = (c * geometry.stepX).toDouble();
      out[(r * gx + c) * 2 + 1] = (r * geometry.stepY).toDouble();
    }
  }

  _EdgeSamples hor(int j, int i) {
    final a = grid.index(i, j);
    final b = grid.index(i + 1, j);
    return _edgeSamples(
      grid.xAt(a),
      grid.yAt(a),
      grid.xAt(b),
      grid.yAt(b),
      curves.hor[j][i],
      edgeParams(nomX(i), nomX(i + 1)),
    );
  }

  _EdgeSamples ver(int j, int i) {
    final a = grid.index(i, j);
    final b = grid.index(i, j + 1);
    return _edgeSamples(
      grid.xAt(a),
      grid.yAt(a),
      grid.xAt(b),
      grid.yAt(b),
      curves.ver[j][i],
      edgeParams(nomY(j), nomY(j + 1)),
    );
  }

  for (var j = 0; j < v - 1; j++) {
    for (var i = 0; i < h - 1; i++) {
      final a = hor(j, i);
      final b = hor(j + 1, i);
      final l = ver(j, i);
      final r = ver(j, i + 1);
      final tu = edgeParams(nomX(i), nomX(i + 1));
      final tv = edgeParams(nomY(j), nomY(j + 1));
      final nu = tu.length - 1;
      final nv = tv.length - 1;
      for (var k = 0; k < tv.length; k++) {
        final iy = (k + nomY(j)).truncate();
        if (iy < nomY(j) || iy > nomY(j + 1) || iy >= gy) continue;
        for (var m = 0; m < tu.length; m++) {
          final ix = (m + nomX(i)).truncate();
          if (ix < nomX(i) || ix > nomX(i + 1) || ix >= gx) continue;
          final u = tu[m];
          final w = tv[k];
          final y0 = (r.y[0] - l.y[0]) * u + l.y[0];
          final y1 = (r.y[nv] - l.y[nv]) * u + l.y[nv];
          final vv = y1 == y0
              ? 1.0
              : ((r.y[k] - l.y[k]) * u + l.y[k] - y0) / (y1 - y0);
          final x0 = (b.x[0] - a.x[0]) * w + a.x[0];
          final x1 = (b.x[nu] - a.x[nu]) * w + a.x[nu];
          final uu = x1 == x0
              ? 1.0
              : ((b.x[m] - a.x[m]) * w + a.x[m] - x0) / (x1 - x0);
          out[(iy * gx + ix) * 2] = _roundTo(
            (r.x[k] - l.x[k]) * uu + l.x[k],
            256,
          );
          out[(iy * gx + ix) * 2 + 1] = _roundTo(
            (b.y[m] - a.y[m]) * vv + a.y[m],
            256,
          );
        }
      }
    }
  }
  return WarpPlane(name: 'W', columns: gx, rows: gy, points: out);
}

/// The table to write for [curveGrid]. Without curved edges this is the
/// bilinear table of [denseFromControl], with them the curve engine.
WarpPlane denseFromCurveGrid(WarpCurveGrid curveGrid, WarpGeometry geometry) =>
    curveGrid.curves.curvedCount == 0
    ? denseFromControl(curveGrid.grid, geometry)
    : curveEngineDense(curveGrid, geometry);

// ------------------------------------------------------- reading a table

WarpEdgeCurve? _fit(
  double p0x,
  double p0y,
  double p1x,
  double p1y,
  List<double> t,
  List<double> sx,
  List<double> sy,
) {
  // Linear least squares for the two handle components of one axis, with the
  // end points fixed. Returns [h1, h2].
  List<double> axis(double p0, double p1, List<double> samples) {
    var a11 = 0.0, a12 = 0.0, a22 = 0.0, b1 = 0.0, b2 = 0.0;
    for (var k = 0; k < t.length; k++) {
      final tt = t[k];
      final s = 1 - tt;
      final f1 = 3 * s * s * tt;
      final f2 = 3 * s * tt * tt;
      final rhs = samples[k] - (s * s * s + f1) * p0 - (f2 + tt * tt * tt) * p1;
      a11 += f1 * f1;
      a12 += f1 * f2;
      a22 += f2 * f2;
      b1 += f1 * rhs;
      b2 += f2 * rhs;
    }
    final det = a11 * a22 - a12 * a12;
    if (det.abs() < 1e-12) return [(p1 - p0) / 3, -(p1 - p0) / 3];
    return [(b1 * a22 - b2 * a12) / det, (a11 * b2 - a12 * b1) / det];
  }

  final hx = axis(p0x, p1x, sx);
  final hy = axis(p0y, p1y, sy);
  final straight =
      (hx[0] - (p1x - p0x) / 3).abs() < 0.05 &&
      (hx[1] + (p1x - p0x) / 3).abs() < 0.05 &&
      (hy[0] - (p1y - p0y) / 3).abs() < 0.05 &&
      (hy[1] + (p1y - p0y) / 3).abs() < 0.05;
  return straight
      ? null
      : WarpEdgeCurve(h1x: hx[0], h1y: hy[0], h2x: hx[1], h2y: hy[1]);
}

/// Fits the handles of every edge to the table [plane], with the edge end
/// points taken from [grid]. An edge between two table lines of the same
/// row or column (such as the middle row of a 3 x 3 grid) has no table nodes
/// along it and cannot be fitted: it is returned straight and counted in
/// `unrecoverable`.
({WarpCurves curves, int unrecoverable}) curvesFromDense(
  WarpPlane plane,
  WarpControlGrid grid,
  WarpGeometry geometry,
) {
  final h = grid.columns;
  final v = grid.rows;
  final nx = grid.panelWidth / geometry.stepX;
  final ny = grid.panelHeight / geometry.stepY;
  double nomX(int i) => (nx * i) / (h - 1);
  double nomY(int j) => (ny * j) / (v - 1);
  var unrecoverable = 0;

  final hor = <List<WarpEdgeCurve?>>[];
  for (var j = 0; j < v; j++) {
    final row = <WarpEdgeCurve?>[];
    for (var i = 0; i < h - 1; i++) {
      final y = nomY(j);
      if (y != y.truncate()) {
        row.add(null);
        unrecoverable++;
        continue;
      }
      final t = edgeParams(nomX(i), nomX(i + 1));
      final tt = <double>[];
      final sx = <double>[];
      final sy = <double>[];
      for (var k = 0; k < t.length; k++) {
        final c = (k + nomX(i)).truncate();
        if (c >= nomX(i) && c <= nomX(i + 1)) {
          tt.add(t[k]);
          sx.add(plane.x(c, y.truncate()));
          sy.add(plane.y(c, y.truncate()));
        }
      }
      final a = grid.index(i, j);
      final b = grid.index(i + 1, j);
      row.add(
        _fit(grid.xAt(a), grid.yAt(a), grid.xAt(b), grid.yAt(b), tt, sx, sy),
      );
    }
    hor.add(row);
  }

  final ver = <List<WarpEdgeCurve?>>[];
  for (var j = 0; j < v - 1; j++) {
    final row = <WarpEdgeCurve?>[];
    for (var i = 0; i < h; i++) {
      final x = nomX(i);
      if (x != x.truncate()) {
        row.add(null);
        unrecoverable++;
        continue;
      }
      final t = edgeParams(nomY(j), nomY(j + 1));
      final tt = <double>[];
      final sx = <double>[];
      final sy = <double>[];
      for (var k = 0; k < t.length; k++) {
        final r = (k + nomY(j)).truncate();
        if (r >= nomY(j) && r <= nomY(j + 1)) {
          tt.add(t[k]);
          sx.add(plane.x(x.truncate(), r));
          sy.add(plane.y(x.truncate(), r));
        }
      }
      final a = grid.index(i, j);
      final b = grid.index(i, j + 1);
      row.add(
        _fit(grid.xAt(a), grid.yAt(a), grid.xAt(b), grid.yAt(b), tt, sx, sy),
      );
    }
    ver.add(row);
  }
  return (curves: WarpCurves(hor: hor, ver: ver), unrecoverable: unrecoverable);
}

// ------------------------------------------------- editing a selection

/// Whether the toggle for a selection shows off, on or mixed.
enum WarpBezierState { off, on, mixed }

/// Calls [visit] for every edge that has at least one end in [selection]:
/// horizontal ones first, then vertical ones.
void _forSelectionEdges(
  WarpControlGrid grid,
  Set<int> selection,
  void Function(bool vertical, int row, int column) visit,
) {
  for (var j = 0; j < grid.rows; j++) {
    for (var i = 0; i < grid.columns - 1; i++) {
      if (selection.contains(grid.index(i, j)) ||
          selection.contains(grid.index(i + 1, j))) {
        visit(false, j, i);
      }
    }
  }
  for (var j = 0; j < grid.rows - 1; j++) {
    for (var i = 0; i < grid.columns; i++) {
      if (selection.contains(grid.index(i, j)) ||
          selection.contains(grid.index(i, j + 1))) {
        visit(true, j, i);
      }
    }
  }
}

/// Turns Bezier on or off for the edges that have at least one selected end.
/// Turning it on gives an edge that is straight the default handles
/// (a third of the nominal cell along the edge) and keeps the handles of an
/// edge that is already curved. Turning it off straightens the edges.
WarpCurveGrid setBezierOnSelection(
  WarpCurveGrid curveGrid,
  Set<int> selection, {
  required bool on,
}) {
  final grid = curveGrid.grid;
  final defaults = WarpCurves.defaults(
    grid.columns,
    grid.rows,
    grid.panelWidth,
    grid.panelHeight,
  );
  var curves = curveGrid.curves;
  _forSelectionEdges(grid, selection, (vertical, row, column) {
    final current = (vertical ? curves.ver : curves.hor)[row][column];
    final next = on
        ? (current ?? (vertical ? defaults.ver : defaults.hor)[row][column])
        : null;
    curves = curves.withEdge(
      vertical: vertical,
      row: row,
      column: column,
      curve: next,
    );
  });
  return WarpCurveGrid(grid: grid, curves: curves);
}

/// Off when none of the edges of the selection is curved, on when all of them
/// are, mixed otherwise. No selection (no edges) is off.
WarpBezierState bezierSelectionState(
  WarpCurveGrid curveGrid,
  Set<int> selection,
) {
  var total = 0;
  var curved = 0;
  _forSelectionEdges(curveGrid.grid, selection, (vertical, row, column) {
    total++;
    if ((vertical ? curveGrid.curves.ver : curveGrid.curves.hor)[row][column] !=
        null) {
      curved++;
    }
  });
  if (curved == 0) return WarpBezierState.off;
  return curved == total ? WarpBezierState.on : WarpBezierState.mixed;
}

/// Puts the selected points back at their nominal positions and gives the
/// curved edges around them the default handles. Straight edges stay
/// straight.
WarpCurveGrid resetCurveGridPositions(
  WarpCurveGrid curveGrid,
  Set<int> selection,
) {
  final grid = curveGrid.grid;
  final defaults = WarpCurves.defaults(
    grid.columns,
    grid.rows,
    grid.panelWidth,
    grid.panelHeight,
  );
  var curves = curveGrid.curves;
  _forSelectionEdges(grid, selection, (vertical, row, column) {
    if ((vertical ? curves.ver : curves.hor)[row][column] == null) return;
    curves = curves.withEdge(
      vertical: vertical,
      row: row,
      column: column,
      curve: (vertical ? defaults.ver : defaults.hor)[row][column],
    );
  });
  return WarpCurveGrid(
    grid: resetControlPositions(grid, selection),
    curves: curves,
  );
}

/// [moveControlSelection] for a curve grid. The handles are relative to their
/// points, so the edges keep their shape.
({WarpCurveGrid grid, double dx, double dy}) moveCurveGridSelection(
  WarpCurveGrid curveGrid,
  Set<int> selection,
  double dx,
  double dy, {
  required num rangeX,
  required num rangeY,
}) {
  final moved = moveControlSelection(
    curveGrid.grid,
    selection,
    dx,
    dy,
    rangeX: rangeX,
    rangeY: rangeY,
  );
  return (
    grid: WarpCurveGrid(grid: moved.grid, curves: curveGrid.curves),
    dx: moved.dx,
    dy: moved.dy,
  );
}

/// The same shape on a grid of [columns] x [rows] points. Without curves this
/// is [resampleControlGrid]. With curves the new points are read from the
/// old table and the handles are fitted to it; an edge that lies between
/// table lines cannot be fitted and becomes straight, so the new curve grid
/// only approximates the old table.
WarpCurveGrid resampleCurveGrid(
  WarpCurveGrid curveGrid,
  WarpGeometry geometry, {
  required int columns,
  required int rows,
}) {
  final old = curveGrid.grid;
  if (curveGrid.curves.curvedCount == 0) {
    return WarpCurveGrid(
      grid: resampleControlGrid(old, columns: columns, rows: rows),
      curves: WarpCurves.straight(columns, rows),
    );
  }
  final dense = curveEngineDense(curveGrid, geometry);
  final points = Float64List(columns * rows * 2);
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < columns; i++) {
      final s = sampleWarpPlane(
        dense,
        old.panelWidth * i / (columns - 1),
        old.panelHeight * j / (rows - 1),
        geometry,
      );
      points[(j * columns + i) * 2] = s.x;
      points[(j * columns + i) * 2 + 1] = s.y;
    }
  }
  final grid = WarpControlGrid(
    columns: columns,
    rows: rows,
    panelWidth: old.panelWidth,
    panelHeight: old.panelHeight,
    points: points,
  );
  return WarpCurveGrid(
    grid: grid,
    curves: curvesFromDense(dense, grid, geometry).curves,
  );
}
