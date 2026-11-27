import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_curve_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

Map<String, Object?> _fixture() => jsonDecode(
  File('test/fixtures/warp/curve_grid_vectors.json').readAsStringSync(),
) as Map<String, Object?>;

const _geo = WarpGeometry(
  panelWidth: 1920,
  panelHeight: 1200,
  columns: 128,
  rows: 78,
  stepX: 16,
  stepY: 16,
);

WarpEdgeCurve? _edge(Object? json) {
  if (json == null) return null;
  final m = json as Map<String, Object?>;
  final h1 = (m['h1']! as List).cast<num>();
  final h2 = (m['h2']! as List).cast<num>();
  return WarpEdgeCurve(
    h1x: h1[0].toDouble(),
    h1y: h1[1].toDouble(),
    h2x: h2[0].toDouble(),
    h2y: h2[1].toDouble(),
  );
}

WarpCurveGrid _curveGridFrom(Map<String, Object?> ctrl) {
  final rows = [
    for (final row in ctrl['points']! as List)
      [
        for (final p in row as List)
          [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()],
      ],
  ];
  final curves = ctrl['curves']! as Map<String, Object?>;
  return WarpCurveGrid(
    grid: WarpControlGrid.fromNested(rows, panelWidth: 1920, panelHeight: 1200),
    curves: WarpCurves(
      hor: [
        for (final r in curves['hor']! as List)
          [for (final e in r as List) _edge(e)],
      ],
      ver: [
        for (final r in curves['ver']! as List)
          [for (final e in r as List) _edge(e)],
      ],
    ),
  );
}

WarpControlGrid _identity(int columns, int rows) => WarpControlGrid.identity(
  columns: columns,
  rows: rows,
  panelWidth: 1920,
  panelHeight: 1200,
);

String _floatDigest(List<double> values) => sha256
    .convert(
      Float64List.fromList([for (final v in values) v + 0.0]).buffer
          .asUint8List(),
    )
    .toString();

/// Row-major x,y pairs of the nodes inside the panel (121 x 76 here).
List<double> _insideNodes(WarpPlane plane, int columns, int rows) => [
  for (var r = 0; r < rows; r++)
    for (var c = 0; c < columns; c++) ...[plane.x(c, r), plane.y(c, r)],
];

