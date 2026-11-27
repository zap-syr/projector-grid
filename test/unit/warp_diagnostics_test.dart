import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/warp_diagnostics.dart';
import 'package:projector_grid/core/services/warp_transfer.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';

import '../helpers/fake_warp_projector.dart';

// The row whose table format the app does not understand: MIDS1 0024 is the
// parameter file 0018, with a 4K FPGA (full tables are type 0x70 + slot).
const _unsupportedMids = 'MIDS1=0024:00:30';
const _typePc1 = 0x72;
const _typePc2 = 0x74;
const _typePc3 = 0x76;

/// A [MemoryWarpLink] that also answers `QVX:MIDS1` (the fake projector has
/// no model), and can throw for chosen commands.
class _DiagnosticsLink implements WarpLink {
  _DiagnosticsLink(this.memory, {this.mids = _unsupportedMids});

  final MemoryWarpLink memory;
  final String? mids;
  final Set<String> throwing = {};

  /// Everything that crossed the link: strings and frames, in order.
  final List<Object> all = [];

  @override
  Future<Uint8List> binary(Uint8List frame) {
    all.add(frame);
    return memory.binary(frame);
  }

  @override
  Future<String?> ascii(String command) async {
    all.add(command);
    if (throwing.contains(command)) {
      throw StateError('socket closed during $command');
    }
    if (command == 'QVX:MIDS1') return mids;
    return memory.ascii(command);
  }
}

Uint8List _block(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 7 + 3) & 0xFF]);

/// A READ reply whose checksum byte is wrong.
String _damagedReadLine(int type) => FakeWarpProjector.frameLine([
  0x02,
  0x00,
  0xA8,
  0xC0,
  0x00,
  0x06,
  type,
  0x10,
  0x03,
  1,
  2,
  3,
  0x00,
  0x03,
]);

bool _isRead(Uint8List f) => f.length >= 4 && f[2] == 0xA8;

