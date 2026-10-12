import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/projector_settings_client.dart';
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
      };
      final (state, raster) = parseEdgeBlendState([
        for (final q in queries) replies[q],
      ]);
      expect(state.mode, EdgeBlendMode.on);
      expect(raster, (h: 3840, v: 2400));
      expect(
        state[BlendEdge.right],
        const EdgeSettings(enabled: true, start: 10, width: 384),
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
    test('applies the shared-raster rules', () {
      final (base, raster) = parseEdgeBlendState(
        List.filled(edgeBlendQueries().length, null),
      );
      final state = base
          .withEdge(
            BlendEdge.upper,
            const EdgeSettings(enabled: true, start: 200, width: 1000),
          )
          .withEdge(
            BlendEdge.lower,
            const EdgeSettings(enabled: true, start: 0, width: 100),
          );
      // WUXGA, V = 1200.
      expect(state.maxFor(BlendEdge.upper, EdgePart.start, raster), 200);
      expect(state.maxFor(BlendEdge.upper, EdgePart.width, raster), 1000);
      expect(state.maxFor(BlendEdge.lower, EdgePart.width, raster), 200);
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
  });
}