void main() {
  final spec = _fixture();

  group('edge parameters', () {
    for (final e in spec['edgeParams']! as List) {
      final edge = e as Map<String, Object?>;
      test('from ${edge['a']} to ${edge['b']}', () {
        final t = edgeParams(
          (edge['a']! as num).toDouble(),
          (edge['b']! as num).toDouble(),
        );
        expect(t.length, edge['count']);
        expect(_floatDigest(t), edge['sha256']);
        expect(t.first, 0);
        expect(t.last, 1);
      });
    }
  });

  group('curve engine', () {
    test('a hand-made curve grid is rebuilt exactly', () {
      final s = spec['synthetic']! as Map<String, Object?>;
      final grid = _curveGridFrom(s['ctrl']! as Map<String, Object?>);
      final dense = curveEngineDense(grid, _geo);
      expect(dense.columns, 128);
      expect(dense.rows, 78);
      final inside = _insideNodes(
        dense,
        s['insideColumns']! as int,
        s['insideRows']! as int,
      );
      expect(inside.length, 121 * 76 * 2);
      expect(_floatDigest(inside), s['sha256']);
      final samples = (s['samples']! as List).cast<num>();
      for (var i = 0; i < samples.length; i += 3) {
        final node = samples[i].toInt();
        expect(
          inside[node * 2],
          samples[i + 1].toDouble(),
          reason: 'node $node x',
        );
        expect(
          inside[node * 2 + 1],
          samples[i + 2].toDouble(),
          reason: 'node $node y',
        );
      }
    });

    test('nodes outside the panel are the identity', () {
      final s = spec['synthetic']! as Map<String, Object?>;
      final dense = curveEngineDense(
        _curveGridFrom(s['ctrl']! as Map<String, Object?>),
        _geo,
      );
      for (final (c, r) in [
        (121, 0),
        (127, 77),
        (0, 76),
        (50, 77),
        (125, 40),
      ]) {
        expect(dense.x(c, r), c * 16, reason: 'x $c,$r');
        expect(dense.y(c, r), r * 16, reason: 'y $c,$r');
      }
    });

    test('a curve table written by a real projector is reproduced closely', () {
      final s = spec['capture']! as Map<String, Object?>;
      final tolerance = (s['tolerancePx']! as num).toDouble();
      final dense = curveEngineDense(
        _curveGridFrom(s['ctrl']! as Map<String, Object?>),
        _geo,
      );
      final inside = _insideNodes(dense, 121, 76);
      final samples = (s['samples']! as List).cast<num>();
      expect(samples.length ~/ 3, greaterThan(100));
      for (var i = 0; i < samples.length; i += 3) {
        final node = samples[i].toInt();
        expect(
          inside[node * 2],
          closeTo(samples[i + 1].toDouble(), tolerance),
          reason: 'node $node x',
        );
        expect(
          inside[node * 2 + 1],
          closeTo(samples[i + 2].toDouble(), tolerance),
          reason: 'node $node y',
        );
      }
    });

    test('default handles on a neutral grid give the identity exactly', () {
      final g = WarpCurveGrid(
        grid: _identity(3, 3),
        curves: WarpCurves.defaults(3, 3, 1920, 1200),
      );
      final dense = curveEngineDense(g, _geo);
      for (var r = 0; r < 78; r++) {
        for (var c = 0; c < 128; c++) {
          expect(dense.x(c, r), c * 16, reason: 'x $c,$r');
          expect(dense.y(c, r), r * 16, reason: 'y $c,$r');
        }
      }
    });

    test(
      'straight edges give bilinear interpolation to within the rounding',
      () {
        final base = moveControlSelection(
          _identity(4, 3),
          {5},
          90,
          -40,
          rangeX: 600,
          rangeY: 600,
        ).grid;
        final straight = curveEngineDense(
          WarpCurveGrid(grid: base, curves: WarpCurves.straight(4, 3)),
          _geo,
        );
        final bilinear = denseFromControl(base, _geo);
        for (var i = 0; i < bilinear.points.length; i++) {
          expect(
            straight.points[i],
            closeTo(bilinear.points[i], 0.03),
            reason: 'value $i',
          );
        }
      },
    );

    test('the table of a grid without curves is the exact bilinear one', () {
      final base = _identity(3, 3);
      final a = denseFromCurveGrid(
        WarpCurveGrid(grid: base, curves: WarpCurves.straight(3, 3)),
        _geo,
      );
      expect(a.points, denseFromControl(base, _geo).points);
    });

    test('the table of a grid with curves comes from the curve engine', () {
      final s = spec['synthetic']! as Map<String, Object?>;
      final g = _curveGridFrom(s['ctrl']! as Map<String, Object?>);
      expect(
        denseFromCurveGrid(g, _geo).points,
        curveEngineDense(g, _geo).points,
      );
    });
  });

  group('default handles', () {
    test('are a third of the nominal cell along each edge', () {
      final c = WarpCurves.defaults(3, 3, 1920, 1200);
      expect(c.hor.length, 3);
      expect(c.hor[0].length, 2);
      expect(c.ver.length, 2);
      expect(c.ver[0].length, 3);
      expect(
        c.hor[1][0],
        const WarpEdgeCurve(h1x: 320, h1y: 0, h2x: -320, h2y: 0),
      );
      expect(
        c.ver[0][2],
        const WarpEdgeCurve(h1x: 0, h1y: 200, h2x: 0, h2y: -200),
      );
      expect(c.curvedCount, 12);
    });

    test('a straight set has no curved edges', () {
      expect(WarpCurves.straight(4, 3).curvedCount, 0);
      expect(WarpCurves.straight(4, 3).hor.length, 3);
      expect(WarpCurves.straight(4, 3).hor[0].length, 3);
      expect(WarpCurves.straight(4, 3).ver.length, 2);
      expect(WarpCurves.straight(4, 3).ver[0].length, 4);
    });
  });

  group('Bezier on a selection', () {
    final base = WarpCurveGrid(
      grid: _identity(3, 3),
      curves: WarpCurves.straight(3, 3),
    );

    test('turning it on curves only edges with a selected end', () {
      final on = setBezierOnSelection(base, {4}, on: true);
      expect(on.curves.curvedCount, 4);
      expect(on.curves.hor[1][0], isNotNull);
      expect(on.curves.hor[1][1], isNotNull);
      expect(on.curves.ver[0][1], isNotNull);
      expect(on.curves.ver[1][1], isNotNull);
      expect(on.curves.hor[0][0], isNull);
      expect(on.curves.ver[0][0], isNull);
    });

    test('a corner point owns two edges', () {
      expect(setBezierOnSelection(base, {0}, on: true).curves.curvedCount, 2);
    });

    test('the new handles are the defaults', () {
      final on = setBezierOnSelection(base, {4}, on: true);
      final want = WarpCurves.defaults(3, 3, 1920, 1200);
      expect(on.curves.hor[1][0], want.hor[1][0]);
      expect(on.curves.ver[1][1], want.ver[1][1]);
    });

    test('the default handles leave the table unchanged', () {
      final all = {for (var i = 0; i < 9; i++) i};
      final on = setBezierOnSelection(base, all, on: true);
      expect(on.curves.curvedCount, 12);
      final dense = curveEngineDense(on, _geo);
      for (var r = 0; r < 78; r++) {
        for (var c = 0; c < 128; c++) {
          expect(dense.x(c, r), c * 16);
          expect(dense.y(c, r), r * 16);
        }
      }
    });

    test('turning it off straightens the edges', () {
      final on = setBezierOnSelection(base, {4}, on: true);
      final off = setBezierOnSelection(on, {4}, on: false);
      expect(off.curves.curvedCount, 0);
    });

    test('turning it on keeps handles the user already set', () {
      final custom = const WarpEdgeCurve(h1x: 111, h1y: 22, h2x: -33, h2y: 44);
      final shaped = WarpCurveGrid(
        grid: base.grid,
        curves: base.curves.withEdge(
          vertical: false,
          row: 1,
          column: 0,
          curve: custom,
        ),
      );
      final on = setBezierOnSelection(shaped, {4}, on: true);
      expect(on.curves.hor[1][0], custom);
      expect(on.curves.hor[1][1], isNotNull);
    });

    test('the state is off, on or mixed over the selection edges', () {
      final centre = setBezierOnSelection(base, {4}, on: true);
      expect(bezierSelectionState(base, {4}), WarpBezierState.off);
      expect(bezierSelectionState(centre, {4}), WarpBezierState.on);
      expect(bezierSelectionState(centre, {0, 4}), WarpBezierState.mixed);
      expect(bezierSelectionState(centre, {}), WarpBezierState.off);
    });

    test('from mixed, a click turns every selected edge on', () {
      final centre = setBezierOnSelection(base, {4}, on: true);
      final all = setBezierOnSelection(centre, {0, 4}, on: true);
      expect(all.curves.curvedCount, 6);
      expect(bezierSelectionState(all, {0, 4}), WarpBezierState.on);
    });
  });

  group('reset positions', () {
    test('moves the points back and gives their edges the default handles', () {
      var g = WarpCurveGrid(
        grid: _identity(3, 3),
        curves: WarpCurves.defaults(3, 3, 1920, 1200),
      );
      final custom = const WarpEdgeCurve(h1x: 5, h1y: 6, h2x: 7, h2y: 8);
      g = WarpCurveGrid(
        grid: moveControlSelection(
          g.grid,
          {4},
          100,
          50,
          rangeX: 600,
          rangeY: 600,
        ).grid,
        curves: g.curves
            .withEdge(vertical: false, row: 1, column: 0, curve: custom)
            .withEdge(vertical: false, row: 0, column: 0, curve: custom),
      );
      final reset = resetCurveGridPositions(g, {4});
      expect(reset.grid.offsetAt(4), (dx: 0.0, dy: 0.0));
      final defaults = WarpCurves.defaults(3, 3, 1920, 1200);
      expect(reset.curves.hor[1][0], defaults.hor[1][0]);
      expect(reset.curves.ver[0][1], defaults.ver[0][1]);
      expect(
        reset.curves.hor[0][0],
        custom,
        reason: 'not an edge of the point',
      );
    });

    test('straight edges stay straight', () {
      var g = WarpCurveGrid(
        grid: _identity(3, 3),
        curves: WarpCurves.straight(3, 3),
      );
      g = WarpCurveGrid(
        grid: moveControlSelection(
          g.grid,
          {4},
          100,
          50,
          rangeX: 600,
          rangeY: 600,
        ).grid,
        curves: g.curves,
      );
      final reset = resetCurveGridPositions(g, {4});
      expect(reset.curves.curvedCount, 0);
    });
  });

  group('moving a selection', () {
    WarpCurveGrid shaped() {
      var grid = _identity(6, 5);
      grid = moveControlSelection(
        grid,
        {grid.index(2, 2)},
        800 - grid.xAt(grid.index(2, 2)),
        610 - grid.yAt(grid.index(2, 2)),
        rangeX: 600,
        rangeY: 600,
      ).grid;
      return WarpCurveGrid(
        grid: grid,
        curves: WarpCurves.defaults(6, 5, 1920, 1200).withEdge(
          vertical: false,
          row: 2,
          column: 2,
          curve: const WarpEdgeCurve(h1x: 150, h1y: 60, h2x: -120, h2y: 40),
        ),
      );
    }

    test('a block moves rigidly, edges keep their shape', () {
      final before = shaped();
      final selection = {
        for (var j = 1; j <= 2; j++)
          for (var i = 1; i <= 3; i++) before.grid.index(i, j),
      };
      final moved = moveCurveGridSelection(
        before,
        selection,
        37.5,
        -21.25,
        rangeX: 600,
        rangeY: 600,
      );
      expect((moved.dx, moved.dy), (37.5, -21.25));
      final a = curveEngineDense(before, _geo);
      final b = curveEngineDense(moved.grid, _geo);
      // A node deep inside the moved block shifts by exactly the delta.
      expect(b.x(50, 30) - a.x(50, 30), closeTo(37.5, 1e-6));
      expect(b.y(50, 30) - a.y(50, 30), closeTo(-21.25, 1e-6));
      // The handles are relative to their points and stay as they were.
      expect(moved.grid.curves.hor[2][2], before.curves.hor[2][2]);
    });

    test('the clamp uses the first point of the block', () {
      final before = shaped();
      final r = moveCurveGridSelection(
        before,
        {0},
        -900,
        0,
        rangeX: 600,
        rangeY: 600,
      );
      expect(r.dx, -600);
    });
  });

  group('reading handles back from a table', () {
    // A 5 x 4 grid has every edge on table nodes, so every edge can be fitted.
    final grid = () {
      var g = _identity(5, 4);
      g = moveControlSelection(
        g,
        {g.index(1, 1)},
        40,
        80,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      g = moveControlSelection(
        g,
        {g.index(3, 2)},
        20,
        60,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      return WarpCurveGrid(
        grid: g,
        curves: WarpCurves.defaults(5, 4, 1920, 1200)
            .withEdge(
              vertical: true,
              row: 0,
              column: 1,
              curve: const WarpEdgeCurve(
                h1x: 60,
                h1y: 140,
                h2x: -30,
                h2y: -130,
              ),
            )
            .withEdge(
              vertical: false,
              row: 2,
              column: 2,
              curve: const WarpEdgeCurve(h1x: 150, h1y: 60, h2x: -120, h2y: 40),
            ),
      );
    }();

    test('the handles come back and rebuild the table', () {
      final dense = curveEngineDense(grid, _geo);
      final read = curvesFromDense(dense, grid.grid, _geo);
      expect(read.unrecoverable, 0);
      for (final (vertical, row, column) in [(true, 0, 1), (false, 2, 2)]) {
        final got = vertical
            ? read.curves.ver[row][column]
            : read.curves.hor[row][column];
        final want = vertical
            ? grid.curves.ver[row][column]
            : grid.curves.hor[row][column];
        expect(got, isNotNull);
        expect(got!.h1x, closeTo(want!.h1x, 0.2));
        expect(got.h1y, closeTo(want.h1y, 0.2));
        expect(got.h2x, closeTo(want.h2x, 0.2));
        expect(got.h2y, closeTo(want.h2y, 0.2));
      }
      final rebuilt = curveEngineDense(
        WarpCurveGrid(grid: grid.grid, curves: read.curves),
        _geo,
      );
      for (var r = 0; r < 76; r++) {
        for (var c = 0; c < 121; c++) {
          expect(
            rebuilt.x(c, r),
            closeTo(dense.x(c, r), 0.03),
            reason: 'x $c,$r',
          );
          expect(
            rebuilt.y(c, r),
            closeTo(dense.y(c, r), 0.03),
            reason: 'y $c,$r',
          );
        }
      }
    });

    test('edges between table nodes are reported, not guessed', () {
      final g = WarpCurveGrid(
        grid: _identity(3, 3),
        curves: WarpCurves.defaults(3, 3, 1920, 1200),
      );
      final read = curvesFromDense(curveEngineDense(g, _geo), g.grid, _geo);
      // The middle row of a 3 x 3 grid lies at y = 37.5 nodes.
      expect(read.unrecoverable, greaterThan(0));
    });

    test('a neutral table reads back as straight edges', () {
      final g = WarpCurveGrid(
        grid: _identity(5, 4),
        curves: WarpCurves.straight(5, 4),
      );
      final read = curvesFromDense(
        denseFromControl(g.grid, _geo),
        g.grid,
        _geo,
      );
      expect(read.curves.curvedCount, 0);
    });
  });

  group('resample', () {
    test('without curves it is the plain grid resample', () {
      var g = _identity(3, 3);
      g = moveControlSelection(g, {4}, 70, 30, rangeX: 600, rangeY: 600).grid;
      final r = resampleCurveGrid(
        WarpCurveGrid(grid: g, curves: WarpCurves.straight(3, 3)),
        _geo,
        columns: 5,
        rows: 5,
      );
      expect(r.curves.curvedCount, 0);
      expect(r.curves.hor.length, 5);
      expect(r.curves.hor[0].length, 4);
      final plain = resampleControlGrid(g, columns: 5, rows: 5);
      for (var i = 0; i < plain.points.length; i++) {
        expect(r.grid.points[i], closeTo(plain.points[i], 1e-9));
      }
    });

    test('with curves the old points are kept and the mode stays on', () {
      final cg = WarpCurveGrid(
        grid: _identity(5, 4),
        curves: WarpCurves.defaults(5, 4, 1920, 1200),
      );
      var grid = cg.grid;
      grid = moveControlSelection(
        grid,
        {grid.index(1, 1)},
        40,
        80,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      final source = WarpCurveGrid(grid: grid, curves: cg.curves);
      final r = resampleCurveGrid(source, _geo, columns: 9, rows: 4);
      expect(r.grid.columns, 9);
      expect(r.grid.rows, 4);
      expect(r.curves.hor.length, 4);
      expect(r.curves.hor[0].length, 8);
      expect(r.curves.ver.length, 3);
      expect(r.curves.ver[0].length, 9);
      for (var j = 0; j < 4; j++) {
        for (var i = 0; i < 5; i++) {
          expect(
            r.grid.xAt(r.grid.index(2 * i, j)),
            closeTo(grid.xAt(grid.index(i, j)), 0.01),
          );
          expect(
            r.grid.yAt(r.grid.index(2 * i, j)),
            closeTo(grid.yAt(grid.index(i, j)), 0.01),
          );
        }
      }
      expect(r.curves.curvedCount, greaterThan(0));
    });
  });
}
