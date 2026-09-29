import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/geometry_values.dart';

void main() {
  group('formatters', () {
    test('formatNtInt pads to 5 digits with a sign', () {
      expect(formatNtInt(12), '+00012');
      expect(formatNtInt(-12), '-00012');
      expect(formatNtInt(0), '+00000');
      expect(formatNtInt(960), '+00960');
    });

    test('formatNtDeg rounds to 1dp with a sign', () {
      expect(formatNtDeg(1.25), '+1.3');
      expect(formatNtDeg(-3), '-3.0');
      expect(formatNtDeg(0), '+0.0');
      expect(formatNtDeg(-0.04), '+0.0');
    });

    test('formatNtThrow is positive and at least 4 chars', () {
      expect(formatNtThrow(1.5), '+01.5');
      expect(formatNtThrow(12.34), '+12.3');
    });
  });

  group('parseKeyedValue', () {
    test('with KEY=', () {
      expect(parseKeyedValue('GMMI0=+00010', 'GMMI0'), '+00010');
    });
    test('different key falls back to the first =', () {
      expect(parseKeyedValue('OTHER=+00001', 'GMMI0'), '+00001');
    });
    test('no = returns the whole trimmed reply', () {
      expect(parseKeyedValue(' +00002 ', 'GMMI0'), '+00002');
    });
    test('null stays null', () {
      expect(parseKeyedValue(null, 'GMMI0'), isNull);
    });
    test('int and double parse through the + sign', () {
      expect(parseKeyedInt('GMFI1=+00300', 'GMFI1'), 300);
      expect(parseKeyedInt('GMFI1=-00240', 'GMFI1'), -240);
      expect(parseKeyedInt('GMFI1=bad', 'GMFI1'), isNull);
      expect(parseKeyedDouble('GMKS0=+1.5', 'GMKS0'), 1.5);
      expect(parseKeyedDouble('GMKS8=-2.3', 'GMKS8'), -2.3);
    });
  });

  group('Quad Pixel Drive tiers', () {
    test('Tier A matches by numeric code regardless of suffix', () {
      for (final m in ['PT-RQ35K', 'PT-RQ35KL', 'PT-RQ35K2', 'PT-RQ25KE']) {
        expect(quadPixelTierFor(m), QuadPixelTier.a, reason: m);
      }
    });
    test('Tier B', () {
      expect(quadPixelTierFor('PT-RQ32K'), QuadPixelTier.b);
      expect(quadPixelTierFor('PT-RQ13KE'), QuadPixelTier.b);
    });
    test('unrelated models', () {
      for (final m in ['PT-RZ120', 'PT-MZ20K', '']) {
        expect(quadPixelTierFor(m), QuadPixelTier.none, reason: m);
      }
    });
  });

  group('Corner Correction canvas maths', () {
    for (final extended in [false, true]) {
      final label = extended ? 'Tier A' : 'standard';

      test('$label: raw → canvas → raw round-trips', () {
        for (final inwardIsPositive in [true, false]) {
          for (var raw = -960; raw <= 960; raw += 7) {
            final canvas = cornerToCanvas(
              raw,
              inwardIsPositive: inwardIsPositive,
              extended: extended,
            );
            expect(
              cornerToRaw(
                canvas,
                inwardIsPositive: inwardIsPositive,
                extended: extended,
              ),
              raw,
            );
          }
        }
      });

      test('$label: canvas bounds land exactly on protocol limits', () {
        // Inward reach is 80px H / 50px V on every model; outward 64 / 40.
        expect(
          cornerToRaw(80, inwardIsPositive: true, extended: extended),
          cornerInwardH(extended: extended),
        );
        expect(
          cornerToRaw(50, inwardIsPositive: true, extended: extended),
          cornerInwardV(extended: extended),
        );
        expect(
          cornerToRaw(-64, inwardIsPositive: true, extended: extended),
          -cornerOutwardH,
        );
        expect(
          cornerToRaw(-40, inwardIsPositive: true, extended: extended),
          -cornerOutwardV,
        );
        // Right/bottom corners: inward is the negative direction.
        expect(
          cornerToRaw(-80, inwardIsPositive: false, extended: extended),
          -cornerInwardH(extended: extended),
        );
        expect(
          cornerToRaw(64, inwardIsPositive: false, extended: extended),
          cornerOutwardH,
        );
      });
    }

    test('limits', () {
      expect(cornerInwardH(extended: false), 480);
      expect(cornerInwardV(extended: false), 300);
      expect(cornerInwardH(extended: true), 960);
      expect(cornerInwardV(extended: true), 600);
      expect(cornerOutwardH, 384);
      expect(cornerOutwardV, 240);
    });

    test('Tier A doubles precision inward only', () {
      expect(
        cornerToCanvas(960, inwardIsPositive: true, extended: true),
        cornerToCanvas(480, inwardIsPositive: true, extended: false),
      );
      expect(
        cornerToCanvas(-384, inwardIsPositive: true, extended: true),
        cornerToCanvas(-384, inwardIsPositive: true, extended: false),
      );
    });
  });
}
