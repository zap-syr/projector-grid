import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/warp/$name').readAsStringSync())
        as Map<String, Object?>;

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

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

WarpGeometry _geometryFor(int bits) => bits == 4 ? _geoWuxga : _geo4k;

int _bytesPerRow(WarpEncoding encoding, int columns) => switch (encoding) {
  WarpEncoding.triple => columns * 6,
  WarpEncoding.delta => 4 + (columns - 1) * 2,
  WarpEncoding.word || WarpEncoding.fpga64 => columns * 4,
};

/// A block holding a single table row, so one real row can be decoded alone.
Uint8List _singleRowBlock(Map<String, Object?> table, Uint8List row) =>
    Uint8List.fromList([
      table['columns']! as int,
      1,
      ...warpHexToBytes(table['header']! as String),
      ...row,
    ]);

WarpEncoding _encodingOf(Map<String, Object?> table) =>
    WarpEncoding.values.byName(table['encoding']! as String);

/// A table of the given geometry with every row on the nominal lattice,
/// except the rows replaced by [rows] (decoded from real stored bytes).
WarpTable _tableWithRealRows(
  Map<String, Object?> source,
  WarpGeometry geometry,
) {
  final bits = source['bits']! as int;
  final encoding = _encodingOf(source);
  final rowHex = (source['rowHex']! as Map<String, Object?>);
  final base = identityWarpTable(geometry);
  final points = Float64List.fromList(base.planes[0].points);
  rowHex.forEach((rowKey, hex) {
    final row = int.parse(rowKey);
    final decoded = decodeTable(
      _singleRowBlock(source, warpHexToBytes(hex! as String)),
      encoding,
      bits,
    );
    for (var c = 0; c < geometry.columns; c++) {
      points[(row * geometry.columns + c) * 2] = decoded.planes[0].x(c, 0);
      points[(row * geometry.columns + c) * 2 + 1] = decoded.planes[0].y(c, 0);
    }
  });
  return WarpTable(
    columns: geometry.columns,
    rows: geometry.rows,
    header: warpHexToBytes(source['header']! as String),
    planes: [
      WarpPlane(
        name: 'W',
        columns: geometry.columns,
        rows: geometry.rows,
        points: points,
      ),
    ],
  );
}

int _independentChecksum(Uint8List frame) {
  // frame = 02 00 A9 C0 size(2) type method loc data... cs 03
  var sum = frame[6] + frame[7] + frame[8];
  for (var i = 9; i < frame.length - 2; i++) {
    sum += frame[i];
  }
  return sum & 0xFF;
}

String _hex(Uint8List bytes) => warpBytesToHex(bytes);

