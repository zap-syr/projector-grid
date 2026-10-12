import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/edge_blend_limits.dart';
import 'package:projector_grid/features/workspace/domain/edge_blend_values.dart';

void main() {
  group('BlendEdge', () {
    test('opposite pairs', () {
      expect(BlendEdge.upper.opposite, BlendEdge.lower);
      expect(BlendEdge.lower.opposite, BlendEdge.upper);
      expect(BlendEdge.left.opposite, BlendEdge.right);
      expect(BlendEdge.right.opposite, BlendEdge.left);
    });

    test('Left/Right run along the raster width', () {
      expect(BlendEdge.left.isHorizontal, isTrue);
      expect(BlendEdge.right.isHorizontal, isTrue);
      expect(BlendEdge.upper.isHorizontal, isFalse);
      expect(BlendEdge.lower.isHorizontal, isFalse);
    });
  });

  group('edgeBlendRasterFor', () {
    test('Tier A (Quad Pixel Drive) is 3840x2400', () {
      expect(edgeBlendRasterFor('PT-RQ25KE'), (h: 3840, v: 2400));
      expect(edgeBlendRasterFor('PT-RQ35K'), (h: 3840, v: 2400));
    });

    test('Tier B is 5120x3200', () {
      expect(edgeBlendRasterFor('PT-RQ32K'), (h: 5120, v: 3200));
    });

    test('WUXGA models and an unknown model are 1920x1200', () {
      expect(edgeBlendRasterFor('PT-RZ34KE'), (h: 1920, v: 1200));
      expect(edgeBlendRasterFor(''), (h: 1920, v: 1200));
    });

    test('span follows the edge axis', () {
      const raster = (h: 3840, v: 2400);
      expect(edgeBlendSpan(raster, BlendEdge.left), 3840);
      expect(edgeBlendSpan(raster, BlendEdge.right), 3840);
      expect(edgeBlendSpan(raster, BlendEdge.upper), 2400);
      expect(edgeBlendSpan(raster, BlendEdge.lower), 2400);
    });
  });

  // Values below are the live results in plan/EDGE_BLENDING_PLAN.md §8.
  group('limits', () {
    test('everything at 0 reaches the full raster, no -128 margin', () {
      expect(maxBlendStart(span: 2400, width: 0), 2400);
      expect(maxBlendWidth(span: 3840, start: 0, oppositeWidth: 0), 3840);
    });

    test('start + own width stay within the raster', () {
      expect(maxBlendStart(span: 2400, width: 2400), 0);
      expect(maxBlendWidth(span: 2400, start: 1200, oppositeWidth: 0), 1200);
    });

    test('opposite widths share the raster', () {
      // RQ25K: Upper width 1000 → Lower width ≤ 1400.
      expect(maxBlendWidth(span: 2400, start: 0, oppositeWidth: 1000), 1400);
      // RZ34K: Left width 1000 → Right width ≤ 920.
      expect(maxBlendWidth(span: 1920, start: 0, oppositeWidth: 1000), 920);
    });

    test('the tighter of own start and opposite width wins', () {
      expect(maxBlendWidth(span: 2400, start: 1800, oppositeWidth: 1000), 600);
      expect(maxBlendWidth(span: 2400, start: 200, oppositeWidth: 1000), 1400);
    });

    test('black border shares the raster with its own blend width', () {
      expect(maxBorderWidth(span: 2400, width: 200), 2200);
      expect(maxBorderWidth(span: 1920, width: 200), 1720);
    });

    test('never negative', () {
      expect(maxBlendStart(span: 1200, width: 1500), 0);
      expect(maxBlendWidth(span: 1200, start: 0, oppositeWidth: 1500), 0);
      expect(maxBorderWidth(span: 1200, width: 1500), 0);
    });
  });

  group('formatNt4', () {
    test('pads to 4 digits', () {
      expect(formatNt4(0), '0000');
      expect(formatNt4(10), '0010');
      expect(formatNt4(2400), '2400');
    });
  });

  group('parseRgbw', () {
    test('bare tuple (QJI / QJO)', () {
      expect(parseRgbw('050,010,020,030'), (w: 50, r: 10, g: 20, b: 30));
    });

    test('keyed tuple (QVX:EBBSn)', () {
      expect(parseRgbw('EBBS0=000,000,000,255'), (w: 0, r: 0, g: 0, b: 255));
    });

    test('anything else is null', () {
      expect(parseRgbw(null), isNull);
      expect(parseRgbw('ER401'), isNull);
      expect(parseRgbw('0'), isNull);
      expect(parseRgbw('000,000,000'), isNull);
      expect(parseRgbw('000,000,000,256'), isNull);
      expect(parseRgbw('000,abc,000,000'), isNull);
    });
  });

  group('formatRgbw', () {
    test('three digits per channel', () {
      expect(formatRgbw((w: 50, r: 10, g: 20, b: 30)), '050,010,020,030');
      expect(formatRgbw((w: 0, r: 0, g: 0, b: 0)), '000,000,000,000');
    });

    test('round-trips with parseRgbw', () {
      const v = (w: 255, r: 1, g: 22, b: 133);
      expect(parseRgbw(formatRgbw(v)), v);
    });
  });
}
