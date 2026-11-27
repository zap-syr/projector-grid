import 'dart:math' as math;
import 'dart:typed_data';

import 'warp_table.dart';

/// The largest control grid the editor offers. The real maximum of each
/// model is not known; 33 x 21 points is an assumption that keeps the point
/// count and the least-squares work small.
const int warpGridMaxColumns = 33;
const int warpGridMaxRows = 21;

/// A table that a control grid rebuilds to within this many pixels is a pure
/// grid table; beyond it the table holds detail the grid cannot describe.
const double warpPureGridResidualPx = 0.05;

/// A cell whose corner turns by less than this (px squared) is folded or
/// squeezed to nothing.
const double warpFoldEpsilon = 1e-6;

/// The control points of the free-form warp: a uniform [columns] x [rows]
/// grid laid over the panel. Point (i, j) sits nominally at
/// (panelWidth * i / (columns - 1), panelHeight * j / (rows - 1)); the grid
/// stores where it actually is. Points are numbered row-major, so the point
/// at column i and row j has the index `j * columns + i`.
///
/// Treat a grid as immutable: every function below returns a new one.
class WarpControlGrid {
  WarpControlGrid({
    required this.columns,
    required this.rows,
    required this.panelWidth,
    required this.panelHeight,
    required this.points,
  }) : assert(columns >= 2 && rows >= 2, 'a grid has at least 2 x 2 points'),
       assert(
         points.length == columns * rows * 2,
         'points must hold x and y for every point',
       );

  /// Every point at its nominal position: no correction.
  factory WarpControlGrid.identity({
    required int columns,
    required int rows,
    required int panelWidth,
    required int panelHeight,
  }) {
    final points = Float64List(columns * rows * 2);
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < columns; i++) {
        points[(j * columns + i) * 2] = panelWidth * i / (columns - 1);
        points[(j * columns + i) * 2 + 1] = panelHeight * j / (rows - 1);
      }
    }
    return WarpControlGrid(
      columns: columns,
      rows: rows,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
      points: points,
    );
  }

  /// A grid from rows of `[x, y]` pairs, the first index being the row.
  factory WarpControlGrid.fromNested(
    List<List<List<double>>> pointRows, {
    required int panelWidth,
    required int panelHeight,
  }) {
    final rows = pointRows.length;
    final columns = pointRows.first.length;
    final points = Float64List(columns * rows * 2);
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < columns; i++) {
        points[(j * columns + i) * 2] = pointRows[j][i][0];
        points[(j * columns + i) * 2 + 1] = pointRows[j][i][1];
      }
    }
    return WarpControlGrid(
      columns: columns,
      rows: rows,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
      points: points,
    );
  }

  final int columns;
  final int rows;
  final int panelWidth;
  final int panelHeight;

  /// x and y of every point, row-major.
  final Float64List points;

  /// The inverse of [WarpControlGrid.fromNested].
  List<List<List<double>>> toNested() => [
    for (var j = 0; j < rows; j++)
      [
        for (var i = 0; i < columns; i++)
          [points[(j * columns + i) * 2], points[(j * columns + i) * 2 + 1]],
      ],
  ];

  int index(int column, int row) => row * columns + column;

  double xAt(int index) => points[index * 2];

  double yAt(int index) => points[index * 2 + 1];

  /// Where column [column] sits when nothing is corrected.
  double nominalX(int column) => panelWidth * column / (columns - 1);

  double nominalY(int row) => panelHeight * row / (rows - 1);

  /// How far point [index] is from its nominal position.
  ({double dx, double dy}) offsetAt(int index) => (
    dx: xAt(index) - nominalX(index % columns),
    dy: yAt(index) - nominalY(index ~/ columns),
  );

  WarpControlGrid _withPoints(Float64List newPoints) => WarpControlGrid(
    columns: columns,
    rows: rows,
    panelWidth: panelWidth,
    panelHeight: panelHeight,
    points: newPoints,
  );
}

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Moves every point of [selection] by ([dx], [dy]). A line or an area is the
/// same operation as a point: one shared delta. The delta is clamped once,
/// from the first point of the selection (the lowest index), so that point
/// stays within the movable range, which reaches [rangeX] and [rangeY]
/// pixels beyond the panel; the others keep their distance to it and may end
/// outside. Returns the grid and the delta that was applied.
({WarpControlGrid grid, double dx, double dy}) moveControlSelection(
  WarpControlGrid grid,
  Set<int> selection,
  double dx,
  double dy, {
  required num rangeX,
  required num rangeY,
}) {
  if (selection.isEmpty) return (grid: grid, dx: 0.0, dy: 0.0);
  final first = selection.reduce(math.min);
  final fx = grid.xAt(first);
  final fy = grid.yAt(first);
  final appliedX = math
      .min(math.max(dx, -rangeX - fx), grid.panelWidth + rangeX - fx)
      .toDouble();
  final appliedY = math
      .min(math.max(dy, -rangeY - fy), grid.panelHeight + rangeY - fy)
      .toDouble();
  final points = Float64List.fromList(grid.points);
  for (final i in selection) {
    points[i * 2] += appliedX;
    points[i * 2 + 1] += appliedY;
  }
  return (grid: grid._withPoints(points), dx: appliedX, dy: appliedY);
}

