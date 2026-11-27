import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/warp/$name').readAsStringSync())
        as Map<String, Object?>;

const _geo4k = WarpGeometry(
  panelWidth: 3840,
  panelHeight: 2400,
  columns: 128,
  rows: 78,
  stepX: 32,
  stepY: 32,
);
const _geoWuxga = WarpGeometry(
  panelWidth: 1920,
  panelHeight: 1200,
  columns: 128,
  rows: 78,
  stepX: 16,
  stepY: 16,
);

WarpControlGrid _gridFrom(Object? points, int width, int height) {
  final rows = [
    for (final row in points! as List)
      [
        for (final p in row as List)
          [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()],
      ],
  ];
  return WarpControlGrid.fromNested(
    rows,
    panelWidth: width,
    panelHeight: height,
  );
}

WarpControlGrid _identity(
  int columns,
  int rows, [
  int w = 1920,
  int h = 1200,
]) => WarpControlGrid.identity(
  columns: columns,
  rows: rows,
  panelWidth: w,
  panelHeight: h,
);

/// One real stored row of a table, as a one-row plane.
WarpPlane _storedRow(String tableName, int row) {
  final tables = _fixture('store_tables.json')['tables']! as List;
  final table = tables.firstWhere(
    (t) => (t as Map)['name'] == tableName,
  ) as Map<String, Object?>;
  final hex = (table['rowHex']! as Map)['$row']! as String;
  final block = Uint8List.fromList([
    table['columns']! as int,
    1,
    ...warpHexToBytes(table['header']! as String),
    ...warpHexToBytes(hex),
  ]);
  return decodeTable(
    block,
    WarpEncoding.values.byName(table['encoding']! as String),
    table['bits']! as int,
  ).planes[0];
}

