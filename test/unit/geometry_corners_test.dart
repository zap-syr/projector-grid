import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/geometry_corners.dart';
import 'package:projector_grid/features/workspace/domain/geometry_modes.dart';
import 'package:projector_grid/features/workspace/domain/geometry_values.dart';

void main() {
  group('GeometryMode', () {
    test('protocol values round-trip, unknown reads as Off', () {
      for (final m in GeometryMode.values) {
        expect(GeometryMode.fromProtocol(m.protocolValue), m);
      }
      expect(GeometryMode.fromProtocol(' +00010 '), GeometryMode.corner);
      expect(GeometryMode.fromProtocol('+00099'), GeometryMode.off);
    });

    test('short labels for the narrow row', () {
      expect(GeometryMode.curved.shortLabel, 'Curved');
      expect(GeometryMode.corner.shortLabel, 'Corner');
      expect(GeometryMode.keystone.shortLabel, GeometryMode.keystone.label);
    });

    test('Reset registers keep throw ratio and aspect ratio', () {
      expect(keystoneResetRegisters.map((r) => r.$1), [
        'GMKS8',
        'GMKS9',
        'GMKI4',
        'GMKI7',
      ]);
      expect(curvedResetRegisters.map((r) => r.$1), [
        'GMCI2',
        'GMCI3',
        'GMCI6',
        'GMCI7',
        'GMCS8',
        'GMCS9',
      ]);
      // Degrees for the keystone angles only.
      expect(
        [
          ...keystoneResetRegisters,
          ...curvedResetRegisters,
        ].where((r) => r.$2).map((r) => r.$1),
        ['GMKS8', 'GMKS9', 'GMCS8', 'GMCS9'],
      );
    });

    test('Quad Pixel Drive note by tier', () {
      expect(quadPixelDriveNote(QuadPixelTier.a), contains('wider inward'));
      expect(
        quadPixelDriveNote(QuadPixelTier.b),
        'turns on by itself when you choose a mode.',
      );
      expect(quadPixelDriveNote(QuadPixelTier.none), isNull);
    });
  });

  group('corner ranges', () {
    test('standard model', () {
      expect(cornerRangeH(GeometryCorner.ul, extended: false), (
        min: -384,
        max: 480,
      ));
      expect(cornerRangeH(GeometryCorner.ur, extended: false), (
        min: -480,
        max: 384,
      ));
      expect(cornerRangeV(GeometryCorner.ul, extended: false), (
        min: -240,
        max: 300,
      ));
      expect(cornerRangeV(GeometryCorner.lr, extended: false), (
        min: -300,
        max: 240,
      ));
    });

    test('Tier A doubles only the inward side', () {
      expect(cornerRangeH(GeometryCorner.ll, extended: true), (
        min: -384,
        max: 960,
      ));
      expect(cornerRangeV(GeometryCorner.ll, extended: true), (
        min: -600,
        max: 240,
      ));
    });

    test('clamp', () {
      expect(clampCornerH(GeometryCorner.ul, 2000, extended: false), 480);
      expect(clampCornerH(GeometryCorner.ul, -2000, extended: false), -384);
      expect(clampCornerV(GeometryCorner.lr, -2000, extended: true), -600);
    });
  });

  group('canvas mapping', () {
    test('zero sits on the default frame corners', () {
      expect(
        cornerCanvasPosition(GeometryCorner.ul, 0, 0, extended: false),
        const Offset(80, 50),
      );
      expect(
        cornerCanvasPosition(GeometryCorner.lr, 0, 0, extended: true),
        const Offset(400, 250),
      );
    });

    test('bounds are the old fixed rectangles and the outer limit', () {
      expect(
        cornerBounds(GeometryCorner.ul),
        const Rect.fromLTRB(16, 10, 160, 100),
      );
      expect(
        cornerBounds(GeometryCorner.ur),
        const Rect.fromLTRB(320, 10, 464, 100),
      );
      expect(
        cornerBounds(GeometryCorner.ll),
        const Rect.fromLTRB(16, 200, 160, 290),
      );
      expect(
        cornerBounds(GeometryCorner.lr),
        const Rect.fromLTRB(320, 200, 464, 290),
      );
      expect(cornerOuterLimit, const Rect.fromLTRB(16, 10, 464, 290));
    });

    test('the edges of the bounds are the protocol limits', () {
      for (final extended in [false, true]) {
        for (final c in GeometryCorner.values) {
          final b = cornerBounds(c);
          final h = cornerRangeH(c, extended: extended);
          final v = cornerRangeV(c, extended: extended);
          expect(cornerRawFromCanvas(c, b.topLeft, extended: extended), (
            h.min,
            v.min,
          ));
          expect(cornerRawFromCanvas(c, b.bottomRight, extended: extended), (
            h.max,
            v.max,
          ));
        }
      }
    });

    test('a position past the bounds is held at them', () {
      expect(
        cornerRawFromCanvas(
          GeometryCorner.ul,
          const Offset(-500, 900),
          extended: false,
        ),
        (-384, 300),
      );
    });

    test('raw to canvas and back', () {
      for (final extended in [false, true]) {
        for (final (h, v) in [(0, 0), (120, -60), (-240, 180), (300, 240)]) {
          final c = GeometryCorner.ul;
          final p = cornerCanvasPosition(c, h, v, extended: extended);
          expect(cornerRawFromCanvas(c, p, extended: extended), (h, v));
        }
      }
    });
  });

  test('selection label', () {
    expect(cornerSelectionLabel({}), isNull);
    expect(cornerSelectionLabel({GeometryCorner.ur}), 'Upper right');
    expect(
      cornerSelectionLabel({GeometryCorner.ur, GeometryCorner.ll}),
      '2 selected',
    );
  });
}