/// Sets the position (in panel pixels) of every selected point, on the axes
/// that are given. A value that is typed applies to every point; each one is
/// held within the movable range.
WarpControlGrid setControlPosition(
  WarpControlGrid grid,
  Set<int> selection, {
  double? x,
  double? y,
  required num rangeX,
  required num rangeY,
}) {
  final points = Float64List.fromList(grid.points);
  for (final i in selection) {
    if (x != null) {
      points[i * 2] = _clamp(
        x,
        -rangeX.toDouble(),
        grid.panelWidth + rangeX.toDouble(),
      );
    }
    if (y != null) {
      points[i * 2 + 1] = _clamp(
        y,
        -rangeY.toDouble(),
        grid.panelHeight + rangeY.toDouble(),
      );
    }
  }
  return grid._withPoints(points);
}

/// Sets the offset from the nominal position of every selected point, on
/// the axes that are given; each point is held within the movable range.
WarpControlGrid setControlOffset(
  WarpControlGrid grid,
  Set<int> selection, {
  double? dx,
  double? dy,
  required num rangeX,
  required num rangeY,
}) {
  final points = Float64List.fromList(grid.points);
  for (final i in selection) {
    if (dx != null) {
      points[i * 2] = _clamp(
        grid.nominalX(i % grid.columns) + dx,
        -rangeX.toDouble(),
        grid.panelWidth + rangeX.toDouble(),
      );
    }
    if (dy != null) {
      points[i * 2 + 1] = _clamp(
        grid.nominalY(i ~/ grid.columns) + dy,
        -rangeY.toDouble(),
        grid.panelHeight + rangeY.toDouble(),
      );
    }
  }
  return grid._withPoints(points);
}

/// Puts every selected point back at its nominal position.
WarpControlGrid resetControlPositions(
  WarpControlGrid grid,
  Set<int> selection,
) {
  final points = Float64List.fromList(grid.points);
  for (final i in selection) {
    points[i * 2] = grid.nominalX(i % grid.columns);
    points[i * 2 + 1] = grid.nominalY(i ~/ grid.columns);
  }
  return grid._withPoints(points);
}

/// Mirror as symmetric offsets: the offset of every selected point is copied
/// to its partner on the other side of the grid, with the sign flipped on
/// the mirrored axis. [horizontal] pairs column i with column
/// `columns - 1 - i` and flips the x offset, otherwise rows are paired and
/// the y offset flips. A point on the axis has no partner and is left alone.
/// When both partners are selected, the one with the lower index is the
/// source.
WarpControlGrid mirrorControlOffsets(
  WarpControlGrid grid,
  Set<int> selection, {
  required bool horizontal,
}) {
  final points = Float64List.fromList(grid.points);
  for (final p in selection) {
    final column = p % grid.columns;
    final row = p ~/ grid.columns;
    final partnerColumn = horizontal ? grid.columns - 1 - column : column;
    final partnerRow = horizontal ? row : grid.rows - 1 - row;
    final q = grid.index(partnerColumn, partnerRow);
    if (q == p) continue;
    if (selection.contains(q) && q < p) continue;
    final offset = grid.offsetAt(p);
    final dx = horizontal ? -offset.dx : offset.dx;
    final dy = horizontal ? offset.dy : -offset.dy;
    points[q * 2] = grid.nominalX(partnerColumn) + dx;
    points[q * 2 + 1] = grid.nominalY(partnerRow) + dy;
  }
  return grid._withPoints(points);
}

/// The indexes of the points that lie outside the movable range, ascending.
List<int> controlPointsOutsideRange(
  WarpControlGrid grid, {
  required num rangeX,
  required num rangeY,
}) => [
  for (var i = 0; i < grid.columns * grid.rows; i++)
    if (grid.xAt(i) < -rangeX ||
        grid.xAt(i) > grid.panelWidth + rangeX ||
        grid.yAt(i) < -rangeY ||
        grid.yAt(i) > grid.panelHeight + rangeY)
      i,
];

// ------------------------------------------------------------ the surface