void main() {
  group('RecordingWarpLink', () {
    test(
      'records ASCII and binary calls in order, replies and errors',
      () async {
        final projector = FakeWarpProjector()
          ..mode = 4
          ..setBlock(_typePc1, _block(10));
        final times = [
          for (var i = 0; i < 4; i++) DateTime.utc(2026, 11, 28, 13, 0, i),
        ];
        var tick = 0;
        final recorder = RecordingWarpLink(
          MemoryWarpLink(projector),
          clock: () => times[tick++],
        );

        final mode = await recorder.ascii('QVX:GMMI0');
        final read = await recorder.binary(buildReadFrame(_typePc1, top: true));
        await expectLater(
          recorder.binary(buildReadFrame(_typePc2, top: true)),
          throwsA(isA<WarpProtocolException>()),
        );
        projector.droppedAscii.add('QVX:GGNS1');
        final dropped = await recorder.ascii('QVX:GGNS1=1');

        expect(mode, 'GMMI0=+00004');
        expect(dropped, isNull);
        final calls = recorder.calls;
        expect(calls, hasLength(4));

        final first = calls[0] as WarpAsciiCall;
        expect(first.command, 'QVX:GMMI0');
        expect(first.reply, 'GMMI0=+00004');
        expect(first.error, isNull);
        expect(first.at, times[0]);

        final second = calls[1] as WarpBinaryCall;
        expect(second.sent, buildReadFrame(_typePc1, top: true));
        expect(second.reply, read);
        expect(second.error, isNull);
        expect(second.at, times[1]);

        final third = calls[2] as WarpBinaryCall;
        expect(third.sent, buildReadFrame(_typePc2, top: true));
        expect(third.reply, isNull);
        expect(third.error!.type, 'WarpProtocolException');
        expect(third.error!.code, 0x8B);

        final fourth = calls[3] as WarpAsciiCall;
        expect(fourth.command, 'QVX:GGNS1=1');
        expect(fourth.reply, isNull);
        expect(fourth.error, isNull);
      },
    );

    test('records a transport failure and an unexpected exception', () async {
      final projector = FakeWarpProjector()..dropFrame(0);
      final link = _DiagnosticsLink(MemoryWarpLink(projector))
        ..throwing.add('QVX:GMMI0');
      final recorder = RecordingWarpLink(link);

      await expectLater(
        recorder.binary(buildReadFrame(_typePc1, top: true)),
        throwsA(isA<WarpTransportException>()),
      );
      await expectLater(recorder.ascii('QVX:GMMI0'), throwsStateError);

      final calls = recorder.calls;
      expect(
        (calls[0] as WarpBinaryCall).error!.type,
        'WarpTransportException',
      );
      expect((calls[0] as WarpBinaryCall).error!.message, 'connection dropped');
      expect((calls[1] as WarpAsciiCall).error!.type, 'StateError');
    });

    test(
      'keeps copies: a reused frame buffer does not change the record',
      () async {
        final recorder = RecordingWarpLink(MemoryWarpLink());
        final frame = buildReadFrame(_typePc1, top: true);
        await recorder.binary(frame).catchError((_) => Uint8List(0));
        frame[4] = 0x00;
        expect((recorder.calls.single as WarpBinaryCall).sent[4], _typePc1);
      },
    );
  });

  group('runWarpDiagnostics', () {
    // PC-1 holds a block of two packets, PC-2 is empty (FF 8B), the reply of
    // PC-3 has a wrong checksum.
    late FakeWarpProjector projector;
    late _DiagnosticsLink link;

    setUp(() {
      projector = FakeWarpProjector()
        ..mode = 3
        ..storedTimes[1] = '20261101120000'
        ..gridCounts[1] = '5:4'
        ..setBlock(_typePc1, _block(5000))
        ..script(3, _damagedReadLine(_typePc3));
      link = _DiagnosticsLink(MemoryWarpLink(projector));
    });

    test('the model is a row the app does not understand', () {
      final caps = warpModelCapsFromMids(_unsupportedMids)!;
      expect(caps.id, '0018_00_30');
      expect(warpModelSupported(caps), isFalse);
      expect(caps.fullBase, 0x70);
    });

    test(
      'surveys the model, the mode and the three memories in order',
      () async {
        final result = await runWarpDiagnostics(link);

        expect(result.mids.reply, _unsupportedMids);
        expect(result.modelId, '0018_00_30');
        expect(result.caps, same(lookupWarpModelCaps('0018_00_30')));
        expect(result.mode.reply, 'GMMI0=+00003');
        expect(result.memories.map((m) => m.number), [1, 2, 3]);

        final commands = link.all.whereType<String>().toList();
        expect(commands, [
          'QVX:MIDS1',
          'QVX:GMMI0',
          'QVX:GDTS1=1',
          'QVX:GGNS1=1',
          'QVX:GDTS1=2',
          'QVX:GGNS1=2',
          'QVX:GDTS1=3',
          'QVX:GGNS1=3',
        ]);
        // GDTS1, then the READ, then GGNS1 of each memory.
        final order = link.all
            .map(
              (e) => e is String
                  ? e
                  : _isRead(e as Uint8List)
                  ? 'READ'
                  : 'other',
            )
            .toList();
        expect(order, [
          'QVX:MIDS1',
          'QVX:GMMI0',
          'QVX:GDTS1=1',
          'READ',
          'READ',
          'QVX:GGNS1=1',
          'QVX:GDTS1=2',
          'READ',
          'QVX:GGNS1=2',
          'QVX:GDTS1=3',
          'READ',
          'QVX:GGNS1=3',
        ]);
      },
    );

    test('a memory with a block keeps every packet as received', () async {
      final result = await runWarpDiagnostics(link);
      final pc1 = result.memories[0];

      expect(pc1.stored.reply, 'GDTS1=1:20261101120000');
      expect(pc1.grid.reply, 'GGNS1=1:5:4');
      final read = pc1.read!;
      expect(read.type, _typePc1);
      expect(read.error, isNull);
      expect(read.packets, hasLength(2));
      expect(read.packets[0].sent, buildReadFrame(_typePc1, top: true));
      expect(read.packets[1].sent, buildReadFrame(_typePc1, top: false));
      final got = read.result as WarpBlockRead;
      expect(got.block, _block(5000));
      // The reply frames are what the link returned: 02 00 A8 C0 ... 03.
      for (final packet in read.packets) {
        expect(packet.reply!.first, 0x02);
        expect(packet.reply!.last, 0x03);
        expect(packet.reply!.sublist(2, 4), [0xA8, 0xC0]);
      }
      final data = [
        for (final p in read.packets) ...parseReadReply(p.reply!).data,
      ];
      expect(data, _block(5000));
    });

    test('an empty memory is FF 8B, not an error of the survey', () async {
      final result = await runWarpDiagnostics(link);
      final pc2 = result.memories[1];

      expect(pc2.stored.reply, 'ER401');
      expect(pc2.grid.reply, 'ER401');
      final read = pc2.read!;
      expect(read.type, _typePc2);
      expect(read.result, isA<WarpBlockNotAvailable>());
      expect(read.error, isNull);
      expect(read.packets, hasLength(1));
      expect(read.packets.single.reply, isNull);
      expect(read.packets.single.error!.code, 0x8B);
    });

    test('a damaged reply keeps its bytes and the error', () async {
      final result = await runWarpDiagnostics(link);
      final pc3 = result.memories[2];

      final read = pc3.read!;
      expect(read.type, _typePc3);
      expect(read.result, isNull);
      expect(read.error!.type, 'WarpProtocolException');
      expect(read.error!.message, contains('wrong checksum'));
      expect(read.packets, hasLength(1));
      expect(
        read.packets.single.reply,
        parseWarpBinaryReply(_damagedReadLine(_typePc3)),
      );
    });

    test('a failure of one step does not stop the others', () async {
      projector
        ..droppedAscii.add('QVX:GDTS1=1')
        ..script(0, null)
        // PC-1 stops after its first frame, so PC-3's READ is frame 2 now.
        ..scripted.remove(3)
        ..script(2, _damagedReadLine(_typePc3));
      link.throwing.add('QVX:GGNS1=1');

      final result = await runWarpDiagnostics(link);

      final pc1 = result.memories[0];
      expect(pc1.stored.noReply, isTrue);
      expect(pc1.read!.error!.type, 'WarpTransportException');
      expect(pc1.read!.result, isNull);
      expect(pc1.grid.error!.type, 'StateError');
      // The later memories were surveyed in full.
      expect(result.memories[1].read!.result, isA<WarpBlockNotAvailable>());
      expect(result.memories[1].grid.reply, 'ER401');
      expect(result.memories[2].read!.error!.message, contains('checksum'));
      expect(result.memories[2].grid.reply, 'ER401');
      expect(
        result.calls.whereType<WarpAsciiCall>().last.command,
        'QVX:GGNS1=3',
      );
    });

    test(
      'a failed model query and mode query are recorded, then it goes on',
      () async {
        link.throwing.add('QVX:GMMI0');

        final result = await runWarpDiagnostics(link);

        expect(result.mode.error!.type, 'StateError');
        expect(result.mids.reply, _unsupportedMids);
        expect(result.memories, hasLength(3));
        expect(result.memories[0].read!.result, isA<WarpBlockRead>());
      },
    );

    test(
      'is read-only: no write, SAVE, VXX command, preview or overlay',
      () async {
        await runWarpDiagnostics(link);

        expect(projector.saves, isEmpty);
        expect(projector.marks, isNull);
        expect(projector.frames, isNotEmpty);
        for (final frame in projector.frames) {
          // 0xA8 is the READ; 0xA9 is WRITE, 0xAA SAVE, 0xAB and 0xAC overlays.
          expect(frame[2], 0xA8, reason: 'frame ${warpBytesToHex(frame)}');
        }
        final commands = link.all.whereType<String>();
        expect(commands, isNotEmpty);
        for (final command in commands) {
          expect(command, startsWith('QVX:'));
          expect(command, isNot(contains('VXX')));
        }
        expect(
          projector.asciiCommands.where((c) => c.startsWith('VXX:')),
          isEmpty,
        );
        // The memories are untouched.
        expect(projector.blockOf(_typePc1), _block(5000));
        expect(projector.blockOf(_typePc2), isNull);
      },
    );

    test('an unknown model skips the READs and says why', () async {
      final unknown = _DiagnosticsLink(
        MemoryWarpLink(projector),
        mids: 'MIDS1=9999:00:00',
      );

      final result = await runWarpDiagnostics(unknown);

      expect(result.modelId, '270f_00_00');
      expect(result.caps, isNull);
      for (final memory in result.memories) {
        expect(memory.read, isNull);
        expect(memory.readSkipped, contains('270f_00_00'));
        expect(memory.readSkipped, contains("not in the app's table"));
        expect(memory.stored.command, startsWith('QVX:GDTS1='));
        expect(memory.grid.command, startsWith('QVX:GGNS1='));
      }
      expect(projector.frames, isEmpty);
    });

    test('no reply to the model query skips the READs', () async {
      final silent = _DiagnosticsLink(MemoryWarpLink(projector), mids: null);

      final result = await runWarpDiagnostics(silent);

      expect(result.mids.noReply, isTrue);
      expect(result.modelId, isNull);
      expect(result.memories.map((m) => m.read), everyElement(isNull));
      expect(result.memories.first.readSkipped, contains('no reply'));
      expect(projector.frames, isEmpty);
    });

    test('a reply that is not a model id skips the READs', () async {
      final odd = _DiagnosticsLink(MemoryWarpLink(projector), mids: 'ER401');

      final result = await runWarpDiagnostics(odd);

      expect(result.modelId, isNull);
      expect(result.memories.first.readSkipped, contains('could not be read'));
      expect(projector.frames, isEmpty);
    });
  });
}
