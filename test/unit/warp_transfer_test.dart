import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/warp_transfer.dart';
import 'package:projector_grid/features/workspace/domain/geometry_overlay.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

import '../helpers/fake_warp_projector.dart';

final WarpModelCaps _caps4k = lookupWarpModelCaps('001c_00_26')!;
final WarpModelCaps _capsWuxga = lookupWarpModelCaps('0016_00_26')!;

String _hex(List<int> bytes) => warpBytesToHex(bytes);

/// The prefix of a WRITE frame as the fixtures list it: nine bytes.
String _prefix(Uint8List frame) => _hex(frame.sublist(0, 9));

Map<String, Map<String, Object?>> _fixtureTables() {
  final json = jsonDecode(
    File('test/fixtures/warp/store_tables.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final t in json['tables']! as List)
      (t as Map<String, Object?>)['name']! as String: t,
  };
}

/// A table with every node on its nominal position.
WarpTable _identity(WarpModelCaps caps, {int planes = 1}) =>
    identityWarpTable(caps.geometry, planes: planes);

/// [table] with [dx] added to x of node ([column], [row]) in every plane.
WarpTable _shifted(
  WarpTable table, {
  required int column,
  required int row,
  required double dx,
}) {
  return WarpTable(
    columns: table.columns,
    rows: table.rows,
    header: table.header,
    planes: [
      for (final p in table.planes)
        WarpPlane(
          name: p.name,
          columns: p.columns,
          rows: p.rows,
          points: (Float64List.fromList(p.points)
            ..[(row * p.columns + column) * 2] += dx),
        ),
    ],
  );
}

/// The WRITE frames of [link] (type, method, location), in order.
List<(int, int, int)> _writes(MemoryWarpLink link) => [
  for (final f in link.projector.frames)
    if (f[2] == 0xA9 && f[3] == 0xC0) (f[6], f[7], f[8]),
];

/// The log as text: a frame as hex, a command as it is.
List<String> _describe(MemoryWarpLink link) => [
  for (final e in link.log) e is Uint8List ? _hex(e) : e as String,
];

Future<WarpStoreResult> _store(
  WarpLink link, {
  WarpSlot slot = WarpSlot.pc1,
  WarpModelCaps? caps,
  WarpTable? full,
  Uint8List? readHeader,
  DateTime? now,
  WarpProgress? onProgress,
}) {
  final c = caps ?? _caps4k;
  return storeWarpMemory(
    link,
    slot: slot,
    caps: c,
    full: full ?? _identity(c),
    readHeader: readHeader,
    gridColumns: 9,
    gridRows: 5,
    now: now ?? DateTime.utc(2026, 11, 28, 9, 30, 5),
    onProgress: onProgress,
  );
}

/// A link that answers every READ with the same packet.
class _EndlessLink implements WarpLink {
  _EndlessLink(this.packet);

  final Uint8List packet;
  int calls = 0;

  @override
  Future<Uint8List> binary(Uint8List frame) async {
    calls++;
    return packet;
  }

  @override
  Future<String?> ascii(String command) async => null;
}

Uint8List _readPacket(int type, int location, List<int> data) {
  final bytes = Uint8List.fromList(data);
  final size = 3 + bytes.length;
  return Uint8List.fromList([
    0x02,
    0x00,
    0xA8,
    0xC0,
    size >> 8,
    size & 0xFF,
    type,
    0,
    location,
    ...bytes,
    warpChecksum(type, 0, location, bytes),
    0x03,
  ]);
}

Uint8List _block(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 7 + 3) & 0xFF]);

