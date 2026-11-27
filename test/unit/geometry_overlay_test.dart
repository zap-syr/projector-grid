import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/geometry_overlay.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

void main() {
  final frames =
      ((jsonDecode(
                File('test/fixtures/warp/overlay_vectors.json')
                    .readAsStringSync(),
              ) as Map<String, Object?>)['frames']!
              as List)
          .cast<Map<String, Object?>>();

  group('frames sent while points were selected and dragged', () {
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final kind = f['kind']! as String;
      final label = switch (kind) {
        'cursor' =>
          'cursor ${(f['on']! as bool) ? 'on' : 'off'} at '
              '${f['x']},${f['y']}',
        'grid' =>
          'grid overlay ${(f['on']! as bool) ? 'on' : 'off'} '
              '${f['columns']}x${f['rows']} ${f['color']}',
        _ => 'marks ${f['points']} ${f['marked']}',
      };
      test('#$i $label', () {
        final Uint8List built;
        switch (kind) {
          case 'cursor':
            built = buildCursorFrame(
              on: f['on']! as bool,
              x: f['x']! as int,
              y: f['y']! as int,
              kind: f['cursorKind']! as int,
            );
          case 'grid':
            built = buildGridOverlayFrame(
              on: f['on']! as bool,
              columns: f['columns']! as int,
              rows: f['rows']! as int,
              rgb: int.parse(f['color']! as String, radix: 16),
            );
          case 'marks':
            final values = [
              for (final ch in (f['values']! as String).split(''))
                int.parse(ch),
            ];
            final marked = (f['marked']! as List).cast<int>();
            expect(
              gridPointMarks(values.length, marked),
              values,
              reason: 'marked indexes expand to the value digits',
            );
            built = buildGridPointMarksFrame(values);
          default:
            fail('unknown frame kind $kind');
        }
        expect(warpBytesToHex(built), f['frame']);
      });
    }
  });

  group('mark packing', () {
    test('uses floor((n + 4) / 4) bytes', () {
      expect(packGridPointMarks(List.filled(45, 0)).length, 12);
      expect(packGridPointMarks(List.filled(9, 0)).length, 3);
      expect(packGridPointMarks(List.filled(1, 0)).length, 1);
    });

    test('the first byte holds three points, the others four', () {
      expect(packGridPointMarks([1, 1, 1]).first, 0x15);
      expect(packGridPointMarks([0, 0, 0, 1, 2, 3, 1]), [0x00, 0x6D]);
    });

    test('values beyond two bits are cut to two bits', () {
      expect(packGridPointMarks([5, 0, 0]).first, 0x10);
    });
  });

  group('cursor', () {
    test('coordinates are 16 bit big-endian', () {
      expect(
        warpBytesToHex(buildCursorFrame(on: true, x: 0x0102, y: 0x0304)),
        '0200AC0701010203040003',
      );
    });

    test('a negative coordinate is sent as two\'s complement', () {
      final f = buildCursorFrame(on: true, x: -1, y: -600);
      expect(f.sublist(5, 9), [0xFF, 0xFF, 0xFD, 0xA8]);
    });
  });
}