void main() {
  group('limits of the editor', () {
    test('the grid size is capped at 33 x 21 points', () {
      expect(warpGridMaxColumns, 33);
      expect(warpGridMaxRows, 21);
    });
  });

  group('grid model', () {
    test('an identity grid sits on the nominal positions', () {
      final g = _identity(3, 3);
      expect(g.columns, 3);
      expect(g.rows, 3);
      expect(g.nominalX(1), 960);
      expect(g.nominalY(2), 1200);
      expect(g.xAt(g.index(1, 1)), 960);
      expect(g.yAt(g.index(1, 1)), 600);
      expect(g.offsetAt(4), (dx: 0.0, dy: 0.0));
    });

    test('points are addressed row-major', () {
      final g = _identity(5, 4);
      expect(g.index(3, 2), 2 * 5 + 3);
      expect(g.nominalX(3), 1920 * 3 / 4);
      expect(g.nominalY(2), 1200 * 2 / 3);
    });

    test('nested lists convert both ways', () {
      final nested = [
        [
          [1.0, 2.0],
          [3.0, 4.0],
        ],
        [
          [5.0, 6.0],
          [7.0, 8.0],
        ],
      ];
      final g = WarpControlGrid.fromNested(
        nested,
        panelWidth: 100,
        panelHeight: 80,
      );
      expect(g.toNested(), nested);
      expect(g.xAt(g.index(1, 1)), 7);
    });
  });

  group('moving a selection', () {
    test('one point moves by the delta', () {
      final g = _identity(3, 3);
      final r = moveControlSelection(g, {4}, 25, -10, rangeX: 600, rangeY: 600);
      expect((r.dx, r.dy), (25.0, -10.0));
      expect(r.grid.xAt(4), 985);
      expect(r.grid.yAt(4), 590);
      expect(g.xAt(4), 960, reason: 'the input grid is not modified');
    });

    test('a point stops at the movable range', () {
      final g = _identity(3, 3);
      final r = moveControlSelection(g, {2}, 1000, 0, rangeX: 600, rangeY: 600);
      expect(r.dx, 600);
      expect(r.grid.xAt(2), 1920 + 600);
      final left = moveControlSelection(
        g,
        {0},
        -2000,
        -2000,
        rangeX: 600,
        rangeY: 300,
      );
      expect((left.dx, left.dy), (-600.0, -300.0));
    });

    test('a group is clamped once, by its first point', () {
      final g = _identity(3, 3);
      final all = {for (var i = 0; i < 9; i++) i};
      final r = moveControlSelection(
        g,
        all,
        -1000,
        0,
        rangeX: 600,
        rangeY: 600,
      );
      expect(r.dx, -600);
      for (var i = 0; i < 9; i++) {
        expect(r.grid.xAt(i), g.xAt(i) - 600, reason: 'point $i');
      }
    });

    test('points other than the first may leave the range with the group', () {
      final g = _identity(3, 3);
      final all = {for (var i = 0; i < 9; i++) i};
      final r = moveControlSelection(g, all, 1000, 0, rangeX: 600, rangeY: 600);
      // The first point (0, 0) may travel up to 1920 + 600, so 1000 is kept
      // and the right column ends at 2920, beyond 1920 + 600.
      expect(r.dx, 1000);
      expect(r.grid.xAt(2), 2920);
    });

    test('the first point is the lowest index however the set is ordered', () {
      final g = _identity(3, 3);
      final r = moveControlSelection(
        g,
        {8, 0, 4},
        -1000,
        0,
        rangeX: 600,
        rangeY: 600,
      );
      expect(r.dx, -600);
    });

    test('an empty selection moves nothing', () {
      final g = _identity(3, 3);
      final r = moveControlSelection(g, {}, 10, 10, rangeX: 600, rangeY: 600);
      expect((r.dx, r.dy), (0.0, 0.0));
      expect(r.grid.toNested(), g.toNested());
    });

    test('typed positions apply to every selected point and are clamped', () {
      final g = _identity(3, 3);
      final r = setControlPosition(
        g,
        {3, 4, 5},
        x: 700,
        rangeX: 600,
        rangeY: 600,
      );
      expect([3, 4, 5].map(r.xAt), [700, 700, 700]);
      expect([3, 4, 5].map(r.yAt), [600, 600, 600]);
      final far = setControlPosition(g, {4}, y: 9000, rangeX: 600, rangeY: 600);
      expect(far.yAt(4), 1200 + 600);
    });

    test('typed offsets give every selected point the same offset', () {
      final g = moveControlSelection(
        _identity(3, 3),
        {3},
        50,
        0,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      final r = setControlOffset(
        g,
        {3, 4, 5},
        dx: 20,
        rangeX: 600,
        rangeY: 600,
      );
      expect(r.offsetAt(3), (dx: 20.0, dy: 0.0));
      expect(r.offsetAt(4), (dx: 20.0, dy: 0.0));
      expect(r.offsetAt(5), (dx: 20.0, dy: 0.0));
      expect(r.offsetAt(0), (dx: 0.0, dy: 0.0));
    });

    test('points outside the movable range are listed', () {
      final g = _identity(3, 3);
      final moved = setControlPosition(
        g,
        {0, 8},
        x: -700,
        rangeX: 10000,
        rangeY: 10000,
      );
      expect(controlPointsOutsideRange(moved, rangeX: 600, rangeY: 600), [
        0,
        8,
      ]);
      expect(controlPointsOutsideRange(g, rangeX: 600, rangeY: 600), isEmpty);
    });
  });

  group('reset positions', () {
    test('selected points return to their nominal positions', () {
      var g = _identity(3, 3);
      g = moveControlSelection(
        g,
        {0, 4, 8},
        33,
        -12,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      final r = resetControlPositions(g, {4, 8});
      expect(r.offsetAt(4), (dx: 0.0, dy: 0.0));
      expect(r.offsetAt(8), (dx: 0.0, dy: 0.0));
      expect(r.offsetAt(0), (dx: 33.0, dy: -12.0));
    });
  });

  group('mirror as symmetric offsets', () {
    WarpControlGrid moved(
      WarpControlGrid g,
      Map<int, (double, double)> offsets,
    ) {
      var out = g;
      offsets.forEach((i, o) {
        out = moveControlSelection(
          out,
          {i},
          o.$1,
          o.$2,
          rangeX: 1000,
          rangeY: 1000,
        ).grid;
      });
      return out;
    }

    test('horizontally the offset is copied with the x sign flipped', () {
      final g = moved(_identity(5, 3), {
        for (var r = 0; r < 3; r++) ...{
          r * 5 + 0: (30.0, -12.0 + r),
          r * 5 + 1: (18.0, 4.0),
        },
      });
      final left = {
        for (var r = 0; r < 3; r++) ...[r * 5 + 0, r * 5 + 1],
      };
      final m = mirrorControlOffsets(g, left, horizontal: true);
      for (var r = 0; r < 3; r++) {
        expect(m.offsetAt(r * 5 + 4), (dx: -30.0, dy: -12.0 + r));
        expect(m.offsetAt(r * 5 + 3), (dx: -18.0, dy: 4.0));
        expect(m.offsetAt(r * 5 + 2), (dx: 0.0, dy: 0.0), reason: 'centre');
        expect(m.offsetAt(r * 5 + 0), g.offsetAt(r * 5 + 0), reason: 'source');
      }
    });

    test('vertically the offset is copied with the y sign flipped', () {
      final g = moved(_identity(3, 3), {0: (5.0, 20.0), 1: (-7.0, 9.0)});
      final m = mirrorControlOffsets(g, {0, 1}, horizontal: false);
      expect(m.offsetAt(6), (dx: 5.0, dy: -20.0));
      expect(m.offsetAt(7), (dx: -7.0, dy: -9.0));
      expect(m.offsetAt(3), (dx: 0.0, dy: 0.0), reason: 'the middle row stays');
    });

    test('a point on the axis has no partner and is left alone', () {
      final g = moved(_identity(3, 3), {1: (10.0, 10.0)});
      final m = mirrorControlOffsets(g, {1}, horizontal: true);
      expect(m.toNested(), g.toNested());
    });

    test('when both partners are selected the lower index is the source', () {
      final g = moved(_identity(3, 3), {0: (10.0, 4.0), 2: (-3.0, 8.0)});
      final m = mirrorControlOffsets(g, {0, 2}, horizontal: true);
      expect(m.offsetAt(0), (dx: 10.0, dy: 4.0));
      expect(m.offsetAt(2), (dx: -10.0, dy: 4.0));
    });

    test('each selected point reaches its own partner', () {
      final g = moved(_identity(5, 5), {0: (12.0, 7.0), 6: (-4.0, 3.0)});
      final once = mirrorControlOffsets(g, {0, 6}, horizontal: true);
      expect(once.offsetAt(4), (dx: -12.0, dy: 7.0));
      expect(once.offsetAt(8), (dx: 4.0, dy: 3.0));
    });
  });

  group('resample keeps the shape', () {
    WarpControlGrid shaped() => moveControlSelection(
      _identity(3, 3),
      {4},
      140,
      40,
      rangeX: 600,
      rangeY: 600,
    ).grid;

    test('old points survive a doubling of the cells', () {
      final g = shaped();
      final r = resampleControlGrid(g, columns: 5, rows: 5);
      expect(r.columns, 5);
      expect(r.rows, 5);
      for (var j = 0; j < 3; j++) {
        for (var i = 0; i < 3; i++) {
          expect(
            r.xAt(r.index(2 * i, 2 * j)),
            closeTo(g.xAt(g.index(i, j)), 1e-9),
          );
          expect(
            r.yAt(r.index(2 * i, 2 * j)),
            closeTo(g.yAt(g.index(i, j)), 1e-9),
          );
        }
      }
    });

    test('new points lie on the old surface', () {
      final g = shaped();
      final r = resampleControlGrid(g, columns: 5, rows: 5);
      // Cell centre of the old top-left cell: the mean of its four corners.
      final expectedX = (g.xAt(0) + g.xAt(1) + g.xAt(3) + g.xAt(4)) / 4;
      final expectedY = (g.yAt(0) + g.yAt(1) + g.yAt(3) + g.yAt(4)) / 4;
      expect(r.xAt(r.index(1, 1)), closeTo(expectedX, 1e-9));
      expect(r.yAt(r.index(1, 1)), closeTo(expectedY, 1e-9));
    });

    test('the table of a refined grid equals the table of the old grid', () {
      final g = shaped();
      final r = resampleControlGrid(g, columns: 5, rows: 5);
      final a = denseFromControl(g, _geoWuxga);
      final b = denseFromControl(r, _geoWuxga);
      for (var i = 0; i < a.points.length; i++) {
        expect(b.points[i], closeTo(a.points[i], 1e-6), reason: 'value $i');
      }
    });

    test('the corners survive a coarser grid', () {
      final g = _identity(5, 5);
      final r = resampleControlGrid(g, columns: 3, rows: 2);
      expect(r.columns, 3);
      expect(r.rows, 2);
      expect(r.xAt(r.index(2, 1)), closeTo(1920, 1e-9));
      expect(r.yAt(r.index(2, 1)), closeTo(1200, 1e-9));
      expect(r.xAt(r.index(1, 0)), closeTo(960, 1e-9));
    });

    test('an identity grid stays identity at any size', () {
      final r = resampleControlGrid(_identity(3, 3), columns: 17, rows: 11);
      final want = _identity(17, 11);
      for (var i = 0; i < want.points.length; i++) {
        expect(r.points[i], closeTo(want.points[i], 1e-9));
      }
    });
  });

  group('table from the grid', () {
    test('nodes outside the panel stay on the nominal lattice', () {
      final g = moveControlSelection(
        _identity(3, 3, 3840, 2400),
        {4},
        100,
        100,
        rangeX: 1200,
        rangeY: 1200,
      ).grid;
      final dense = denseFromControl(g, _geo4k);
      expect(dense.columns, 128);
      expect(dense.rows, 78);
      expect(dense.x(127, 77), 127 * 32);
      expect(dense.y(127, 77), 77 * 32);
      expect(dense.x(121, 10), 121 * 32);
    });

    test('a neutral grid gives the identity table', () {
      final dense = denseFromControl(_identity(9, 5, 3840, 2400), _geo4k);
      final want = identityWarpTable(_geo4k).planes[0];
      for (var i = 0; i < want.points.length; i++) {
        expect(dense.points[i], closeTo(want.points[i], 1e-9));
      }
    });

    test('the table carries the default header unless one is given', () {
      final g = _identity(3, 3, 3840, 2400);
      expect(tableFromControlGrid(g, _geo4k).header, defaultWarpHeader(1));
      final read = Uint8List.fromList(List.generate(41, (i) => i + 1));
      expect(tableFromControlGrid(g, _geo4k, header: read).header, read);
    });

    test(
      'the recovered points of a stored table rebuild it within 0.02 px',
      () {
        final spec =
            _fixture('control_grid_vectors.json')['recovered4k']!
                as Map<String, Object?>;
        final g = _gridFrom(spec['points'], 3840, 2400);
        final dense = denseFromControl(g, _geo4k);
        for (final row in [0, 37]) {
          final stored = _storedRow('store_4k_full', row);
          for (var c = 0; c < 128; c++) {
            expect(
              dense.x(c, row),
              closeTo(stored.x(c, 0), 0.02),
              reason: '$row,$c x',
            );
            expect(
              dense.y(c, row),
              closeTo(stored.y(c, 0), 0.02),
              reason: '$row,$c y',
            );
          }
        }
      },
    );
  });

  group('tables written for PC-3 match byte for byte', () {
    final specs =
        (_fixture('control_grid_vectors.json')['writtenGrids']! as List)
            .cast<Map<String, Object?>>();
    for (final spec in specs) {
      test('${spec['name']}: full and delta frames', () {
        final g = _gridFrom(spec['points'], 3840, 2400);
        final full = tableFromControlGrid(g, _geo4k);
        final fullFrames = tableWriteFrames(
          full,
          type: warpTypeCode(0x70, WarpSlot.pc3),
          encoding: WarpEncoding.triple,
          bits: 3,
        );
        expect(fullFrames.length, spec['fullFrames']);
        expect(
          sha256.convert([for (final f in fullFrames) ...f]).toString(),
          spec['fullSha256'],
        );

        final fpga = fpgaTableFromFull(full, _geo4k);
        expect(fpgaEncodingFor(fpga), WarpEncoding.delta);
        final deltaFrames = tableWriteFrames(
          fpga,
          type: warpTypeCode(0x80, WarpSlot.pc3),
          encoding: WarpEncoding.delta,
          bits: 3,
        );
        expect(deltaFrames.length, spec['deltaFrames']);
        expect(
          sha256.convert([for (final f in deltaFrames) ...f]).toString(),
          spec['deltaSha256'],
        );
      });

      test(
        '${spec['name']}: what the vendor software shows after a reload',
        () {
          final g = _gridFrom(spec['points'], 3840, 2400);
          final dense = denseFromControl(g, _geo4k);
          for (final s in spec['shows']! as List) {
            final column = (s as List)[0] as int;
            final row = s[1] as int;
            final shown = sampleWarpPlane(
              dense,
              g.nominalX(column),
              g.nominalY(row),
              _geo4k,
            );
            expect(shown.x, closeTo((s[2] as num).toDouble(), 0.051));
            expect(shown.y, closeTo((s[3] as num).toDouble(), 0.051));
          }
        },
      );
    }

    test('the WUXGA centre point shows 1080.7 / 596.0', () {
      final spec =
          _fixture('control_grid_vectors.json')['wuxga3x3']!
              as Map<String, Object?>;
      final g = _gridFrom(spec['points'], 1920, 1200);
      final dense = denseFromControl(g, _geoWuxga);
      final shows = spec['shows']! as List;
      final shown = sampleWarpPlane(
        dense,
        g.nominalX(shows[0] as int),
        g.nominalY(shows[1] as int),
        _geoWuxga,
      );
      expect(shown.x, closeTo((shows[2] as num).toDouble(), 0.051));
      expect(shown.y, closeTo((shows[3] as num).toDouble(), 0.051));
    });
  });

  group('recovering the grid from a table', () {
    test('a table built from a grid gives the grid back', () {
      final spec =
          (_fixture('control_grid_vectors.json')['writtenGrids']! as List)
              .cast<Map<String, Object?>>()
              .firstWhere((s) => s['name'] == 'pc3_8x4');
      final g = _gridFrom(spec['points'], 3840, 2400);
      final dense = denseFromControl(g, _geo4k);
      final r = controlFromDense(dense, _geo4k, columns: 9, rows: 5);
      expect(r.residual, lessThan(1e-6));
      expect(hasUndescribedDetail(r.residual), isFalse);
      for (var i = 0; i < g.points.length; i++) {
        expect(
          r.grid.points[i],
          closeTo(g.points[i], 1e-6),
          reason: 'value $i',
        );
      }
    });

    test('the largest supported grid is recovered', () {
      var g = _identity(33, 21, 3840, 2400);
      g = moveControlSelection(
        g,
        {g.index(10, 7), g.index(11, 7), g.index(20, 14)},
        60,
        -35,
        rangeX: 1200,
        rangeY: 1200,
      ).grid;
      final dense = denseFromControl(g, _geo4k);
      final r = controlFromDense(dense, _geo4k, columns: 33, rows: 21);
      expect(r.residual, lessThan(1e-6));
      for (var i = 0; i < g.points.length; i++) {
        expect(r.grid.points[i], closeTo(g.points[i], 1e-6));
      }
    });

    test(
      'a grid that is too small leaves a residual the user is told about',
      () {
        final spec =
            (_fixture('control_grid_vectors.json')['writtenGrids']! as List)
                .cast<Map<String, Object?>>()
                .firstWhere((s) => s['name'] == 'pc3_8x4');
        final dense = denseFromControl(
          _gridFrom(spec['points'], 3840, 2400),
          _geo4k,
        );
        final r = controlFromDense(dense, _geo4k, columns: 3, rows: 3);
        expect(r.residual, greaterThan(10));
        expect(hasUndescribedDetail(r.residual), isTrue);
      },
    );

    test('the residual threshold is 0.05 px', () {
      expect(hasUndescribedDetail(0.049), isFalse);
      expect(hasUndescribedDetail(0.05), isTrue);
    });

    test('an identity table gives an identity grid', () {
      final r = controlFromDense(
        identityWarpTable(_geo4k).planes[0],
        _geo4k,
        columns: 4,
        rows: 3,
      );
      expect(r.residual, lessThan(1e-9));
      final want = _identity(4, 3, 3840, 2400);
      for (var i = 0; i < want.points.length; i++) {
        expect(r.grid.points[i], closeTo(want.points[i], 1e-6));
      }
    });
  });

  group('folded cells', () {
    test('a neutral grid has none', () {
      expect(foldedControlCells(_identity(4, 3)), isEmpty);
      expect(
        foldedTableCells(
          denseFromControl(_identity(4, 3, 3840, 2400), _geo4k),
          _geo4k,
        ),
        isEmpty,
      );
    });

    test('moving a point past its neighbour folds the cells around it', () {
      final g = moveControlSelection(
        _identity(3, 3),
        {4},
        -1100,
        0,
        rangeX: 2000,
        rangeY: 2000,
      ).grid;
      // Cells are numbered row-major over the 2 x 2 cells.
      expect(foldedControlCells(g), [0, 2]);
    });

    test('a squeezed cell counts as folded', () {
      final g = moveControlSelection(
        _identity(3, 3),
        {4},
        -960,
        0,
        rangeX: 2000,
        rangeY: 2000,
      ).grid;
      expect(foldedControlCells(g), isNotEmpty);
    });

    test('the table of a folded grid has folded cells too', () {
      final g = moveControlSelection(
        _identity(3, 3, 3840, 2400),
        {4},
        -2300,
        0,
        rangeX: 3000,
        rangeY: 3000,
      ).grid;
      final folded = foldedTableCells(denseFromControl(g, _geo4k), _geo4k);
      expect(folded, isNotEmpty);
      // Cells outside the panel are never reported.
      for (final cell in folded) {
        final column = cell % 127;
        final row = cell ~/ 127;
        expect(column, lessThan(120));
        expect(row, lessThan(75));
      }
    });

    test('a point moved inwards but not past its neighbours folds nothing', () {
      final g = moveControlSelection(
        _identity(3, 3),
        {4},
        300,
        -250,
        rangeX: 600,
        rangeY: 600,
      ).grid;
      expect(foldedControlCells(g), isEmpty);
    });
  });
}