/// Where the bilinear surface of [grid] puts the panel position (x, y).
(double, double) _surface(WarpControlGrid grid, double x, double y) {
  final cellsX = grid.columns - 1;
  final cellsY = grid.rows - 1;
  final cw = grid.panelWidth / cellsX;
  final ch = grid.panelHeight / cellsY;
  final i = math.min(cellsX - 1, (x / cw).floor());
  final j = math.min(cellsY - 1, (y / ch).floor());
  final u = x / cw - i;
  final v = y / ch - j;
  double f(double Function(int index) at) =>
      (1 - u) * (1 - v) * at(grid.index(i, j)) +
      u * (1 - v) * at(grid.index(i + 1, j)) +
      (1 - u) * v * at(grid.index(i, j + 1)) +
      u * v * at(grid.index(i + 1, j + 1));
  return (f(grid.xAt), f(grid.yAt));
}

/// The same shape on a grid of [columns] x [rows] points: every new point is
/// taken from the old surface at its nominal position, so the deformation
/// is kept and only its description changes.
WarpControlGrid resampleControlGrid(
  WarpControlGrid grid, {
  required int columns,
  required int rows,
}) {
  final points = Float64List(columns * rows * 2);
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < columns; i++) {
      final (x, y) = _surface(
        grid,
        grid.panelWidth * i / (columns - 1),
        grid.panelHeight * j / (rows - 1),
      );
      points[(j * columns + i) * 2] = x;
      points[(j * columns + i) * 2 + 1] = y;
    }
  }
  return WarpControlGrid(
    columns: columns,
    rows: rows,
    panelWidth: grid.panelWidth,
    panelHeight: grid.panelHeight,
    points: points,
  );
}

/// The dense table of a grid: the bilinear surface over the panel, and the
/// nominal lattice outside it. Rebuilt tables match tables stored on real
/// projectors to within 0.02 px.
WarpPlane denseFromControl(WarpControlGrid grid, WarpGeometry geometry) =>
    WarpPlane.generate(
      name: 'W',
      columns: geometry.columns,
      rows: geometry.rows,
      point: (c, r) {
        final x = (c * geometry.stepX).toDouble();
        final y = (r * geometry.stepY).toDouble();
        if (x > grid.panelWidth || y > grid.panelHeight || x < 0 || y < 0) {
          return (x, y);
        }
        return _surface(grid, x, y);
      },
    );

/// [denseFromControl] as a table. A header that was read is kept; without
/// one the default header is used.
WarpTable tableFromControlGrid(
  WarpControlGrid grid,
  WarpGeometry geometry, {
  Uint8List? header,
}) => WarpTable(
  columns: geometry.columns,
  rows: geometry.rows,
  header: header ?? defaultWarpHeader(1),
  planes: [denseFromControl(grid, geometry)],
);

/// Recovers a [columns] x [rows] grid from a dense table by least squares over
/// the nodes inside the panel. The residual is the largest difference, in
/// px, between the table and the table the recovered grid builds: below
/// [warpPureGridResidualPx] the table is a pure grid table.
({WarpControlGrid grid, double residual}) controlFromDense(
  WarpPlane plane,
  WarpGeometry geometry, {
  required int columns,
  required int rows,
}) {
  final n = columns * rows;
  final band = columns + 1; // a point couples to those one row and column away
  final panelWidth = geometry.panelWidth;
  final panelHeight = geometry.panelHeight;
  final cw = panelWidth / (columns - 1);
  final ch = panelHeight / (rows - 1);

  // Normal equations A p = b of the bilinear model. A is symmetric, banded
  // and positive definite, so only its lower band is kept: row i holds
  // A[i][i - k] at k = 0..band.
  final a = List<Float64List>.generate(n, (_) => Float64List(band + 1));
  final bx = Float64List(n);
  final by = Float64List(n);
  for (var r = 0; r < plane.rows; r++) {
    for (var c = 0; c < plane.columns; c++) {
      final x = (c * geometry.stepX).toDouble();
      final y = (r * geometry.stepY).toDouble();
      if (x > panelWidth || y > panelHeight) continue;
      final i = math.min(columns - 2, (x / cw).floor());
      final j = math.min(rows - 2, (y / ch).floor());
      final u = x / cw - i;
      final v = y / ch - j;
      final idx = [
        j * columns + i,
        j * columns + i + 1,
        (j + 1) * columns + i,
        (j + 1) * columns + i + 1,
      ];
      final w = [(1 - u) * (1 - v), u * (1 - v), (1 - u) * v, u * v];
      for (var p = 0; p < 4; p++) {
        for (var q = 0; q < 4; q++) {
          if (idx[q] <= idx[p]) a[idx[p]][idx[p] - idx[q]] += w[p] * w[q];
        }
        bx[idx[p]] += w[p] * plane.x(c, r);
        by[idx[p]] += w[p] * plane.y(c, r);
      }
    }
  }

  // Banded Cholesky factorisation A = L L^T, in place.
  for (var i = 0; i < n; i++) {
    for (var j = math.max(0, i - band); j <= i; j++) {
      var sum = a[i][i - j];
      for (var k = math.max(0, i - band); k < j; k++) {
        sum -= a[i][i - k] * a[j][j - k];
      }
      if (j == i) {
        if (sum <= 1e-12) {
          throw StateError(
            'the table does not determine a $columns x $rows grid',
          );
        }
        a[i][0] = math.sqrt(sum);
      } else {
        a[i][i - j] = sum / a[j][0];
      }
    }
  }

  Float64List solve(Float64List rhs) {
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      var sum = rhs[i];
      for (var k = math.max(0, i - band); k < i; k++) {
        sum -= a[i][i - k] * y[k];
      }
      y[i] = sum / a[i][0];
    }
    final x = Float64List(n);
    for (var i = n - 1; i >= 0; i--) {
      var sum = y[i];
      for (var k = i + 1; k <= math.min(n - 1, i + band); k++) {
        sum -= a[k][k - i] * x[k];
      }
      x[i] = sum / a[i][0];
    }
    return x;
  }

  final xs = solve(bx);
  final ys = solve(by);
  final points = Float64List(n * 2);
  for (var i = 0; i < n; i++) {
    points[i * 2] = xs[i];
    points[i * 2 + 1] = ys[i];
  }
  final grid = WarpControlGrid(
    columns: columns,
    rows: rows,
    panelWidth: panelWidth,
    panelHeight: panelHeight,
    points: points,
  );

  final rebuilt = denseFromControl(grid, geometry);
  var residual = 0.0;
  for (var r = 0; r < plane.rows; r++) {
    for (var c = 0; c < plane.columns; c++) {
      if (c * geometry.stepX > panelWidth || r * geometry.stepY > panelHeight) {
        continue;
      }
      residual = math.max(
        residual,
        math.max(
          (plane.x(c, r) - rebuilt.x(c, r)).abs(),
          (plane.y(c, r) - rebuilt.y(c, r)).abs(),
        ),
      );
    }
  }
  return (grid: grid, residual: residual);
}

