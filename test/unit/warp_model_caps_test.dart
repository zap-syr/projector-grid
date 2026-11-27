import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

void main() {
  group('MIDS1 reply', () {
    test('the id is decimal and becomes a four digit hex file id', () {
      expect(warpModelIdFromMids('MIDS1=0028:00:26'), '001c_00_26');
      expect(warpModelIdFromMids('MIDS1=0022:00:26'), '0016_00_26');
      expect(warpModelIdFromMids('MIDS1=0010:00:26'), '000a_00_26');
      expect(warpModelIdFromMids('MIDS1=0005:00:22'), '0005_00_22');
      expect(warpModelIdFromMids('MIDS1=0255:03:46'), '00ff_03_46');
    });

    test('the prefix and trailing whitespace are optional', () {
      expect(warpModelIdFromMids('0028:00:26'), '001c_00_26');
      expect(warpModelIdFromMids('MIDS1=0028:00:26\r'), '001c_00_26');
      expect(warpModelIdFromMids('  MIDS1=0028:00:26 \r\n'), '001c_00_26');
    });

    test('letters in the variant fields are lower-cased', () {
      expect(warpModelIdFromMids('MIDS1=0028:0A:2B'), '001c_0a_2b');
    });

    test('anything that is not a MIDS1 reply gives null', () {
      for (final bad in [
        '',
        'MIDS1=',
        'MIDS1=0028',
        'MIDS1=0028:00',
        'MIDS1=00x8:00:26',
        'MIDS1=0028:0:26',
        'MIDS1=0028:00:260',
        'MIDS1=99999:00:26',
        'ER401',
        'garbage',
      ]) {
        expect(warpModelIdFromMids(bad), isNull, reason: bad);
      }
    });
  });

  group('lookup', () {
    test('PT-RQ25K: bits 3, 3840 x 2400, 128 x 78 step 32, range 1200', () {
      final caps = warpModelCapsFromMids('MIDS1=0028:00:26')!;
      expect(caps.id, '001c_00_26');
      expect(caps.bits, 3);
      expect(caps.panelWidth, 3840);
      expect(caps.panelHeight, 2400);
      expect(caps.tableColumns, 128);
      expect(caps.tableRows, 78);
      expect(caps.stepX, 32);
      expect(caps.stepY, 32);
      expect(caps.movableRangeX, 1200);
      expect(caps.movableRangeY, 1200);
      expect(caps.is4kFpga, isTrue);
      expect(caps.isGcx2, isFalse);
      expect(caps.isNoInverse, isTrue);
      expect(caps.fullBase, 0x70);
      expect(caps.fpgaBase, 0x80);
    });

    test('PT-RZ34KE: bits 4, 1920 x 1200, 128 x 78 step 16, range 600', () {
      final caps = warpModelCapsFromMids('MIDS1=0022:00:26')!;
      expect(caps.id, '0016_00_26');
      expect(caps.bits, 4);
      expect(caps.panelWidth, 1920);
      expect(caps.panelHeight, 1200);
      expect(caps.tableColumns, 128);
      expect(caps.tableRows, 78);
      expect(caps.stepX, 16);
      expect(caps.stepY, 16);
      expect(caps.movableRangeX, 600);
      expect(caps.movableRangeY, 600);
      expect(caps.is4kFpga, isFalse);
      expect(caps.isNoInverse, isTrue);
      expect(caps.fullBase, 0x40);
      expect(caps.fpgaBase, 0x50);
    });

    test('the geometry of a row feeds the table functions', () {
      final geometry = warpModelCapsFromMids('MIDS1=0022:00:26')!.geometry;
      expect(geometry.panelWidth, 1920);
      expect(geometry.columns, 128);
      expect(geometry.stepY, 16);
      expect(geometry.lastInsideColumn, 120);
      expect(geometry.lastInsideRow, 75);
    });

    test('an unknown id or variant has no row', () {
      expect(warpModelCapsFromMids('MIDS1=0999:00:26'), isNull);
      expect(warpModelCapsFromMids('MIDS1=0028:09:99'), isNull);
      expect(warpModelCapsFromMids('nonsense'), isNull);
      expect(lookupWarpModelCaps('ffff_00_00'), isNull);
    });

    test('a variant of the same model id is a separate row', () {
      expect(warpModelCapsFromMids('MIDS1=0021:00:26')!.id, '0015_00_26');
      expect(warpModelCapsFromMids('MIDS1=0021:01:26')!.id, '0015_01_26');
      expect(warpModelCapsFromMids('MIDS1=0021:02:26')!.id, '0015_02_26');
    });

    test('the anomaly row 0039 is a WUXGA panel with bits 3', () {
      final caps = warpModelCapsFromMids('MIDS1=0039:00:26')!;
      expect(caps.id, '0027_00_26');
      expect(caps.bits, 3, reason: 'never inferred from the panel size');
      expect(caps.panelWidth, 1920);
      expect(caps.panelHeight, 1200);
      expect(caps.stepX, 16);
      expect(caps.movableRangeX, 600);
    });

    test('other classes of the table keep their own geometry', () {
      final uhd = lookupWarpModelCaps('0018_00_30')!;
      expect((uhd.bits, uhd.panelWidth, uhd.panelHeight), (4, 3840, 2176));
      expect(
        (uhd.tableColumns, uhd.tableRows, uhd.movableRangeX),
        (128, 69, 800),
      );

      final coarse = lookupWarpModelCaps('001b_00_24')!;
      expect((coarse.tableColumns, coarse.tableRows), (61, 31));
      expect(
        (coarse.stepX, coarse.stepY, coarse.movableRangeX),
        (64, 70, 1200),
      );

      final cinema = lookupWarpModelCaps('0010_00_29')!;
      expect(
        (cinema.bits, cinema.panelWidth, cinema.panelHeight),
        (3, 4096, 2160),
      );
      expect((cinema.tableColumns, cinema.tableRows), (129, 69));

      final qhd = lookupWarpModelCaps('0026_00_24')!;
      expect((qhd.panelWidth, qhd.panelHeight), (2560, 1440));
      expect((qhd.tableColumns, qhd.tableRows), (88, 52));

      final sxga = lookupWarpModelCaps('0005_00_22')!;
      expect((sxga.panelWidth, sxga.panelHeight, sxga.bits), (1408, 1056, 4));
    });
  });

  group('binary model id', () {
    test('two 2-char fields after 020185 give the file id', () {
      expect(warpModelIdFromBinaryModelInfo('0201855A2803'), '5a_00_28');
      expect(warpModelIdFromBinaryModelInfo('020185552603'), '55_00_26');
      expect(warpModelIdFromBinaryModelInfo('020185552203'), '55_00_22');
    });

    test('the reply prefix and letter case do not matter', () {
      expect(warpModelIdFromBinaryModelInfo('01020185 5a 28 03'), '5a_00_28');
      expect(warpModelIdFromBinaryModelInfo('0201855c4803'), '5c_00_48');
    });

    test('the ids are only lower-cased, never converted', () {
      expect(warpModelIdFromBinaryModelInfo('0201856E2603'), '6e_00_26');
      expect(warpModelIdFromBinaryModelInfo('020185592203'), '59_00_22');
    });

    test('replies that do not carry the marker give null', () {
      expect(warpModelIdFromBinaryModelInfo(''), isNull);
      expect(warpModelIdFromBinaryModelInfo('0200FF8B03'), isNull);
      expect(warpModelIdFromBinaryModelInfo('020185'), isNull);
      expect(warpModelIdFromBinaryModelInfo('020185ZZ2603'), isNull);
    });

    test('rows are found through the binary form', () {
      final gcx2 = warpModelCapsFromBinaryModelInfo('0201855A2803')!;
      expect(gcx2.bits, 2);
      expect((gcx2.panelWidth, gcx2.panelHeight), (3840, 1920));
      expect((gcx2.tableColumns, gcx2.tableRows), (121, 76));
      expect(gcx2.isGcx2, isTrue);
      expect(gcx2.fullBase, 0x70);
      expect(gcx2.fpgaBase, 0x80);
      expect(warpModelCapsFromBinaryModelInfo('020185FF2603'), isNull);
    });
  });

  group('the generated table', () {
    test('has one row per parameter file', () {
      expect(warpModelCapsTable.length, 70);
    });

    test('every row is stored under its own id', () {
      warpModelCapsTable.forEach((key, caps) {
        expect(caps.id, key);
        expect(
          key,
          matches(RegExp(r'^[0-9a-f]{2,4}_[0-9a-z]{2}_[0-9a-z]{2}$')),
        );
      });
    });

    test('rows are consistent', () {
      for (final caps in warpModelCapsTable.values) {
        expect([2, 3, 4], contains(caps.bits), reason: caps.id);
        expect(caps.panelWidth, greaterThan(0), reason: caps.id);
        expect(caps.tableColumns, greaterThanOrEqualTo(2), reason: caps.id);
        expect(caps.stepX, greaterThan(0), reason: caps.id);
        expect(caps.movableRangeX, greaterThan(0), reason: caps.id);
        // The table must reach at least the middle of the panel.
        expect(
          (caps.tableColumns - 1) * caps.stepX,
          greaterThan(caps.panelWidth ~/ 2),
          reason: caps.id,
        );
      }
    });

    test('the table base follows the 4K FPGA and GCX2 flags', () {
      for (final caps in warpModelCapsTable.values) {
        final wide = caps.is4kFpga || caps.isGcx2;
        expect(caps.fullBase, wide ? 0x70 : 0x40, reason: caps.id);
        expect(caps.fpgaBase, wide ? 0x80 : 0x50, reason: caps.id);
      }
    });

    test('no row asks for a table base that is not in the protocol', () {
      for (final caps in warpModelCapsTable.values) {
        expect([0x40, 0x70], contains(caps.fullBase));
        expect([0x50, 0x80], contains(caps.fpgaBase));
      }
    });

    test('the two verified models are in the table', () {
      expect(lookupWarpModelCaps('001c_00_26'), isNotNull);
      expect(lookupWarpModelCaps('0016_00_26'), isNotNull);
    });
  });

  group('geometry', () {
    test('a row provides the geometry the table functions need', () {
      final g = lookupWarpModelCaps('001c_00_26')!.geometry;
      expect(
        g,
        isA<WarpGeometry>()
            .having((x) => x.panelWidth, 'panelWidth', 3840)
            .having((x) => x.panelHeight, 'panelHeight', 2400)
            .having((x) => x.columns, 'columns', 128)
            .having((x) => x.rows, 'rows', 78)
            .having((x) => x.stepX, 'stepX', 32),
      );
    });
  });
}