void main() {
  group('ack checks', () {
    test('SAVE ack names the memory and needs status 0', () {
      final ok = warpHexToBytes('0200AAE20003');
      checkSaveAck(ok, WarpSlot.pc2);
      expect(
        () => checkSaveAck(ok, WarpSlot.pc3),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(
        () => checkSaveAck(warpHexToBytes('0200AAE20103'), WarpSlot.pc2),
        throwsA(isA<WarpProtocolException>().having((e) => e.code, 'code', 1)),
      );
      checkSaveAck(warpHexToBytes('0200AAE00003'), WarpSlot.ram);
    });

    test('cursor and grid acks', () {
      checkCursorAck(warpHexToBytes('0200AC070003'));
      checkGridOverlayAck(warpHexToBytes('0200AB070003'));
      expect(
        () => checkCursorAck(warpHexToBytes('0200AB070003')),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(
        () => checkGridOverlayAck(warpHexToBytes('0200AB070103')),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(
        () => checkCursorAck(warpHexToBytes('0200AC07')),
        throwsA(isA<WarpProtocolException>()),
      );
    });
  });

  group('readWarpBlock', () {
    test('a block that fits one packet is one read', () async {
      final link = MemoryWarpLink()..projector.setBlock(0x72, _block(4096));
      final result = await readWarpBlock(link, type: 0x72);
      expect(result, isA<WarpBlockRead>());
      expect((result as WarpBlockRead).block, _block(4096));
      expect(link.projector.frames, hasLength(1));
      expect(
        _hex(link.projector.frames.single),
        _hex(buildReadFrame(0x72, top: true)),
      );
    });

    test('packets are joined and the read stops at location 2', () async {
      final link = MemoryWarpLink()..projector.setBlock(0x72, _block(10000));
      final result = await readWarpBlock(link, type: 0x72) as WarpBlockRead;
      expect(result.block, _block(10000));
      expect(link.projector.frames.map((f) => f[5]), [1, 0, 0]);
    });

    test('the method byte of the first packet is returned', () async {
      final link = MemoryWarpLink()
        ..projector.readMethod = 0x10
        ..projector.setBlock(0x72, _block(10));
      final result = await readWarpBlock(link, type: 0x72) as WarpBlockRead;
      expect(result.method, 0x10);
    });

    test(
      'FF 8B on the first packet is "not available", not an error',
      () async {
        final link = MemoryWarpLink();
        expect(
          await readWarpBlock(link, type: 0x72),
          isA<WarpBlockNotAvailable>(),
        );
        expect(link.projector.frames, hasLength(1));
      },
    );

    test('any other FF code is an error', () async {
      final link = MemoryWarpLink()..projector.failFrame(0, 0x10);
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(
          isA<WarpProtocolException>().having((e) => e.code, 'code', 0x10),
        ),
      );
    });

    test('FF 8B after the first packet is an error', () async {
      final link = MemoryWarpLink()
        ..projector.setBlock(0x72, _block(10000))
        ..projector.failFrame(1, 0x8B);
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(
          isA<WarpProtocolException>().having((e) => e.code, 'code', 0x8B),
        ),
      );
      expect(link.projector.frames, hasLength(2));
    });

    test('an empty RAM is "empty" after one read, no loop', () async {
      final link = MemoryWarpLink();
      expect(await readWarpBlock(link, type: 0x80), isA<WarpBlockEmpty>());
      expect(link.projector.frames, hasLength(1));
    });

    test('a wrong checksum throws', () async {
      final link = MemoryWarpLink()
        ..projector.corruptReadChecksum = true
        ..projector.setBlock(0x72, _block(100));
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(isA<WarpProtocolException>()),
      );
    });

    test('a reply for another type throws', () async {
      final link = _EndlessLink(_readPacket(0x74, 3, [1, 2, 3]));
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(isA<WarpProtocolException>()),
      );
    });

    test('a cut-short reply throws a protocol error', () async {
      final link = _EndlessLink(warpHexToBytes('0200A8C0'));
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(isA<WarpProtocolException>()),
      );
    });

    test('a block that never ends is cut off at the packet cap', () async {
      // A first packet, then middle packets for ever.
      final link = _ScriptedReads(
        _readPacket(0x72, 1, [1, 2, 3]),
        then: _readPacket(0x72, 0, [1, 2, 3]),
      );
      await expectLater(
        readWarpBlock(link, type: 0x72),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(link.calls, warpMaxReadPackets);
    });
  });

  group('reloadWarpMemory', () {
    test('asks in the documented order and parses the answers', () async {
      final link = MemoryWarpLink();
      link.projector
        ..mode = 3
        ..storedTimes[1] = '20261128093005'
        ..gridCounts[1] = '7:4'
        ..setBlock(0x72, _block(300));
      final r = await reloadWarpMemory(link, WarpSlot.pc1, _caps4k);
      expect(_describe(link), [
        'QVX:GMMI0',
        'QVX:GDTS1=1',
        _hex(buildReadFrame(0x72, top: true)),
        'QVX:GGNS1=1',
      ]);
      expect(r.mode, 3);
      expect(r.storedAt, DateTime.utc(2026, 11, 28, 9, 30, 5));
      expect(r.storedAt!.isUtc, isTrue);
      expect(r.gridCounts, (columns: 7, rows: 4));
      expect(r.gridCountsDefaulted, isFalse);
      expect((r.read as WarpBlockRead).block, _block(300));
    });

    test('the read type follows the memory and the model', () async {
      final link = MemoryWarpLink();
      await reloadWarpMemory(link, WarpSlot.pc3, _capsWuxga);
      expect(link.projector.frames.single[4], 0x46);
      final link4k = MemoryWarpLink();
      await reloadWarpMemory(link4k, WarpSlot.pc2, _caps4k);
      expect(link4k.projector.frames.single[4], 0x74);
    });

    test('ER401 on GGNS1 gives 3 x 3 and says so', () async {
      final link = MemoryWarpLink();
      final r = await reloadWarpMemory(link, WarpSlot.pc1, _caps4k);
      expect(r.gridCounts, warpDefaultGridCounts);
      expect(r.gridCounts, (columns: 3, rows: 3));
      expect(r.gridCountsDefaulted, isTrue);
    });

    test('ER401 on GDTS1 means no stored time', () async {
      final link = MemoryWarpLink();
      final r = await reloadWarpMemory(link, WarpSlot.pc1, _caps4k);
      expect(r.storedAt, isNull);
    });

    test('FF 8B is a result, not an error', () async {
      final link = MemoryWarpLink();
      final r = await reloadWarpMemory(link, WarpSlot.pc2, _caps4k);
      expect(r.read, isA<WarpBlockNotAvailable>());
      // GGNS1 is still asked after it.
      expect(link.log.last, 'QVX:GGNS1=2');
    });

    test('no reply to a command is a transport failure', () async {
      final link = MemoryWarpLink()..projector.droppedAscii.add('QVX:GDTS1');
      await expectLater(
        reloadWarpMemory(link, WarpSlot.pc1, _caps4k),
        throwsA(isA<WarpTransportException>()),
      );
      expect(link.projector.frames, isEmpty);
    });

    test('a reply of an unexpected shape is a protocol error', () async {
      final link = _AsciiLink({'QVX:GMMI0': 'GMMI0=garbage'});
      await expectLater(
        reloadWarpMemory(link, WarpSlot.pc1, _caps4k),
        throwsA(isA<WarpProtocolException>()),
      );
    });

    test('an error code other than ER401 is a protocol error', () async {
      final link = _AsciiLink({'QVX:GMMI0': 'ERR3'});
      await expectLater(
        reloadWarpMemory(link, WarpSlot.pc1, _caps4k),
        throwsA(isA<WarpProtocolException>()),
      );
    });

    test('the live memory cannot be reloaded', () async {
      await expectLater(
        reloadWarpMemory(MemoryWarpLink(), WarpSlot.ram, _caps4k),
        throwsArgumentError,
      );
    });
  });

  group('storeWarpMemory', () {
    for (final (name, caps, fpgaType, fullType) in [
      ('4K', _caps4k, 0x82, 0x72),
      ('WUXGA', _capsWuxga, 0x52, 0x42),
    ]) {
      test('$name PC-1: FPGA frames, full frames, SAVE, time, grid', () async {
        final link = MemoryWarpLink();
        final result = await _store(link, caps: caps);
        final writes = _writes(link);
        expect(writes.where((w) => w.$1 == fpgaType), hasLength(5));
        expect(writes.where((w) => w.$1 == fullType), hasLength(15));
        expect(writes, hasLength(20));
        // Delta first (method 0), then the full table (method 0x10).
        expect(
          writes.take(5).every((w) => w.$1 == fpgaType && w.$2 == 0x00),
          isTrue,
        );
        expect(
          writes.skip(5).every((w) => w.$1 == fullType && w.$2 == 0x10),
          isTrue,
        );
        expect(_describe(link).sublist(20), [
          '0200AAE103',
          'VXX:GDTS1=1:20261128093005',
          'VXX:GGNS1=1:9:5',
        ]);
        expect(result.frames, 21);
        expect(result.fpgaEncoding, WarpEncoding.delta);
        expect(result.complete, isTrue);
        expect(result.metadataError, isNull);
      });
    }

    test('type codes follow the memory', () async {
      for (final (slot, fpga, full) in [
        (WarpSlot.pc1, 0x82, 0x72),
        (WarpSlot.pc2, 0x84, 0x74),
        (WarpSlot.pc3, 0x86, 0x76),
      ]) {
        final link = MemoryWarpLink();
        await _store(link, slot: slot);
        final types = _writes(link).map((w) => w.$1).toSet();
        expect(types, {fpga, full});
        expect(link.projector.saves, [0xE0 + slot.offset ~/ 2]);
      }
    });

    test('a table with three planes sets the separate-colour bit', () async {
      final link = MemoryWarpLink();
      await _store(link, full: _identity(_caps4k, planes: 3));
      expect(_writes(link).map((w) => w.$1).toSet(), {0x83, 0x73});
    });

    test('a step that does not fit the delta format falls back to words', () async {
      final full = _shifted(_identity(_caps4k), column: 60, row: 5, dx: 300);
      final link = MemoryWarpLink();
      final result = await _store(link, full: full);
      expect(result.fpgaEncoding, WarpEncoding.word);
      final writes = _writes(link);
      expect(
        writes.where((w) => w.$1 == 0x82).every((w) => w.$2 == 0x10),
        isTrue,
      );
      // Words are 4 bytes a point, so the FPGA table is larger than the deltas.
      expect(writes.where((w) => w.$1 == 0x82).length, greaterThan(5));
    });

    test(
      'the header read from the slot is kept, the last byte is set',
      () async {
        final read = defaultWarpHeader(1, last: 0x00);
        read[3] = 7;
        read[20] = 9;
        final link = MemoryWarpLink();
        await _store(link, readHeader: read);
        final frames = link.projector.frames;
        Uint8List header(Uint8List f) => f.sublist(11, 11 + 41);
        final fpgaHeader = header(frames.first);
        final fullHeader = header(frames[5]);
        expect(fpgaHeader.sublist(0, 40), read.sublist(0, 40));
        expect(fullHeader.sublist(0, 40), read.sublist(0, 40));
        expect(fpgaHeader.last, warpHeaderLastFpga);
        expect(fullHeader.last, warpHeaderLastFull);
        expect(read.last, 0x00, reason: 'the input is not modified');
      },
    );

    test('a zero or missing header becomes the default header', () async {
      for (final readHeader in [null, Uint8List(41)]) {
        final link = MemoryWarpLink();
        await _store(link, readHeader: readHeader);
        final frames = link.projector.frames;
        expect(
          frames[5].sublist(11, 11 + 41),
          defaultWarpHeader(1, last: warpHeaderLastFull),
        );
        expect(
          frames.first.sublist(11, 11 + 41),
          defaultWarpHeader(1, last: warpHeaderLastFpga),
        );
      }
    });

    test('a header of the wrong length is refused before any frame', () async {
      final link = MemoryWarpLink();
      await expectLater(
        _store(link, readHeader: Uint8List.fromList(List.filled(121, 1))),
        throwsArgumentError,
      );
      expect(link.log, isEmpty);
    });

    test('a node the full table cannot hold sends nothing', () async {
      final full = _shifted(_identity(_capsWuxga), column: 3, row: 3, dx: 5000);
      final link = MemoryWarpLink();
      await expectLater(
        _store(link, caps: _capsWuxga, full: full),
        throwsA(
          isA<WarpNotEncodableException>()
              .having((e) => e.fpgaTable, 'fpgaTable', isFalse)
              .having((e) => e.check.badCount, 'badCount', 1)
              .having((e) => e.check.firstColumn, 'column', 3)
              .having((e) => e.check.firstRow, 'row', 3),
        ),
      );
      expect(link.log, isEmpty);
    });

    test('a node only the FPGA table cannot hold sends nothing', () async {
      // Column 120 is the last one inside the panel: the FPGA table continues
      // from it, 7 steps of 16 px to column 127, which is past 3072.
      final full = _shifted(
        _identity(_capsWuxga),
        column: 120,
        row: 3,
        dx: 3000 - 1920,
      );
      final link = MemoryWarpLink();
      await expectLater(
        _store(link, caps: _capsWuxga, full: full),
        throwsA(
          isA<WarpNotEncodableException>().having(
            (e) => e.fpgaTable,
            'fpgaTable',
            isTrue,
          ),
        ),
      );
      expect(link.log, isEmpty);
    });

    test('a bit type without a 3-byte encoding sends nothing', () async {
      final caps = warpModelCapsTable.values.firstWhere((c) => c.bits == 2);
      final link = MemoryWarpLink();
      await expectLater(
        _store(link, caps: caps, full: _identity(caps)),
        throwsArgumentError,
      );
      expect(link.log, isEmpty);
    });

    test('an FF frame stops the sequence, SAVE is not sent', () async {
      final link = MemoryWarpLink()..projector.failFrame(3, 0x10);
      await expectLater(
        _store(link),
        throwsA(
          isA<WarpProtocolException>().having((e) => e.code, 'code', 0x10),
        ),
      );
      expect(link.projector.frames, hasLength(4));
      expect(link.projector.saves, isEmpty);
      expect(link.log.whereType<String>(), isEmpty);
    });

    test('a failure in the full table stops before SAVE', () async {
      final link = MemoryWarpLink()..projector.failFrame(12, 0x10);
      await expectLater(_store(link), throwsA(isA<WarpProtocolException>()));
      expect(link.projector.frames, hasLength(13));
      expect(link.projector.saves, isEmpty);
    });

    test('a non-zero write status stops the sequence', () async {
      final link = MemoryWarpLink()..projector.rejectFrame(2, 1);
      await expectLater(
        _store(link),
        throwsA(isA<WarpProtocolException>().having((e) => e.code, 'code', 1)),
      );
      expect(link.projector.frames, hasLength(3));
      expect(link.projector.saves, isEmpty);
    });

    test('a dropped connection is a transport failure, no SAVE', () async {
      final link = MemoryWarpLink()..projector.dropFrame(7);
      await expectLater(_store(link), throwsA(isA<WarpTransportException>()));
      expect(link.projector.saves, isEmpty);
    });

    test('a wrong SAVE ack is an error and no time is written', () async {
      for (final ack in ['0200AAE10103', '0200AAE20003', '0200AAE1']) {
        final link = MemoryWarpLink()
          ..projector.script(
            20,
            FakeWarpProjector.frameLine(warpHexToBytes(ack)),
          );
        await expectLater(_store(link), throwsA(isA<WarpProtocolException>()));
        expect(link.log.whereType<String>(), isEmpty, reason: ack);
      }
    });

    test(
      'a failed time write after SAVE is reported, the table is stored',
      () async {
        final link = MemoryWarpLink()..projector.droppedAscii.add('VXX:GDTS1');
        final result = await _store(link);
        expect(result.dateSaved, isFalse);
        expect(result.gridCountsSaved, isTrue);
        expect(result.complete, isFalse);
        expect(result.metadataError, isA<WarpTransportException>());
        expect(link.projector.saves, [0xE1]);
        expect(link.projector.gridCounts[1], '9:5');
      },
    );

    test('a failed grid write after SAVE is reported', () async {
      final link = MemoryWarpLink()..projector.droppedAscii.add('VXX:GGNS1');
      final result = await _store(link);
      expect(result.dateSaved, isTrue);
      expect(result.gridCountsSaved, isFalse);
      expect(result.complete, isFalse);
      expect(link.projector.storedTimes[1], '20261128093005');
    });

    test('an error reply to a metadata write is reported too', () async {
      final link = _AsciiOverLink(MemoryWarpLink(), {
        'VXX:GGNS1=1:9:5': 'ER402',
      });
      final result = await _store(link);
      expect(result.gridCountsSaved, isFalse);
      expect(result.metadataError, isA<WarpProtocolException>());
    });

    test('progress counts every frame and command up to the total', () async {
      final calls = <(int, int)>[];
      await _store(
        MemoryWarpLink(),
        onProgress: (done, total) => calls.add((done, total)),
      );
      expect(calls, [for (var i = 1; i <= 23; i++) (i, 23)]);
    });

    test('progress stops where the sequence failed', () async {
      final calls = <int>[];
      final link = MemoryWarpLink()..projector.failFrame(3, 0x10);
      await expectLater(
        _store(link, onProgress: (done, total) => calls.add(done)),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(calls, [1, 2, 3]);
    });

    test('the stored time is UTC, zero-padded, from any DateTime', () async {
      expect(
        warpStoredTimeStamp(DateTime.utc(2026, 1, 2, 3, 4, 5)),
        '20260102030405',
      );
      final local = DateTime(2026, 1, 2, 3, 4, 5);
      final u = local.toUtc();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(
        warpStoredTimeStamp(local),
        '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}'
        '${two(u.second)}',
      );
      final link = MemoryWarpLink();
      await _store(link, now: DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(link.projector.storedTimes[1], '20260102030405');
    });

    test('the live memory cannot be stored to', () async {
      final link = MemoryWarpLink();
      await expectLater(_store(link, slot: WarpSlot.ram), throwsArgumentError);
      expect(link.log, isEmpty);
    });

    test('a stored memory reloads to the table that was stored', () async {
      final link = MemoryWarpLink();
      final full = _shifted(_identity(_caps4k), column: 40, row: 20, dx: 21.5);
      await _store(link, full: full, slot: WarpSlot.pc2);
      final r = await reloadWarpMemory(link, WarpSlot.pc2, _caps4k);
      expect(r.mode, 0);
      expect(r.storedAt, DateTime.utc(2026, 11, 28, 9, 30, 5));
      expect(r.gridCounts, (columns: 9, rows: 5));
      final table = decodeTable(
        (r.read as WarpBlockRead).block,
        WarpEncoding.triple,
        _caps4k.bits,
      );
      expect(table.header.last, warpHeaderLastFull);
      expect(table.planes.single.points, full.planes.single.points);
    });

    group('frames match the tables stored on real projectors', () {
      final tables = _fixtureTables();
      for (final (name, caps, slot, fullName, deltaName) in [
        ('4K', _caps4k, WarpSlot.pc2, 'store_4k_full', 'store_4k_delta'),
        (
          'WUXGA',
          _capsWuxga,
          WarpSlot.pc3,
          'store_wuxga_full',
          'store_wuxga_delta',
        ),
      ]) {
        test('$name: types, chunk cuts and lengths', () async {
          final fullFixture = tables[fullName]!;
          final deltaFixture = tables[deltaName]!;
          final link = MemoryWarpLink();
          await _store(
            link,
            caps: caps,
            slot: slot,
            readHeader: warpHexToBytes(fullFixture['header']! as String),
          );
          final frames = link.projector.frames;
          void expectSet(Iterable<Uint8List> set, Map<String, Object?> f) {
            final list = set.toList();
            final spec = f['frames']! as Map<String, Object?>;
            expect(list, hasLength(spec['count']! as int));
            expect(_prefix(list.first), spec['firstPrefix']);
            expect(_prefix(list[1]), spec['middlePrefix']);
            expect(_prefix(list.last), spec['lastPrefix']);
            expect(list.first.length, spec['fullLength']);
            expect(list.last.length, spec['lastLength']);
          }

          expectSet(frames.take(5), deltaFixture);
          expectSet(frames.skip(5).take(15), fullFixture);
          expect(_hex(frames[20]), '0200AAE${slot.offset ~/ 2}03');
          expect(frames, hasLength(21));
        });
      }
    });
  });

  group('restoreWarpBackup', () {
    test(
      'sends the block in the cuts of the original write, then SAVE',
      () async {
        final original = MemoryWarpLink();
        await _store(original);
        final read = await readWarpBlock(original, type: 0x72) as WarpBlockRead;

        final link = MemoryWarpLink();
        final result = await restoreWarpBackup(
          link,
          slot: WarpSlot.pc1,
          fullType: 0x72,
          rawBlock: read.block,
          gridColumns: 9,
          gridRows: 5,
        );
        final sent = link.projector.frames;
        final stored = original.projector.frames.skip(5).take(15).map(_hex);
        expect(sent.take(15).map(_hex), stored);
        expect(_hex(sent[15]), '0200AAE103');
        expect(sent, hasLength(16));
        expect(link.projector.gridCounts[1], '9:5');
        expect(link.projector.blockOf(0x72), read.block);
        expect(result.frames, 16);
        expect(result.fpgaEncoding, isNull);
        expect(result.complete, isTrue);
      },
    );

    test('without grid counts no command is sent', () async {
      final link = MemoryWarpLink();
      final calls = <(int, int)>[];
      await restoreWarpBackup(
        link,
        slot: WarpSlot.pc3,
        fullType: 0x46,
        rawBlock: _block(5000),
        onProgress: (d, t) => calls.add((d, t)),
      );
      expect(link.log.whereType<String>(), isEmpty);
      expect(_writes(link), [(0x46, 0x10, 1), (0x46, 0x10, 2)]);
      expect(calls, [(1, 3), (2, 3), (3, 3)]);
    });

    test('a failed frame ends it without SAVE', () async {
      final link = MemoryWarpLink()..projector.failFrame(1, 0x10);
      await expectLater(
        restoreWarpBackup(
          link,
          slot: WarpSlot.pc1,
          fullType: 0x72,
          rawBlock: _block(10000),
          gridColumns: 3,
          gridRows: 3,
        ),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(link.projector.frames, hasLength(2));
      expect(link.projector.saves, isEmpty);
      expect(link.log.whereType<String>(), isEmpty);
    });

    test('a wrong SAVE ack is an error', () async {
      final link = MemoryWarpLink()
        ..projector.script(
          1,
          FakeWarpProjector.frameLine([0x02, 0x00, 0xAA, 0xE1, 0x01, 0x03]),
        );
      await expectLater(
        restoreWarpBackup(
          link,
          slot: WarpSlot.pc1,
          fullType: 0x72,
          rawBlock: _block(10),
          gridColumns: 3,
          gridRows: 3,
        ),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(link.log.whereType<String>(), isEmpty);
    });

    test('a failed grid write is reported, the table is restored', () async {
      final link = MemoryWarpLink()..projector.droppedAscii.add('VXX:GGNS1');
      final result = await restoreWarpBackup(
        link,
        slot: WarpSlot.pc1,
        fullType: 0x72,
        rawBlock: _block(10),
        gridColumns: 3,
        gridRows: 3,
      );
      expect(result.gridCountsSaved, isFalse);
      expect(result.complete, isFalse);
      expect(link.projector.saves, [0xE1]);
    });
  });

  group('writeWarpPreview', () {
    final tables = _fixtureTables();

    test('4K: delta into the RAM type 0x80', () async {
      final link = MemoryWarpLink();
      final result = await writeWarpPreview(
        link,
        caps: _caps4k,
        full: _identity(_caps4k),
      );
      expect(result.encoding, WarpEncoding.delta);
      expect(result.frames, 5);
      expect(_writes(link).map((w) => (w.$1, w.$2)).toSet(), {(0x80, 0x00)});
      expect(link.projector.saves, isEmpty);
      expect(link.log.whereType<String>(), isEmpty);
    });

    test('WUXGA: delta into the RAM type 0x50', () async {
      final link = MemoryWarpLink();
      await writeWarpPreview(
        link,
        caps: _capsWuxga,
        full: _identity(_capsWuxga),
      );
      expect(_writes(link).map((w) => (w.$1, w.$2)).toSet(), {(0x50, 0x00)});
    });

    test('the FPGA header ends in 0xA1', () async {
      final link = MemoryWarpLink();
      await writeWarpPreview(link, caps: _caps4k, full: _identity(_caps4k));
      expect(link.projector.frames.first[11 + 40], warpHeaderLastFpga);
    });

    test('4K without a fitting delta: 1/64 px with method 0x10', () async {
      final link = MemoryWarpLink();
      final full = _shifted(_identity(_caps4k), column: 60, row: 5, dx: 300);
      final result = await writeWarpPreview(link, caps: _caps4k, full: full);
      expect(result.encoding, WarpEncoding.fpga64);
      final frames = link.projector.frames;
      final spec = tables['ram_preview_4k_fpga64']!['frames']! as Map;
      expect(frames, hasLength(spec['count']! as int));
      expect(_prefix(frames.first), spec['firstPrefix']);
      expect(_prefix(frames.last), spec['lastPrefix']);
      expect(frames.last.length, spec['lastLength']);
      final block = link.projector.blockOf(0x80)!;
      final decoded = decodeTable(block, WarpEncoding.fpga64, _caps4k.bits);
      expect(decoded.planes.single.x(60, 5), closeTo(60 * 32 + 300, 1 / 64));
    });

    test('WUXGA without a fitting delta: words with method 0x10', () async {
      final link = MemoryWarpLink();
      final full = _shifted(_identity(_capsWuxga), column: 60, row: 5, dx: 300);
      final result = await writeWarpPreview(link, caps: _capsWuxga, full: full);
      expect(result.encoding, WarpEncoding.word);
      expect(_writes(link).map((w) => w.$1).toSet(), {0x50});
      expect(_writes(link).every((w) => w.$2 == 0x10), isTrue);
      final decoded = decodeTable(
        link.projector.blockOf(0x50)!,
        WarpEncoding.word,
        _capsWuxga.bits,
      );
      expect(decoded.planes.single.x(60, 5), closeTo(60 * 16 + 300, 1 / 16));
    });

    test('three planes use the separate-colour type', () async {
      final link = MemoryWarpLink();
      await writeWarpPreview(
        link,
        caps: _caps4k,
        full: _identity(_caps4k, planes: 3),
      );
      expect(_writes(link).map((w) => w.$1).toSet(), {0x81});
    });

    test('a table that cannot be encoded sends nothing', () async {
      final link = MemoryWarpLink();
      final full = _shifted(_identity(_capsWuxga), column: 3, row: 3, dx: 5000);
      await expectLater(
        writeWarpPreview(link, caps: _capsWuxga, full: full),
        throwsA(isA<WarpNotEncodableException>()),
      );
      expect(link.log, isEmpty);
    });

    test('a failed frame ends the preview', () async {
      final link = MemoryWarpLink()..projector.failFrame(1, 0x10);
      await expectLater(
        writeWarpPreview(link, caps: _caps4k, full: _identity(_caps4k)),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(link.projector.frames, hasLength(2));
    });
  });

  group('overlay helpers', () {
    test('cursor, grid and marks are sent and their acks checked', () async {
      final link = MemoryWarpLink();
      await sendWarpCursor(link, on: true, x: 100, y: 200);
      await sendWarpGridOverlay(
        link,
        on: true,
        columns: 9,
        rows: 5,
        rgb: 0xFF0000,
      );
      await sendWarpPointMarks(link, gridPointMarks(9, [4]));
      expect(_describe(link), [
        _hex(buildCursorFrame(on: true, x: 100, y: 200)),
        _hex(
          buildGridOverlayFrame(on: true, columns: 9, rows: 5, rgb: 0xFF0000),
        ),
        _hex(buildGridPointMarksFrame(gridPointMarks(9, [4]))),
      ]);
      expect(link.projector.marks, packGridPointMarks(gridPointMarks(9, [4])));
    });

    test('a selection sends the cursor before the marks', () async {
      final link = MemoryWarpLink();
      await sendWarpSelection(
        link,
        x: 10,
        y: 20,
        marks: gridPointMarks(9, [0]),
      );
      final frames = link.projector.frames;
      expect(frames, hasLength(2));
      expect(frames[0][2], 0xAC);
      expect(frames[1][2], 0xA9);
      expect(frames[1][6], 0x90);
    });

    test('a rejected cursor stops the selection before the marks', () async {
      final link = MemoryWarpLink()
        ..projector.script(
          0,
          FakeWarpProjector.frameLine([0x02, 0x00, 0xAC, 0x07, 0x01, 0x03]),
        );
      await expectLater(
        sendWarpSelection(link, x: 10, y: 20, marks: gridPointMarks(9, [0])),
        throwsA(isA<WarpProtocolException>()),
      );
      expect(link.projector.frames, hasLength(1));
    });

    test('rejected grid and marks frames throw', () async {
      final grid = MemoryWarpLink()
        ..projector.script(
          0,
          FakeWarpProjector.frameLine([0x02, 0x00, 0xAB, 0x07, 0x02, 0x03]),
        );
      await expectLater(
        sendWarpGridOverlay(grid, on: false, columns: 3, rows: 3, rgb: 0),
        throwsA(isA<WarpProtocolException>()),
      );
      final marks = MemoryWarpLink()..projector.rejectFrame(0, 1);
      await expectLater(
        sendWarpPointMarks(marks, gridPointMarks(9, [])),
        throwsA(isA<WarpProtocolException>()),
      );
    });
  });
}

/// Answers the first read with [first], every later one with [then].
class _ScriptedReads implements WarpLink {
  _ScriptedReads(this.first, {required this.then});

  final Uint8List first;
  final Uint8List then;
  int calls = 0;

  @override
  Future<Uint8List> binary(Uint8List frame) async =>
      calls++ == 0 ? first : then;

  @override
  Future<String?> ascii(String command) async => null;
}

/// Answers ASCII commands from a map and nothing else.
class _AsciiLink implements WarpLink {
  _AsciiLink(this.replies);

  final Map<String, String?> replies;

  @override
  Future<Uint8List> binary(Uint8List frame) =>
      throw StateError('no binary frame expected');

  @override
  Future<String?> ascii(String command) async => replies[command];
}

/// A link that overrides some ASCII replies of another one.
class _AsciiOverLink implements WarpLink {
  _AsciiOverLink(this.inner, this.replies);

  final MemoryWarpLink inner;
  final Map<String, String?> replies;

  @override
  Future<Uint8List> binary(Uint8List frame) => inner.binary(frame);

  @override
  Future<String?> ascii(String command) => replies.containsKey(command)
      ? Future.value(replies[command])
      : inner.ascii(command);
}
