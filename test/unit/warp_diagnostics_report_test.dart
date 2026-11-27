import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/warp_diagnostics.dart';
import 'package:projector_grid/core/services/warp_transfer.dart';
import 'package:projector_grid/features/workspace/domain/warp_diagnostics_report.dart';

import '../helpers/fake_warp_projector.dart';

// The unsupported-format row, as in warp_diagnostics_test.dart.
const _unsupportedMids = 'MIDS1=0024:00:30';

class _Link implements WarpLink {
  _Link(this.memory, this.mids);

  final MemoryWarpLink memory;
  final String? mids;

  @override
  Future<Uint8List> binary(Uint8List frame) => memory.binary(frame);

  @override
  Future<String?> ascii(String command) async =>
      command == 'QVX:MIDS1' ? mids : memory.ascii(command);
}

Uint8List _block(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 7 + 3) & 0xFF]);

String _damagedReadLine() => FakeWarpProjector.frameLine([
  0x02, 0x00, 0xA8, 0xC0, 0x00, 0x06, 0x76, 0x10, 0x03, 1, 2, 3, 0x00, 0x03, //
]);

// PC-1 holds a 40 byte block, PC-2 is empty, PC-3 answers with a damaged
// reply.
Future<WarpDiagnosticsResult> _survey({String? mids = _unsupportedMids}) {
  final projector = FakeWarpProjector()
    ..mode = 3
    ..readMethod = 0x10
    ..storedTimes[1] = '20261101120000'
    ..gridCounts[1] = '5:4'
    ..setBlock(0x72, _block(40))
    ..script(2, _damagedReadLine());
  return runWarpDiagnostics(_Link(MemoryWarpLink(projector), mids));
}

String _report(
  WarpDiagnosticsResult result, {
  String serial = '12345678',
  String? version = '2.0.1+13',
}) => buildWarpDiagnosticsReport(
  result: result,
  projectorName: 'PT-RZ34K',
  ip: '192.168.0.15',
  port: 1024,
  serialNumber: serial,
  appVersion: version,
  createdAt: DateTime.utc(2026, 11, 28, 13, 32, 5),
);

List<String> _lines(String text) => text.split('\n');

