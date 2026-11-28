import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/free_grid_view.dart';
import '../../../../domain/warp_control_grid.dart';
import '../../../../domain/warp_table.dart';

/// The colours the canvas draws with, taken from the theme by the widget.
class FreeGridPaintColors {
  const FreeGridPaintColors({
    required this.frame,
    required this.line,
    required this.pointFill,
    required this.warning,
  });

  /// The panel and movable range frames.
  final Color frame;

  /// The control grid, the points' outline and the faint table lines.
  final Color line;

  /// The inside of a point: the card colour.
  final Color pointFill;

  /// Folded cells.
  final Color warning;

  @override
  bool operator ==(Object other) =>
      other is FreeGridPaintColors &&
      other.frame == frame &&
      other.line == line &&
      other.pointFill == pointFill &&
      other.warning == warning;

  @override
  int get hashCode => Object.hash(frame, line, pointFill, warning);
}

/// Draws the Free grid canvas in panel px through a [FreeGridView]: the
/// movable range, the panel, the projector's own table, folded cells, the
/// control grid and its points. Nothing here reads state; the canvas widget
/// hands in what to show.
class FreeGridPainter extends CustomPainter {
  FreeGridPainter({
    required this.view,
    required this.frame,
    required this.colors,
    required this.geometry,
    required this.plane,
    required this.grid,
    required this.foldedCells,
    required this.pointRadius,
    required this.showTableLines,
  });

  final FreeGridView view;
  final FreeGridFrame frame;
  final FreeGridPaintColors colors;
  final WarpGeometry geometry;

  /// The projector's dense table (its first plane); null draws no lines.
  final WarpPlane? plane;

  /// The control grid; null (a read-only memory) draws frames and the table
  /// only.
  final WarpControlGrid? grid;

  /// Row-major indexes of the folded cells of [grid].
  final List<int> foldedCells;
  final double pointRadius;

  /// False on a dense grid, where the faint lines would hide the real one.
  final bool showTableLines;

  static const double _frameWidth = 1;
  static const double _dashOn = 6;
  static const double _dashOff = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _drawFrames(canvas);
    final plane = this.plane;
    if (showTableLines && plane != null) _drawTable(canvas, size, plane);
    final grid = this.grid;
    if (grid == null) return;
    _drawFolded(canvas, size, grid);
    _drawGrid(canvas, grid);
    _drawPoints(canvas, grid);
  }

  void _drawFrames(Canvas canvas) {
    final paint = Paint()
      ..color = colors.frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = _frameWidth;
    if (frame.rangeFrameVisible(view)) {
      _dashedRect(canvas, view.rectToScreen(frame.range), paint);
    }
    canvas.drawRect(view.rectToScreen(frame.panel), paint);
  }

  void _dashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        final end = math.min(at + _dashOn, metric.length);
        canvas.drawPath(metric.extractPath(at, end), paint);
        at += _dashOn + _dashOff;
      }
    }
  }

  /// The indexes 0, [stride], 2 * [stride] ... up to and including [last].
  static List<int> _indexes(int last, int stride) => [
    for (var i = 0; i < last; i += stride) i,
    last,
  ];

  void _drawTable(Canvas canvas, Size size, WarpPlane plane) {
    final lastColumn = geometry.lastInsideColumn;
    final lastRow = geometry.lastInsideRow;
    if (lastColumn < 1 || lastRow < 1) return;
    final columns = _indexes(
      lastColumn,
      freeGridDenseStride(geometry.stepX.toDouble(), view.zoom),
    );
    final rows = _indexes(
      lastRow,
      freeGridDenseStride(geometry.stepY.toDouble(), view.zoom),
    );
    Offset at(int c, int r) =>
        view.toScreen(Offset(plane.x(c, r), plane.y(c, r)));
    final path = Path();
    for (final r in rows) {
      path.moveTo(at(columns.first, r).dx, at(columns.first, r).dy);
      for (final c in columns.skip(1)) {
        final p = at(c, r);
        path.lineTo(p.dx, p.dy);
      }
    }
    for (final c in columns) {
      path.moveTo(at(c, rows.first).dx, at(c, rows.first).dy);
      for (final r in rows.skip(1)) {
        final p = at(c, r);
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.line.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }

  Offset _point(WarpControlGrid grid, int column, int row) {
    final i = grid.index(column, row);
    return view.toScreen(Offset(grid.xAt(i), grid.yAt(i)));
  }

  void _drawFolded(Canvas canvas, Size size, WarpControlGrid grid) {
    if (foldedCells.isEmpty) return;
    final visible = Offset.zero & size;
    final hatch = Paint()
      ..color = colors.warning.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final edge = Paint()
      ..color = colors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final cellsX = grid.columns - 1;
    for (final cell in foldedCells) {
      final i = cell % cellsX;
      final j = cell ~/ cellsX;
      final quad = Path()
        ..addPolygon([
          _point(grid, i, j),
          _point(grid, i + 1, j),
          _point(grid, i + 1, j + 1),
          _point(grid, i, j + 1),
        ], true);
      final bounds = quad.getBounds().intersect(visible);
      if (!bounds.isEmpty) {
        canvas.save();
        canvas.clipPath(quad);
        // Diagonal lines every 4 px across the part of the cell in view.
        for (var x = bounds.left - bounds.height; x < bounds.right; x += 4) {
          canvas.drawLine(
            Offset(x, bounds.bottom),
            Offset(x + bounds.height, bounds.top),
            hatch,
          );
        }
        canvas.restore();
      }
      canvas.drawPath(quad, edge);
    }
  }

  void _drawGrid(Canvas canvas, WarpControlGrid grid) {
    final path = Path();
    for (var j = 0; j < grid.rows; j++) {
      final first = _point(grid, 0, j);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < grid.columns; i++) {
        final p = _point(grid, i, j);
        path.lineTo(p.dx, p.dy);
      }
    }
    for (var i = 0; i < grid.columns; i++) {
      final first = _point(grid, i, 0);
      path.moveTo(first.dx, first.dy);
      for (var j = 1; j < grid.rows; j++) {
        final p = _point(grid, i, j);
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPoints(Canvas canvas, WarpControlGrid grid) {
    final fill = Paint()..color = colors.pointFill;
    final outline = Paint()
      ..color = colors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75;
    for (var j = 0; j < grid.rows; j++) {
      for (var i = 0; i < grid.columns; i++) {
        final p = _point(grid, i, j);
        canvas.drawCircle(p, pointRadius, fill);
        canvas.drawCircle(p, pointRadius, outline);
      }
    }
  }

  @override
  bool shouldRepaint(FreeGridPainter old) =>
      old.view != view ||
      old.colors != colors ||
      !identical(old.plane, plane) ||
      !identical(old.grid, grid) ||
      !listEquals(old.foldedCells, foldedCells) ||
      old.pointRadius != pointRadius ||
      old.showTableLines != showTableLines ||
      old.frame.canvas != frame.canvas ||
      old.frame.panelWidth != frame.panelWidth ||
      old.frame.panelHeight != frame.panelHeight ||
      old.frame.rangeX != frame.rangeX ||
      old.frame.rangeY != frame.rangeY;
}

/// The legend swatch of a folded cell: a small hatched box with an amber
/// edge.
class FreeGridFoldedSwatch extends CustomPainter {
  const FreeGridFoldedSwatch(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.save();
    canvas.clipRect(rect);
    final hatch = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (var x = -size.height; x < size.width; x += 4) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(FreeGridFoldedSwatch old) => old.color != color;
}