void main() {
  final codec = _fixture('codec_vectors.json');
  final tables = {
    for (final t in (_fixture('store_tables.json')['tables']! as List))
      (t as Map<String, Object?>)['name']! as String: t,
  };

  group('rounding and scalar codecs', () {
    test('warpRound rounds half away from zero', () {
      expect(warpRound(0.5 / 4096, 4096), 1);
      expect(warpRound(-0.5 / 4096, 4096), -1);
      expect(warpRound(0.4 / 4096, 4096), 0);
      expect(warpRound(2.5, 1), 3);
      expect(warpRound(-2.5, 1), -3);
    });

    for (final entry in codec['scalarCodecs']! as List) {
      final row = entry as List;
      final kind = row[0] as String;
      final bits = row[1] as int;
      final value = (row[2] as num).toDouble();
      final bytes = row[3] as String;
      final decoded = (row[4] as num).toDouble();
      test('$kind bits $bits: $value <-> $bytes', () {
        final length = bytes.length ~/ 2;
        final buffer = Uint8List(length);
        switch (kind) {
          case 'triple':
            encodeTriple(value, bits, buffer, 0);
            expect(_hex(buffer), bytes);
            expect(decodeTriple(warpHexToBytes(bytes), 0, bits), decoded);
          case 'word':
            encodeWord(value, bits, buffer, 0);
            expect(_hex(buffer), bytes);
            expect(decodeWord(warpHexToBytes(bytes), 0, bits), decoded);
          case 'fpga64':
            encodeFpga64(value, buffer, 0);
            expect(_hex(buffer), bytes);
            expect(decodeFpga64Raw(warpHexToBytes(bytes), 0), decoded);
          default:
            fail('unknown codec $kind');
        }
      });
    }

    test('bits 4 triples split the sign at 3072 px', () {
      expect(decodeTriple(warpHexToBytes('BFFFFF'), 0, 4), closeTo(3071.9, .1));
      expect(decodeTriple(warpHexToBytes('C00000'), 0, 4), -1024);
      expect(decodeTriple(warpHexToBytes('DA8000'), 0, 4), -600);
    });

    test('bits 4 words split the sign at 3072 px', () {
      expect(decodeWord(warpHexToBytes('FFBF'), 0, 4), closeTo(3071.9, .1));
      expect(decodeWord(warpHexToBytes('00C0'), 0, 4), -1024);
    });

    test('encoders refuse values the format cannot hold', () {
      final b3 = Uint8List(3);
      final b2 = Uint8List(2);
      expect(() => encodeTriple(3072, 4, b3, 0), throwsArgumentError);
      expect(() => encodeTriple(-1025, 4, b3, 0), throwsArgumentError);
      expect(() => encodeTriple(32768, 3, b3, 0), throwsArgumentError);
      expect(() => encodeTriple(1, 2, b3, 0), throwsArgumentError);
      expect(() => encodeWord(6144, 3, b2, 0), throwsArgumentError);
      expect(() => encodeWord(-2049, 3, b2, 0), throwsArgumentError);
      expect(() => encodeWord(-1, 2, b2, 0), throwsArgumentError);
      expect(() => encodeWord(1, 5, b2, 0), throwsArgumentError);
    });

    test('fpga64 values are unwrapped by continuity', () {
      expect(unwrapFpga64(0.5, 1023), closeTo(1024.5, 1e-9));
      expect(unwrapFpga64(1000, 20), closeTo(-24, 1e-9));
      expect(unwrapFpga64(100, 120), 100);
    });
  });

  group('frames and wire', () {
    for (final entry in codec['frames']! as List) {
      final frame = entry as Map<String, Object?>;
      test(frame['name']! as String, () {
        final Uint8List built;
        if (frame.containsKey('data')) {
          built = buildWriteFrame(
            frame['type']! as int,
            frame['method']! as int,
            frame['location']! as int,
            warpHexToBytes(frame['data']! as String),
          );
        } else if (frame.containsKey('top')) {
          built = buildReadFrame(
            frame['type']! as int,
            top: frame['top']! as bool,
          );
        } else {
          built = buildSaveFrame(
            WarpSlot.values.byName(frame['slot']! as String),
          );
        }
        expect(_hex(built), frame['frame']);
      });
    }

    test('type codes add slot and the separate-colour flag to the base', () {
      expect(warpTypeCode(0x70, WarpSlot.pc2), 0x74);
      expect(warpTypeCode(0x80, WarpSlot.pc3), 0x86);
      expect(warpTypeCode(0x40, WarpSlot.ram), 0x40);
      expect(warpTypeCode(0x40, WarpSlot.pc1, separateRgb: true), 0x43);
    });

    test('binary command body is 01 followed by upper-case hex', () {
      final wire = (codec['wire']! as List)[0] as Map<String, Object?>;
      expect(
        warpBinaryCommandBody(warpHexToBytes(wire['bytes']! as String)),
        wire['body'],
      );
    });

    test('binary reply is stripped of its prefix and hex decoded', () {
      final wire = (codec['wire']! as List)[0] as Map<String, Object?>;
      expect(
        _hex(parseWarpBinaryReply(wire['replyLine']! as String)),
        wire['replyBytes'],
      );
    });

    test('an FF frame is an error with its code', () {
      final wire = (codec['wire']! as List)[1] as Map<String, Object?>;
      expect(
        () => parseWarpBinaryReply(wire['replyLine']! as String),
        throwsA(
          isA<WarpProtocolException>().having(
            (e) => e.code,
            'code',
            wire['errorCode'],
          ),
        ),
      );
      expect(warpErrorMeaning(0x8B), contains('no data'));
    });

    test('an ASCII error reply is an error without a code', () {
      final wire = (codec['wire']! as List)[2] as Map<String, Object?>;
      expect(
        () => parseWarpBinaryReply(wire['replyLine']! as String),
        throwsA(
          isA<WarpProtocolException>().having((e) => e.code, 'code', isNull),
        ),
      );
    });

    test('garbage replies are rejected', () {
      expect(() => parseWarpBinaryReply('01ZZ'), throwsFormatException);
      expect(() => parseWarpBinaryReply('010'), throwsFormatException);
    });

    test('write acknowledgements', () {
      checkWriteAck(warpHexToBytes('0200A9C00003'));
      expect(
        () => checkWriteAck(warpHexToBytes('0200A9C08B03')),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(
        () => checkWriteAck(warpHexToBytes('0200AAE10003')),
        throwsA(isA<WarpProtocolException>()),
      );
    });
  });

  group('read reply', () {
    final spec = codec['readReply']! as Map<String, Object?>;

    /// The captured reply is a regular run of identity points; rebuilding it
    /// from the formula and matching the digest proves the formula is the
    /// captured data.
    String rebuiltLine() {
      String hex3(int v) => v.toRadixString(16).toUpperCase().padLeft(6, '0');
      final data = StringBuffer();
      for (var r = 74; r <= 77; r++) {
        for (var c = 0; c < 128; c++) {
          if (r == 74 && c < 69) continue;
          data
            ..write(hex3(c * 16 * 4096))
            ..write(hex3(r * 16 * 4096));
        }
      }
      final dataBytes = warpHexToBytes(data.toString());
      var sum = 0x72 + 0 + 2;
      for (final b in dataBytes) {
        sum += b;
      }
      final size = 3 + dataBytes.length;
      return '01'
          '0200A8C0${size.toRadixString(16).toUpperCase().padLeft(4, '0')}'
          '720002${data.toString()}'
          '${(sum & 0xFF).toRadixString(16).toUpperCase().padLeft(2, '0')}03';
    }

    test('the rebuilt line is the captured one', () {
      final line = rebuiltLine();
      expect(line.length, spec['lineLength']);
      expect(_sha(utf8.encode(line)), spec['lineSha256']);
    });

    test('fields and checksum are parsed', () {
      final reply = parseReadReply(parseWarpBinaryReply(rebuiltLine()));
      expect(reply.size, spec['size']);
      expect(reply.type, spec['type']);
      expect(reply.method, spec['method']);
      expect(reply.location, spec['location']);
      expect(reply.data.length, spec['dataLength']);
      expect(reply.checksumOk, spec['checksumOk']);
    });

    test('a corrupted byte fails the checksum', () {
      final bytes = parseWarpBinaryReply(rebuiltLine());
      bytes[20] ^= 0x01;
      expect(parseReadReply(bytes).checksumOk, isFalse);
    });

    test('short or foreign replies are rejected', () {
      expect(
        () => parseReadReply(warpHexToBytes('0200A8C00003')),
        throwsFormatException,
      );
      expect(
        () => parseReadReply(warpHexToBytes('0200A9C0000000000000000003')),
        throwsFormatException,
      );
      final truncated = parseWarpBinaryReply(rebuiltLine()).sublist(0, 100);
      expect(() => parseReadReply(truncated), throwsFormatException);
    });
  });

  group('store tables stored by Panasonic software', () {
    for (final name in tables.keys) {
      final table = tables[name]!;
      final encoding = _encodingOf(table);
      final bits = table['bits']! as int;
      final geometry = _geometryFor(bits);
      final frames = table['frames']! as Map<String, Object?>;

      test('$name: frame layout of a full chunked write', () {
        final identity = identityWarpTable(geometry);
        final withHeader = WarpTable(
          columns: identity.columns,
          rows: identity.rows,
          header: warpHexToBytes(table['header']! as String),
          planes: identity.planes,
        );
        final encoded = encodeTable(withHeader, encoding, bits);
        final built = chunkWrite(
          table['type']! as int,
          table['method']! as int,
          encoded.head,
          encoded.points,
        );
        expect(built.length, frames['count']);
        expect(built.first.length, frames['fullLength']);
        expect(built[1].length, frames['fullLength']);
        expect(built.last.length, frames['lastLength']);
        expect(_hex(built.first.sublist(0, 9)), frames['firstPrefix']);
        expect(_hex(built[1].sublist(0, 9)), frames['middlePrefix']);
        expect(_hex(built.last.sublist(0, 9)), frames['lastPrefix']);
        for (final f in built) {
          expect(f.last, 0x03);
          expect(f[f.length - 2], _independentChecksum(f));
          expect((f[4] << 8) | f[5], f.length - 11 + 3);
        }
      });

      if (table.containsKey('rowHex')) {
        final rowHex = table['rowHex']! as Map<String, Object?>;
        rowHex.forEach((rowKey, hex) {
          test('$name: row $rowKey decodes and encodes back byte for byte', () {
            final bytes = warpHexToBytes(hex! as String);
            final decoded = decodeTable(
              _singleRowBlock(table, bytes),
              encoding,
              bits,
            );
            expect(decoded.columns, 128);
            expect(decoded.rows, 1);
            expect(_hex(decoded.header), table['header']);
            final again = encodeTable(decoded, encoding, bits);
            expect(_hex(again.points), hex);
            expect(again.points.length, _bytesPerRow(encoding, 128));
          });
        });
      }

      if (table.containsKey('rowSha256')) {
        final source = tables[table['source']]!;
        final shas = table['rowSha256']! as Map<String, Object?>;
        test('$name: delta rows rebuilt from the stored full table', () {
          final full = _tableWithRealRows(source, geometry);
          final fpga = fpgaTableFromFull(full, geometry);
          expect(fpgaDeltaFits(fpga.planes[0]).ok, isTrue);
          final encoded = encodeTable(fpga, WarpEncoding.delta, bits);
          final rowBytes = _bytesPerRow(WarpEncoding.delta, 128);
          shas.forEach((rowKey, sha) {
            final row = int.parse(rowKey);
            expect(
              _sha(
                encoded.points.sublist(row * rowBytes, (row + 1) * rowBytes),
              ),
              sha,
              reason: 'row $row',
            );
          });
        });
      }
    }

    test('store_4k_full row 0 holds the stored values', () {
      final table = tables['store_4k_full']!;
      final hex = (table['rowHex']! as Map)['0']! as String;
      final decoded = decodeTable(
        _singleRowBlock(table, warpHexToBytes(hex)),
        WarpEncoding.triple,
        3,
      );
      expect(decoded.planes[0].x(0, 0), 265.484375);
      expect(decoded.planes[0].y(0, 0), 126.96875);
      expect(decoded.planes[0].x(1, 0), 293.0625);
      expect(decoded.planes[0].y(1, 0), 124.859375);
    });

    test('ram_preview_4k_fpga64 row 0 unwraps across the 1024 px wraps', () {
      final table = tables['ram_preview_4k_fpga64']!;
      final hex = (table['rowHex']! as Map)['0']! as String;
      final decoded = decodeTable(
        _singleRowBlock(table, warpHexToBytes(hex)),
        WarpEncoding.fpga64,
        3,
      );
      for (final v in table['rowValues']! as List) {
        final c = (v as List)[0] as int;
        expect(decoded.planes[0].x(c, 0), (v[1] as num).toDouble());
        expect(decoded.planes[0].y(c, 0), (v[2] as num).toDouble());
      }
    });

    test('a read of a never-written slot is the identity table', () {
      final spec = codec['identityBlock']! as Map<String, Object?>;
      final data = ByteData(2 + 41 + 128 * 78 * 4);
      data
        ..setUint8(0, 128)
        ..setUint8(1, 78);
      var offset = 2 + 41;
      for (var r = 0; r < 78; r++) {
        for (var c = 0; c < 128; c++) {
          data
            ..setUint16(offset, c * 32 * 8, Endian.little)
            ..setUint16(offset + 2, r * 32 * 8, Endian.little);
          offset += 4;
        }
      }
      final block = data.buffer.asUint8List();
      expect(block.length, spec['length']);
      expect(_sha(block), spec['sha256']);

      final decoded = decodeTable(block, WarpEncoding.word, 3);
      expect(decoded.columns, 128);
      expect(decoded.rows, 78);
      expect(decoded.header.every((b) => b == 0), isTrue);
      expect(decoded.planes[0].x(127, 77), 127 * 32);
      expect(decoded.planes[0].y(127, 77), 77 * 32);
      expect(decoded.planes[0].x(5, 9), 5 * 32);
      expect(decoded.planes[0].y(5, 9), 9 * 32);
    });
  });

  group('table codec round trips', () {
    WarpTable synthetic(int planes, int step) {
      const gx = 121;
      const gy = 76;
      return WarpTable(
        columns: gx,
        rows: gy,
        header: defaultWarpHeader(planes),
        planes: [
          for (var p = 0; p < planes; p++)
            WarpPlane.generate(
              name: planes == 1 ? 'W' : 'RGB'[p],
              columns: gx,
              rows: gy,
              point: (c, r) => (
                c * step + 10 + 0.37 * p + math.sin(c + r) * 3.3,
                r * step + 10 - 0.21 * p + math.cos(c * r) * 2.7,
              ),
            ),
        ],
      );
    }

    final cases = <(WarpEncoding, int, int, int, double)>[
      (WarpEncoding.triple, 4, 1, 16, 0.5 / 4096),
      (WarpEncoding.triple, 3, 3, 32, 0.5 / 256),
      (WarpEncoding.word, 4, 1, 16, 0.5 / 16),
      (WarpEncoding.word, 3, 3, 32, 0.5 / 8),
      (WarpEncoding.word, 2, 1, 32, 0.5 / 4),
      (WarpEncoding.fpga64, 3, 1, 32, 0.5 / 64),
      (WarpEncoding.delta, 3, 1, 32, 0.125),
      (WarpEncoding.delta, 4, 3, 16, 0.125),
    ];
    for (final (encoding, bits, planes, step, tolerance) in cases) {
      test('${encoding.name} bits $bits, $planes plane(s)', () {
        final table = synthetic(planes, step);
        final encoded = encodeTable(table, encoding, bits);
        expect(encoded.separateRgb, planes == 3);
        final block = Uint8List.fromList([...encoded.head, ...encoded.points]);
        final back = decodeTable(block, encoding, bits);
        expect(back.columns, table.columns);
        expect(back.rows, table.rows);
        expect(back.header, table.header);
        expect(back.planes.map((p) => p.name), table.planes.map((p) => p.name));
        var worst = 0.0;
        for (var p = 0; p < planes; p++) {
          for (var i = 0; i < table.planes[p].points.length; i++) {
            worst = math.max(
              worst,
              (table.planes[p].points[i] - back.planes[p].points[i]).abs(),
            );
          }
        }
        expect(worst, lessThanOrEqualTo(tolerance + 1e-9));
      });
    }

    test(
      'a 3-plane block is told apart from a 1-plane block by its length',
      () {
        final one = encodeTable(synthetic(1, 16), WarpEncoding.triple, 4);
        final three = encodeTable(synthetic(3, 16), WarpEncoding.triple, 4);
        expect(one.head.length, 2 + 41);
        expect(three.head.length, 2 + 121);
        expect(three.points.length, 3 * one.points.length);
      },
    );

    test('3-plane tables chunk with the larger first-packet limit', () {
      final encoded = encodeTable(synthetic(3, 16), WarpEncoding.triple, 4);
      final frames = chunkWrite(0x43, 0x10, encoded.head, encoded.points);
      expect(frames.first.length - 11, 0x1000);
      expect(frames.first[8], 1);
      expect(frames.last[8], 2);
      expect(frames[1][8], 0);
    });

    test('malformed tables and blocks are rejected', () {
      final table = synthetic(1, 16);
      expect(
        () => encodeTable(
          WarpTable(
            columns: table.columns,
            rows: table.rows,
            header: Uint8List(40),
            planes: table.planes,
          ),
          WarpEncoding.triple,
          4,
        ),
        throwsArgumentError,
      );
      expect(
        () => decodeTable(Uint8List(100), WarpEncoding.triple, 4),
        throwsFormatException,
      );
      expect(
        () => decodeTable(Uint8List(1), WarpEncoding.triple, 4),
        throwsFormatException,
      );
    });

    test('a table frame set is built from a type code and an encoding', () {
      final table = synthetic(1, 16);
      final encoded = encodeTable(table, WarpEncoding.triple, 4);
      expect(
        tableWriteFrames(
          table,
          type: 0x46,
          encoding: WarpEncoding.triple,
          bits: 4,
        ).map(_hex),
        chunkWrite(0x46, 0x10, encoded.head, encoded.points).map(_hex),
      );
      final delta = tableWriteFrames(
        table,
        type: 0x56,
        encoding: WarpEncoding.delta,
        bits: 4,
      );
      expect(delta.first[7], 0x00);
    });
  });

  group('delta format limits', () {
    WarpPlane rowPlane(List<(double, double)> row) => WarpPlane.generate(
      name: 'W',
      columns: row.length,
      rows: 1,
      point: (c, r) => row[c],
    );

    test('regular steps fit', () {
      final plane = rowPlane([for (var c = 0; c < 10; c++) (c * 32.0, 5.0)]);
      expect(fpgaDeltaFits(plane).ok, isTrue);
    });

    test('a step of 63.75 px fits and 64 px does not', () {
      expect(fpgaDeltaFits(rowPlane([(0, 0), (63.75, 0)])).ok, isTrue);
      final fit = fpgaDeltaFits(rowPlane([(0, 0), (10, 0), (74, 0)]));
      expect(fit.ok, isFalse);
      expect(fit.column, 2);
      expect(fit.dx, 64);
    });

    test('a negative step (a folded row) does not fit', () {
      final fit = fpgaDeltaFits(rowPlane([(0, 0), (30, 0), (20, 0)]));
      expect(fit.ok, isFalse);
      expect(fit.dx, -10);
    });

    test('vertical steps are limited to -32 .. 31.75 px', () {
      expect(fpgaDeltaFits(rowPlane([(0, 0), (30, 31.75)])).ok, isTrue);
      expect(fpgaDeltaFits(rowPlane([(0, 0), (30, 32)])).ok, isFalse);
      expect(fpgaDeltaFits(rowPlane([(0, 0), (30, -32)])).ok, isTrue);
      expect(fpgaDeltaFits(rowPlane([(0, 0), (30, -32.25)])).ok, isFalse);
    });

    test('the delta encoder refuses a step that does not fit', () {
      final table = WarpTable(
        columns: 2,
        rows: 1,
        header: defaultWarpHeader(1),
        planes: [
          rowPlane([(0, 0), (100, 0)]),
        ],
      );
      expect(
        () => encodeTable(table, WarpEncoding.delta, 4),
        throwsArgumentError,
      );
    });

    test('an FPGA table is encoded as deltas when it fits, else as words', () {
      final good = fpgaTableFromFull(identityWarpTable(_geoWuxga), _geoWuxga);
      expect(fpgaEncodingFor(good), WarpEncoding.delta);
      final points = Float64List.fromList(good.planes[0].points);
      points[(5 * 128 + 60) * 2] += 300;
      final bad = WarpTable(
        columns: good.columns,
        rows: good.rows,
        header: good.header,
        planes: [WarpPlane(name: 'W', columns: 128, rows: 78, points: points)],
      );
      expect(fpgaEncodingFor(bad), WarpEncoding.word);
    });
  });

  group('encodable range', () {
    WarpTable tableWith(double x) => WarpTable(
      columns: 2,
      rows: 1,
      header: defaultWarpHeader(1),
      planes: [
        WarpPlane.generate(
          name: 'W',
          columns: 2,
          rows: 1,
          point: (c, r) => (c == 1 ? x : 0.0, 0.0),
        ),
      ],
    );

    test('bits 4 holds -1024 up to but excluding 3072', () {
      expect(checkWarpEncodable(tableWith(-1024), 4).ok, isTrue);
      expect(checkWarpEncodable(tableWith(3071.9), 4).ok, isTrue);
      final over = checkWarpEncodable(tableWith(3072), 4);
      expect(over.ok, isFalse);
      expect(over.badCount, 1);
      expect(over.firstColumn, 1);
      expect(over.firstRow, 0);
      expect(checkWarpEncodable(tableWith(-1025), 4).ok, isFalse);
    });

    test('bits 3 holds -2048 up to but excluding 6144', () {
      expect(checkWarpEncodable(tableWith(-2048), 3).ok, isTrue);
      expect(checkWarpEncodable(tableWith(6143), 3).ok, isTrue);
      expect(checkWarpEncodable(tableWith(6144), 3).ok, isFalse);
    });

    test('the reader limit warning applies to bits 4 below -512 only', () {
      expect(warpLegacyReaderLimit(4), -512);
      expect(warpLegacyReaderLimit(3), isNull);
      expect(warpLegacyReaderLimit(2), isNull);
      expect(tableBreaksLegacyReader(tableWith(-512), 4), isFalse);
      expect(tableBreaksLegacyReader(tableWith(-512.5), 4), isTrue);
      expect(tableBreaksLegacyReader(tableWith(-600), 4), isTrue);
      expect(tableBreaksLegacyReader(tableWith(-3000), 3), isFalse);
    });
  });
}