/// Whether a table that [controlFromDense] could only rebuild to within
/// [residual] px holds detail the grid cannot describe, so that editing
/// would replace it with the grid shape.
bool hasUndescribedDetail(double residual) =>
    residual >= warpPureGridResidualPx;

// ------------------------------------------------------------ folded cells

/// Whether the quad c0 c1 c2 c3 (clockwise on a screen, y down) has a corner
/// that turns the wrong way or not at all. For a bilinear cell the corners
/// decide: the Jacobian is linear over the cell.
bool _quadFolded(
  double x0,
  double y0,
  double x1,
  double y1,
  double x2,
  double y2,
  double x3,
  double y3,
) {
  double turn(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) => (bx - ax) * (cy - by) - (by - ay) * (cx - bx);
  return math.min(
        math.min(turn(x0, y0, x1, y1, x2, y2), turn(x1, y1, x2, y2, x3, y3)),
        math.min(turn(x2, y2, x3, y3, x0, y0), turn(x3, y3, x0, y0, x1, y1)),
      ) <=
      warpFoldEpsilon;
}

/// The cells of the control grid that are folded over or squeezed to nothing,
/// numbered row-major over the `(columns - 1) x (rows - 1)` cells.
List<int> foldedControlCells(WarpControlGrid grid) {
  final folded = <int>[];
  for (var j = 0; j < grid.rows - 1; j++) {
    for (var i = 0; i < grid.columns - 1; i++) {
      final a = grid.index(i, j);
      final b = grid.index(i + 1, j);
      final c = grid.index(i + 1, j + 1);
      final d = grid.index(i, j + 1);
      if (_quadFolded(
        grid.xAt(a),
        grid.yAt(a),
        grid.xAt(b),
        grid.yAt(b),
        grid.xAt(c),
        grid.yAt(c),
        grid.xAt(d),
        grid.yAt(d),
      )) {
        folded.add(j * (grid.columns - 1) + i);
      }
    }
  }
  return folded;
}

/// The folded cells of a dense table that lie inside the panel, numbered
/// row-major over the `(columns - 1) x (rows - 1)` cells of the table. This
/// also finds folds that curved edges cause.
List<int> foldedTableCells(WarpPlane plane, WarpGeometry geometry) {
  final folded = <int>[];
  for (var r = 0; r < geometry.lastInsideRow; r++) {
    for (var c = 0; c < geometry.lastInsideColumn; c++) {
      if (_quadFolded(
        plane.x(c, r),
        plane.y(c, r),
        plane.x(c + 1, r),
        plane.y(c + 1, r),
        plane.x(c + 1, r + 1),
        plane.y(c + 1, r + 1),
        plane.x(c, r + 1),
        plane.y(c, r + 1),
      )) {
        folded.add(r * (plane.columns - 1) + c);
      }
    }
  }
  return folded;
}
