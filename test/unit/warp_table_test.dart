import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

const _geo4k = WarpGeometry(
  panelWidth: 3840,
  panelHeight: 2400,
  columns: 128,
  rows: 78,
  stepX: 32,
  stepY: 32,
);

/// A 3840 x 2176 panel whose table is only 61 x 31 nodes at 64 x 70 px steps,
/// so the table ends before the panel does.
const _geoCoarse = WarpGeometry(
  panelWidth: 3840,
  panelHeight: 2176,
  columns: 61,
  rows: 31,
  stepX: 64,
  stepY: 70,
);

void main() {
  group('geometry', () {
    test('the last node inside the panel', () {
      expect(_geo4k.lastInsideColumn, 120);
      expect(_geo4k.lastInsideRow, 75);
    });

    test('a table shorter than the panel ends the inside area early', () {
      expect(_geoCoarse.lastInsideColumn, 60);
      expect(_geoCoarse.lastInsideRow, 30);
    });
  });

  group('plane', () {
    test('points are addressed by column and row', () {
      final plane = WarpPlane.generate(
        name: 'W',
        columns: 4,
        rows: 3,
        point: (c, r) => (c * 10.0, r * 100.0 + c),
      );
      expect(plane.x(3, 2), 30);
      expect(plane.y(3, 2), 203);
      expect(plane.points.length, 4 * 3 * 2);
    });
  });

  group('header', () {
    test('the default single-plane header is 41 bytes', () {
      final h = defaultWarpHeader(1);
      expect(h.length, 41);
      expect(
        warpBytesToHex(h),
        '1400000000000000000000000000000000000000000000000000000000006400'
        '000001000000000021',
      );
      expect(h.last, warpHeaderLastFull);
    });

    test('the FPGA variant ends in A1', () {
      expect(defaultWarpHeader(1, last: warpHeaderLastFpga).last, 0xA1);
    });

    test('the three-plane header repeats each field for R, G and B', () {
      final h = defaultWarpHeader(3);
      expect(h.length, 121);
      final data = ByteData.sublistView(h);
      int word(int i) => data.getUint16(i * 2, Endian.little);
      for (var c = 0; c < 3; c++) {
        expect(word(0 * 3 + c), 20);
        expect(word(15 * 3 + c), 100);
        expect(word(17 * 3 + c), 1);
      }
      expect(word(1 * 3), 0);
      expect(h.last, 0x21);
    });

    test('only the last byte is replaced and a read header is preserved', () {
      final read = Uint8List.fromList(List.generate(41, (i) => i + 1));
      final changed = warpHeaderWithLast(read, 0xA1);
      expect(changed.sublist(0, 40), read.sublist(0, 40));
      expect(changed.last, 0xA1);
      expect(read.last, 41, reason: 'the input must not be modified');
    });
  });

  group('identity table', () {
    test('a single plane sits on the nominal lattice', () {
      final t = identityWarpTable(_geo4k);
      expect(t.columns, 128);
      expect(t.rows, 78);
      expect(t.planes.length, 1);
      expect(t.planes[0].name, 'W');
      expect(t.planes[0].x(127, 77), 127 * 32);
      expect(t.planes[0].y(127, 77), 77 * 32);
      expect(t.header.length, 41);
    });

    test('three planes are named R, G and B and carry the long header', () {
      final t = identityWarpTable(_geo4k, planes: 3);
      expect(t.planes.map((p) => p.name), ['R', 'G', 'B']);
      expect(t.header.length, 121);
    });
  });

  group('FPGA table from the full table', () {
    WarpTable withNode(
      WarpGeometry g,
      int column,
      int row,
      double dx,
      double dy,
    ) {
      final base = identityWarpTable(g);
      final points = Float64List.fromList(base.planes[0].points);
      points[(row * g.columns + column) * 2] += dx;
      points[(row * g.columns + column) * 2 + 1] += dy;
      return WarpTable(
        columns: g.columns,
        rows: g.rows,
        header: base.header,
        planes: [
          WarpPlane(
            name: 'W',
            columns: g.columns,
            rows: g.rows,
            points: points,
          ),
        ],
      );
    }

    test('an identity table stays identity', () {
      final full = identityWarpTable(_geo4k);
      final fpga = fpgaTableFromFull(full, _geo4k);
      expect(fpga.planes[0].points, full.planes[0].points);
    });

    test('inside the panel the table is unchanged', () {
      final full = withNode(_geo4k, 40, 20, 7.5, -3.25);
      final fpga = fpgaTableFromFull(full, _geo4k);
      expect(fpga.planes[0].x(40, 20), 40 * 32 + 7.5);
      expect(fpga.planes[0].y(40, 20), 20 * 32 - 3.25);
    });

    test(
      'columns past the panel continue the edge value plus the overshoot',
      () {
        final full = withNode(_geo4k, 120, 40, 10, 5);
        final fpga = fpgaTableFromFull(full, _geo4k);
        expect(fpga.planes[0].x(121, 40), 3840 + 10 + 32);
        expect(fpga.planes[0].y(121, 40), 40 * 32 + 5);
        expect(fpga.planes[0].x(127, 40), 3840 + 10 + 7 * 32);
      },
    );

    test('rows past the panel continue the edge value plus the overshoot', () {
      final full = withNode(_geo4k, 30, 75, 7, -3);
      final fpga = fpgaTableFromFull(full, _geo4k);
      expect(fpga.planes[0].x(30, 76), 30 * 32 + 7);
      expect(fpga.planes[0].y(30, 76), 75 * 32 - 3 + 32);
      expect(fpga.planes[0].y(30, 77), 75 * 32 - 3 + 64);
    });

    test('the corner past both edges adds both overshoots', () {
      final full = withNode(_geo4k, 120, 75, 4, 6);
      final fpga = fpgaTableFromFull(full, _geo4k);
      expect(fpga.planes[0].x(122, 77), 3840 + 4 + 64);
      expect(fpga.planes[0].y(122, 77), 2400 + 6 + 64);
    });

    test('the header keeps what was read except the last byte', () {
      final full = identityWarpTable(_geo4k);
      final read = Uint8List.fromList(List.generate(41, (i) => i + 1));
      final fpga = fpgaTableFromFull(
        WarpTable(
          columns: full.columns,
          rows: full.rows,
          header: read,
          planes: full.planes,
        ),
        _geo4k,
      );
      expect(fpga.header.sublist(0, 40), read.sublist(0, 40));
      expect(fpga.header.last, warpHeaderLastFpga);
    });

    test('a table shorter than the panel does not read past its edge', () {
      final full = identityWarpTable(_geoCoarse);
      final fpga = fpgaTableFromFull(full, _geoCoarse);
      expect(fpga.planes[0].points, full.planes[0].points);
    });

    test('every plane of a three-plane table is converted', () {
      final full = identityWarpTable(_geo4k, planes: 3);
      final fpga = fpgaTableFromFull(full, _geo4k);
      expect(fpga.planes.length, 3);
      expect(fpga.header.length, 121);
      expect(fpga.header.last, warpHeaderLastFpga);
    });
  });

  group('sampling a plane', () {
    final plane = WarpPlane.generate(
      name: 'W',
      columns: 5,
      rows: 4,
      point: (c, r) => (c * 32.0 + r, r * 32.0 + 2 * c),
    );
    const geo = WarpGeometry(
      panelWidth: 128,
      panelHeight: 96,
      columns: 5,
      rows: 4,
      stepX: 32,
      stepY: 32,
    );

    test('on a node it returns the node', () {
      final s = sampleWarpPlane(plane, 64, 32, geo);
      expect(s.x, closeTo(2 * 32 + 1, 1e-12));
      expect(s.y, closeTo(32 + 4, 1e-12));
    });

    test('between nodes it interpolates bilinearly', () {
      final s = sampleWarpPlane(plane, 48, 16, geo);
      expect(s.x, closeTo(1.5 * 32 + 0.5, 1e-12));
      expect(s.y, closeTo(0.5 * 32 + 2 * 1.5, 1e-12));
    });

    test('the far edge is sampled from the last cell', () {
      final s = sampleWarpPlane(plane, 128, 96, geo);
      expect(s.x, closeTo(4 * 32 + 3, 1e-12));
      expect(s.y, closeTo(3 * 32 + 8, 1e-12));
    });
  });
}
