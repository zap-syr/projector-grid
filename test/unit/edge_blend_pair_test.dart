import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/edge_blend_pair.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';

ProjectorNode _node(String id) =>
    ProjectorNode(id: id, name: id, ipAddress: '10.0.0.1', x: 0, y: 0);

void main() {
  group('PairArrangement', () {
    test('facing edges', () {
      expect(PairArrangement.sideBySide.facingA, BlendEdge.right);
      expect(PairArrangement.sideBySide.facingB, BlendEdge.left);
      expect(PairArrangement.stacked.facingA, BlendEdge.lower);
      expect(PairArrangement.stacked.facingB, BlendEdge.upper);
      expect(PairArrangement.stacked.facingOf(1), BlendEdge.upper);
    });
  });

  group('edgeBlendTargets', () {
    final a = _node('a');
    final b = _node('b');
    final c = _node('c');
    final all = [a, b, c];

    test('no selection opens the clicked card', () {
      expect(edgeBlendTargets(b, {}, all), [b]);
    });

    test('a click outside the selection opens the clicked card', () {
      expect(edgeBlendTargets(c, {'a', 'b'}, all), [c]);
    });

    test('a selection of two opens both, in workspace order', () {
      expect(edgeBlendTargets(c, {'c', 'a'}, all), [a, c]);
    });

    test('a selection of three opens the clicked card', () {
      expect(edgeBlendTargets(b, {'a', 'b', 'c'}, all), [b]);
    });
  });

  group('guessPairArrangement', () {
    test('wider horizontal gap is side by side, left card is A', () {
      expect(guessPairArrangement((x: 300, y: 0), (x: 0, y: 40)), (
        arrangement: PairArrangement.sideBySide,
        swapped: true,
      ));
      expect(guessPairArrangement((x: 0, y: 40), (x: 300, y: 0)), (
        arrangement: PairArrangement.sideBySide,
        swapped: false,
      ));
    });

    test('taller vertical gap is stacked, upper card is A', () {
      expect(guessPairArrangement((x: 0, y: 0), (x: 20, y: 200)), (
        arrangement: PairArrangement.stacked,
        swapped: false,
      ));
      expect(guessPairArrangement((x: 20, y: 200), (x: 0, y: 0)), (
        arrangement: PairArrangement.stacked,
        swapped: true,
      ));
    });

    test('a tie is side by side', () {
      expect(
        guessPairArrangement((x: 0, y: 0), (x: 100, y: 100)).arrangement,
        PairArrangement.sideBySide,
      );
    });
  });

  group('Link', () {
    test('only between equal rasters', () {
      expect(canLinkRasters((h: 3840, v: 2400), (h: 3840, v: 2400)), isTrue);
      expect(canLinkRasters((h: 3840, v: 2400), (h: 1920, v: 1200)), isFalse);
    });

    test('linked max is the smaller one', () {
      expect(linkedMax(2400, 1400), 1400);
      expect(linkedMax(300, 900), 300);
    });
  });

  group('pair layout', () {
    FacingEdge edge(int start, int width, {int span = 3840, bool on = true}) =>
        (enabled: on, start: start, width: width, span: span);

    test('no blend: the rasters just touch', () {
      expect(pairOverlap(edge(0, 0), edge(0, 0)), 0);
      expect(pairPositions(0), (a: 0, b: 1));
    });

    test('overlap is Start(A) + Start(B) + the wider width', () {
      // 0.1 + 0.05 + max(0.125, 0.0625)
      expect(pairOverlap(edge(384, 480), edge(192, 240)), closeTo(0.275, 1e-9));
    });

    test("the narrower width doesn't move anything", () {
      final wide = edge(0, 480);
      expect(pairOverlap(wide, edge(0, 0)), pairOverlap(wide, edge(0, 400)));
    });

    test('a disabled facing edge adds nothing', () {
      expect(
        pairOverlap(edge(384, 480, on: false), edge(192, 240)),
        closeTo(0.05 + 0.0625, 1e-9),
      );
    });

    test('mixed rasters overlap by their own fractions', () {
      // A: 480 / 3840 = 0.125, B: 120 / 1920 = 0.0625
      expect(
        pairOverlap(edge(0, 480), edge(120, 0, span: 1920)),
        closeTo(0.1875, 1e-9),
      );
    });

    test('the pair is centred: both rasters move by half the overlap', () {
      final p = pairPositions(0.2);
      expect(p.a, closeTo(0.1, 1e-9));
      expect(p.b, closeTo(0.9, 1e-9));
      // B ends as far from the extent's end as A starts from its start.
      expect(2 - (p.b + 1), closeTo(p.a, 1e-9));
    });

    test('extent fits two rasters along the axis', () {
      expect(pairExtent(PairArrangement.sideBySide), (h: 2, v: 1));
      expect(pairExtent(PairArrangement.stacked), (h: 1, v: 2));
    });
  });
}