void main() {
  group('warpDiagnosticsHex', () {
    test('upper case, space separated, indented', () {
      expect(
        warpDiagnosticsHex([0x02, 0xA8, 0x0F, 0xFF], indent: 2),
        '  02 A8 0F FF',
      );
    });

    test('wraps at 32 bytes per line', () {
      final text = warpDiagnosticsHex(List.generate(70, (i) => i));
      final lines = _lines(text);
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('    00 01 02'));
      expect(lines[0].trim().split(' '), hasLength(32));
      expect(lines[1].trim().split(' '), hasLength(32));
      expect(lines[1].trim(), startsWith('20 21'));
      expect(lines[2].trim().split(' '), hasLength(6));
      expect(lines[2].trim(), '40 41 42 43 44 45');
    });

    test('exactly 32 bytes is one line, no bytes is empty', () {
      expect(_lines(warpDiagnosticsHex(List.filled(32, 0xAB))), hasLength(1));
      expect(warpDiagnosticsHex(const []), '');
    });
  });

  group('warpDiagnosticsFileName', () {
    test('model, IP and the local date', () {
      expect(
        warpDiagnosticsFileName(
          model: 'PT-RZ34K',
          ip: '192.168.0.15',
          at: DateTime(2026, 11, 28, 23, 59),
        ),
        'warp-diagnostics-PT-RZ34K-192.168.0.15-2026-11-28.txt',
      );
    });

    test('keeps only letters, digits, dot and hyphen', () {
      expect(
        warpDiagnosticsFileName(
          model: 'PT RZ34K / Left?',
          ip: 'fe80::1%12',
          at: DateTime(2026, 1, 5),
        ),
        'warp-diagnostics-PT-RZ34K-Left-fe80-1-12-2026-01-05.txt',
      );
    });

    test('an empty name becomes unknown', () {
      expect(
        warpDiagnosticsFileName(
          model: '***',
          ip: '',
          at: DateTime(2026, 11, 28),
        ),
        'warp-diagnostics-unknown-unknown-2026-11-28.txt',
      );
    });
  });

  group('buildWarpDiagnosticsReport', () {
    late String text;
    late List<String> lines;

    setUp(() async {
      text = _report(await _survey());
      lines = _lines(text);
    });

    test('is plain ASCII with LF line ends', () {
      expect(text.codeUnits.every((c) => c < 128), isTrue);
      expect(text, isNot(contains('\r')));
      expect(text, endsWith('\n'));
    });

    test('says which projector, when and with which app', () {
      expect(lines[0], 'Projector Grid free grid diagnostics');
      final local = DateTime.utc(2026, 11, 28, 13, 32, 5).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(
        lines[1],
        'Created: ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)} local, '
        '2026-11-28 13:32:05 UTC',
      );
      expect(lines, contains('App version: 2.0.1+13'));
      expect(lines, contains('Projector: PT-RZ34K (192.168.0.15), port 1024'));
      expect(lines, contains('Serial number: 12345678'));
      expect(lines, contains('Firmware: not read by this app'));
    });

    test('says which row the app picked and why it is unsupported', () {
      expect(lines, contains('Model id (QVX:MIDS1): $_unsupportedMids'));
      expect(lines, contains('Model file id: 0018_00_30'));
      final row = lines.firstWhere((l) => l.startsWith('Model row: '));
      expect(row, contains('0018_00_30, bits 4'));
      expect(row, contains('panel 3840 x 2176'));
      expect(row, contains('table 128 x 69'));
      expect(row, contains('step 32 x 32'));
      expect(row, contains('movable range 800 x 800'));
      expect(row, contains('full table type base 0x70'));
      final status = lines.firstWhere(
        (l) => l.startsWith('Free grid status: '),
      );
      expect(
        status,
        startsWith(
          "Free grid status: not supported, the neutral table does not fit "
          "the row's bits (",
        ),
      );
      expect(status, contains('nodes out of range for 4 bits'));
      expect(lines, contains('Mode (QVX:GMMI0): GMMI0=+00003'));
    });

    test('lists the memories in order, each with its queries', () {
      final pc1 = lines.indexOf('[PC-1]');
      final pc2 = lines.indexOf('[PC-2]');
      final pc3 = lines.indexOf('[PC-3]');
      expect(pc1, greaterThan(0));
      expect(pc2, greaterThan(pc1));
      expect(pc3, greaterThan(pc2));
      expect(lines[pc1 + 1], 'QVX:GDTS1=1 -> GDTS1=1:20261101120000');
      expect(lines, contains('QVX:GGNS1=1 -> GGNS1=1:5:4'));
      expect(lines, contains('QVX:GDTS1=2 -> ER401'));
      expect(lines, contains('QVX:GGNS1=3 -> ER401'));
    });

    test('shows a block with every byte as received', () {
      expect(
        lines,
        contains(
          'READ type 0x72: block of 40 bytes in 1 packet(s), method 0x10',
        ),
      );
      expect(lines, contains('  packet 1 sent (9 bytes):'));
      expect(lines, contains('    02 00 A8 C0 72 01 10 03 03'));
      // 02 00 A8 C0, size 3 + 40 = 0x2B, type, method, location 3, then data.
      expect(lines, contains('  packet 1 reply (51 bytes):'));
      expect(
        lines,
        contains(
          '    02 00 A8 C0 00 2B 72 10 03 03 0A 11 18 1F 26 2D 34 3B 42 49 '
          '50 57 5E 65 6C 73 7A 81 88 8F 96 9D',
        ),
      );
      // 51 bytes: 32 on the first line, 19 on the next, checksum and the
      // closing 03 last.
      final at = lines.indexOf('  packet 1 reply (51 bytes):');
      expect(lines[at + 2].trim().split(' '), hasLength(19));
      expect(lines[at + 2], endsWith(' 51 03'));
    });

    test('shows an empty memory as not available', () {
      expect(
        lines,
        contains('READ type 0x74: not available (error frame FF 8B)'),
      );
      expect(
        lines.any((l) => l.startsWith('  packet 1 reply: none, error: ')),
        isTrue,
      );
      expect(text, contains('(code 0x8B)'));
    });

    test('shows where a read failed and with what error', () {
      expect(lines, contains('READ type 0x76: failed'));
      final error = lines.firstWhere((l) => l.startsWith('  error: '));
      expect(error, contains('WarpProtocolException'));
      expect(error, contains('wrong checksum'));
      // The damaged reply is there as it came back.
      expect(lines, contains('    02 00 A8 C0 00 06 76 10 03 01 02 03 00 03'));
    });

    test('a serial number polling did not find is not known', () async {
      final result = await _survey();
      expect(
        _lines(_report(result, serial: '-')),
        contains('Serial number: not known'),
      );
      expect(
        _lines(_report(result, serial: '')),
        contains('Serial number: not known'),
      );
    });

    test('an app version that could not be read is said so', () async {
      final result = await _survey();
      expect(
        _lines(_report(result, version: null)),
        contains('App version: not known'),
      );
    });
  });

  group('buildWarpDiagnosticsReport for a model that is not known', () {
    test('a model not in the table skips the READs and says so', () async {
      final result = await _survey(mids: 'MIDS1=9999:00:00');
      final lines = _lines(_report(result));

      expect(lines, contains('Model file id: 270f_00_00'));
      expect(lines, contains("Model row: not in the app's table"));
      expect(
        lines,
        contains(
          "Free grid status: unknown, the model is not in the app's table",
        ),
      );
      final skipped = lines.where((l) => l.startsWith('READ: skipped, '));
      expect(skipped, hasLength(3));
      expect(lines.any((l) => l.startsWith('READ type')), isFalse);
      expect(lines, contains('QVX:GDTS1=3 -> ER401'));
    });

    test('no reply to the model query is shown as such', () async {
      final result = await _survey(mids: null);
      final lines = _lines(_report(result));

      expect(lines, contains('Model id (QVX:MIDS1): no reply'));
      expect(lines, contains('Model file id: not known'));
      expect(
        lines,
        contains(
          'READ: skipped, the model query got no reply, so the table type is '
          'not known',
        ),
      );
    });
  });
}
