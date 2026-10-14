import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/black_level_zones.dart';
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

  // plan/EDGE_BLENDING_PLAN.md §8 "Limits rule": border lines never cross.
  group('limits', () {
    test('the border line sits the border width in from the zone end', () {
      // RQ25K in VSS: Left Start 391, Width 763, border 544.
      expect(blendLineDepth(start: 391, width: 763, border: 544), 1698);
    });

    test('everything at 0 reaches the full raster, no -128 margin', () {
      expect(maxBlendValue(span: 2400, oppositeLine: 0, ownRest: 0), 2400);
    });

    test('the opposite border line and the own other values count', () {
      // Lower line at 1000, Upper Start 200 + border 300 → Width ≤ 900.
      expect(maxBlendValue(span: 2400, oppositeLine: 1000, ownRest: 500), 900);
    });

    test('never negative', () {
      expect(maxBlendValue(span: 1200, oppositeLine: 1500, ownRest: 0), 0);
    });
  });

  group('black level zones', () {
    test('bands: Start, zone end, border line', () {
      expect(blendBands(start: 200, width: 400, border: 300), (
        start: 200,
        end: 600,
        line: 900,
      ));
    });

    test('overlapped and border add up, capped at 255', () {
      // Overlapped red 255 + border blue 255 showed magenta on the RQ25K.
      expect(
        stackLevels((w: 0, r: 255, g: 0, b: 0), (w: 0, r: 0, g: 0, b: 255)),
        (w: 0, r: 255, g: 0, b: 255),
      );
      expect(
        stackLevels((w: 0, r: 200, g: 10, b: 0), (w: 0, r: 100, g: 20, b: 0)),
        (w: 0, r: 255, g: 30, b: 0),
      );
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
