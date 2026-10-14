import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/projector_settings_client.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_side.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';

import '../helpers/fake_protocol_service.dart';

const _node = ProjectorNode(
  id: '1',
  name: 'P1',
  ipAddress: '10.0.0.1',
  x: 0,
  y: 0,
);

void main() {
  group('parseEdgeBlendState', () {
    test('reads every family in query order', () {
      final queries = edgeBlendQueries();
      final replies = {
        'QVX:EDBI0': 'EDBI0=+00001',
        'QID': 'PT-RQ25KE',
        'QGR': '1',
        'QER': '10',
        'QVX:ERWI0': 'ERWI0=+00384',
        'QVX:EUWI0': 'EUWI0=+00240',
        'QGM': '1',
        'QVX:EATI1': 'EATI1=+00000',
        'QJR': '468',
      };
      final (state, raster) = parseEdgeBlendState([
        for (final q in queries) replies[q],
      ]);
      expect(state.mode, EdgeBlendMode.on);
      expect(raster, (h: 3840, v: 2400));
      expect(
        state[BlendEdge.right],
        const EdgeSettings(enabled: true, start: 10, width: 384, border: 468),
      );
      expect(
        state[BlendEdge.upper],
        const EdgeSettings(enabled: false, start: 0, width: 240),
      );
      expect(state.markers, isTrue);
      expect(state.autoPattern, isFalse);
    });

    test('missing replies fall back to off / 0 and the WUXGA raster', () {
      final (state, raster) = parseEdgeBlendState(
        List.filled(edgeBlendQueries().length, null),
      );
      expect(state.mode, EdgeBlendMode.off);
      expect(raster, (h: 1920, v: 1200));
      expect(
        state[BlendEdge.left],
        const EdgeSettings(enabled: false, start: 0, width: 0),
      );
    });
  });

  group('EdgeBlendState.maxFor', () {
    // WUXGA, V = 1200. Upper line at 200 + 600 + 100 = 900.
    final (base, raster) = parseEdgeBlendState(
      List.filled(edgeBlendQueries().length, null),
    );
    EdgeBlendState withLower({required bool enabled}) => base
        .withEdge(
          BlendEdge.upper,
          const EdgeSettings(
            enabled: true,
            start: 200,
            width: 600,
            border: 100,
          ),
        )
        .withEdge(
          BlendEdge.lower,
          EdgeSettings(enabled: enabled, start: 0, width: 100, border: 50),
        );

    test('border lines never cross', () {
      final state = withLower(enabled: true);
      // Lower line at 150.
      expect(state.maxFor(BlendEdge.upper, EdgePart.start, raster), 350);
      expect(state.maxFor(BlendEdge.upper, EdgePart.width, raster), 750);
      expect(state.maxFor(BlendEdge.upper, EdgePart.border, raster), 250);
      expect(state.maxFor(BlendEdge.lower, EdgePart.width, raster), 250);
      expect(state.maxFor(BlendEdge.lower, EdgePart.border, raster), 200);
    });

    test('a disabled edge counts with its stored values', () {
      final state = withLower(enabled: false);
      expect(state.maxFor(BlendEdge.upper, EdgePart.width, raster), 750);
    });

    test('a value already past the rule is its own ceiling', () {
      // Set elsewhere: the lines cross (the projector allows it).
      final state = withLower(enabled: true).withEdge(
        BlendEdge.upper,
        const EdgeSettings(enabled: true, start: 200, width: 1000),
      );
      expect(state.maxFor(BlendEdge.upper, EdgePart.width, raster), 1000);
    });
  });

  group('EdgeBlendSide', () {
    late FakeProtocolService service;
    late List<String> failures;
    late EdgeBlendSide side;

    setUp(() async {
      service = FakeProtocolService();
      failures = [];
      service.rawResponses.addAll({
        'QVX:EDBI0': 'EDBI0=+00001',
        'QID': 'PT-RZ34KE',
        'QGL': '1',
        'QEL': '0',
        'QVX:ELWI0': 'ELWI0=+00192',
        'QJL': '100',
      });
      side = EdgeBlendSide(
        node: _node,
        client: ProjectorSettingsClient(
          service: service,
          node: _node,
          onFailure: failures.add,
        ),
      );
      await side.load();
      service.sentRaw.clear();
    });

    tearDown(() => side.dispose());

    List<String> sent() => [for (final (_, cmd) in service.sentRaw) cmd];

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('nothing answering is unreachable', () async {
      final dead = EdgeBlendSide(
        node: _node,
        client: ProjectorSettingsClient(
          service: FakeProtocolService(),
          node: _node,
          onFailure: (_) {},
        ),
      );
      await dead.load();
      expect(dead.unreachable, isTrue);
      dead.dispose();
    });

    test(
      'preview sends nothing, commit sends once in each wire format',
      () async {
        service.rawResponses['VEL:0010'] = 'VEL:0010';
        side.preview(BlendEdge.left, EdgePart.start, 5);
        side.preview(BlendEdge.left, EdgePart.start, 10);
        expect(sent(), isEmpty);
        side.commit(BlendEdge.left, EdgePart.start);
        side.preview(BlendEdge.left, EdgePart.width, 300);
        side.commit(BlendEdge.left, EdgePart.width);
        await settle();
        expect(sent(), ['VEL:0010', 'VXX:ELWI0=+00300']);
      },
    );

    test('a commit equal to what the projector has sends nothing', () async {
      side.commit(BlendEdge.left, EdgePart.width); // still 192
      await settle();
      expect(sent(), isEmpty);
    });

    test('ER402 reads the value back without a failure notice', () async {
      service.rawResponses['VXX:ELWI0=+01900'] = 'ER402';
      side.preview(BlendEdge.left, EdgePart.width, 1900);
      side.commit(BlendEdge.left, EdgePart.width);
      await settle();
      expect(sent(), ['VXX:ELWI0=+01900', 'QVX:ELWI0']);
      expect(side.blend[BlendEdge.left].width, 192);
      expect(failures, isEmpty);
      // The read-back is now the baseline: committing 192 again is a no-op.
      side.commit(BlendEdge.left, EdgePart.width);
      await settle();
      expect(sent(), hasLength(2));
    });

    test('a refused write queued before another of the same field is not '
        'read back over it', () async {
      service.rawResponses['VXX:ELWI0=+01900'] = 'ER402';
      side.preview(BlendEdge.left, EdgePart.width, 1900);
      side.commit(BlendEdge.left, EdgePart.width);
      side.preview(BlendEdge.left, EdgePart.width, 1200);
      side.commit(BlendEdge.left, EdgePart.width);
      await settle();
      expect(sent(), ['VXX:ELWI0=+01900', 'VXX:ELWI0=+01200']);
      expect(side.blend[BlendEdge.left].width, 1200);
    });

    test('a write with no reply is sent again on the next commit', () async {
      side.preview(BlendEdge.left, EdgePart.start, 500);
      side.commit(BlendEdge.left, EdgePart.start); // unscripted: no reply
      await settle();
      expect(failures, ['VEL:0500']);
      service.rawResponses['VEL:0500'] = 'VEL:0500';
      side.commit(BlendEdge.left, EdgePart.start);
      await settle();
      expect(sent(), ['VEL:0500', 'VEL:0500']);
    });

    test('other error codes are reported and read back', () async {
      service.rawResponses['VGU:1'] = 'ERR3';
      service.rawResponses['QGU'] = '0';
      side.setEnabled(BlendEdge.upper, true);
      expect(side.blend[BlendEdge.upper].enabled, isTrue);
      await settle();
      expect(failures, ['VGU:1']);
      expect(side.blend[BlendEdge.upper].enabled, isFalse);
    });

    test('mode, markers and auto pattern use their own commands', () async {
      service.rawResponses['VGM:1'] = 'VGM:1';
      side.setMode(EdgeBlendMode.user);
      side.setMarkers(true);
      side.setAutoPattern(true);
      await settle();
      expect(sent(), ['VXX:EDBI0=+00002', 'VGM:1', 'VXX:EATI1=+00001']);
    });

    test('the border width loads with the blend values', () {
      expect(side.blend[BlendEdge.left].border, 100);
      expect(side.black, isNull);
    });

    test('Auto test pattern ER401 is no failure, just refused', () async {
      service.rawResponses['VXX:EATI1=+00001'] = 'ER401';
      service.rawResponses['QVX:EATI1'] = 'EATI1=+00000';
      side.setAutoPattern(true);
      await settle();
      expect(failures, isEmpty);
      expect(side.autoPatternRefused, isTrue);
      expect(side.blend.autoPattern, isFalse);
      // Accepted once the test pattern is off.
      service.rawResponses['VXX:EATI1=+00001'] = 'VXX:EATI1=+00001';
      side.setAutoPattern(true);
      await settle();
      expect(side.autoPatternRefused, isFalse);
    });

    group('Black Level', () {
      setUp(() async {
        service.rawResponses.addAll({
          'QJI': '010,020,030,040',
          'QVX:EBII1': 'EBII1=+00000',
          'QJO': '005,005,005,005',
          'QVX:EBII2': 'EBII2=+00001',
        });
        await side.loadBlack();
        service.sentRaw.clear();
      });

      test('loads lazily, apart from the blend tab', () {
        expect(side.black![LevelSlot.nonOverlapped].value, (
          w: 10,
          r: 20,
          g: 30,
          b: 40,
        ));
        expect(side.black![LevelSlot.border].interlocked, isTrue);
        expect(side.blend[BlendEdge.left].width, 192);
      });

      // W is written the way VSS writes it (§8 "W channel").
      test('an interlocked level is written as V,V,V,V', () async {
        side.previewLevel(LevelSlot.border, RgbChannel.g, 12);
        side.commitLevel(LevelSlot.border);
        await settle();
        expect(sent(), ['VJO:012,012,012,012']);
      });

      test('a free level changes one channel and writes W as 0', () async {
        side.previewLevel(LevelSlot.nonOverlapped, RgbChannel.r, 50);
        side.commitLevel(LevelSlot.nonOverlapped);
        await settle();
        expect(sent(), ['VJI:000,050,030,040']);
      });

      test('Interlocked ON writes the flag, then everything = R', () async {
        side.setInterlocked(LevelSlot.nonOverlapped, true);
        await settle();
        expect(sent(), ['VXX:EBII1=+00001', 'VJI:020,020,020,020']);
        expect(side.black![LevelSlot.nonOverlapped].value, (
          w: 20,
          r: 20,
          g: 20,
          b: 20,
        ));
      });

      test('Interlocked OFF writes the flag, then W = 0', () async {
        side.setInterlocked(LevelSlot.border, false);
        await settle();
        expect(sent(), ['VXX:EBII2=+00000', 'VJO:000,005,005,005']);
      });

      test('border width uses the legacy 4-digit write', () async {
        side.preview(BlendEdge.left, EdgePart.border, 250);
        side.commit(BlendEdge.left, EdgePart.border);
        side.resetBorder(BlendEdge.left);
        await settle();
        expect(sent(), ['VJL:0250', 'VJL:0000']);
      });

      test('mode writes EBMI1', () async {
        side.setBlackMode(BlackLevelMode.blackOnly);
        await settle();
        expect(sent(), ['VXX:EBMI1=+00001']);
      });
    });
  });

  group('parseBlackLevelState', () {
    test('reads tuples and flags in query order', () {
      final replies = {
        'QVX:EBMI1': 'EBMI1=+00001',
        'QVX:EBBS3': 'EBBS3=001,002,003,004',
        'QVX:EBII6': 'EBII6=+00001',
      };
      final state = parseBlackLevelState([
        for (final q in blackLevelQueries()) replies[q],
      ]);
      expect(blackLevelQueries(), hasLength(13));
      expect(state.mode, BlackLevelMode.blackOnly);
      expect(
        state[LevelSlot.right],
        const RgbwLevel(value: (w: 1, r: 2, g: 3, b: 4), interlocked: true),
      );
      expect(
        state[LevelSlot.nonOverlapped],
        const RgbwLevel(value: (w: 0, r: 0, g: 0, b: 0), interlocked: false),
      );
    });
  });

  group('RgbwLevel', () {
    const free = RgbwLevel(value: (w: 5, r: 6, g: 7, b: 8), interlocked: false);

    test('a free channel changes alone, W goes to 0', () {
      expect(free.withChannel(RgbChannel.b, 9).value, (w: 0, r: 6, g: 7, b: 9));
    });

    test('interlocked: any channel moves the others and W', () {
      final locked = free.copyWith(interlocked: true);
      // Unequal values set elsewhere show as they are until changed.
      expect(locked.channel(RgbChannel.g), 7);
      expect(locked.withChannel(RgbChannel.b, 3).value, (
        w: 3,
        r: 3,
        g: 3,
        b: 3,
      ));
    });

    test('turning Interlocked on evens out to R, off zeroes W', () {
      expect(free.withInterlocked(true).value, (w: 6, r: 6, g: 6, b: 6));
      expect(free.copyWith(interlocked: true).withInterlocked(false).value, (
        w: 0,
        r: 6,
        g: 7,
        b: 8,
      ));
    });
  });
}
