import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/geometry_modes.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

void main() {
  group('GeometryMode', () {
    test('protocol values round-trip for all seven modes', () {
      expect(GeometryMode.values, hasLength(7));
      for (final m in GeometryMode.values) {
        expect(GeometryMode.fromProtocol(m.protocolValue), m);
      }
    });

    test('the PC memories are +00003 to +00005', () {
      expect(GeometryMode.pc1.protocolValue, '+00003');
      expect(GeometryMode.pc2.protocolValue, '+00004');
      expect(GeometryMode.pc3.protocolValue, '+00005');
      expect(GeometryMode.fromProtocol(' +00004 '), GeometryMode.pc2);
      expect(GeometryMode.fromProtocol('+00006'), GeometryMode.off);
    });

    test('a PC mode is the free grid and knows its warp memory', () {
      expect(GeometryMode.pc1.isFreeGrid, isTrue);
      expect(GeometryMode.pc2.isFreeGrid, isTrue);
      expect(GeometryMode.pc3.isFreeGrid, isTrue);
      for (final m in GeometryMode.tileModes) {
        expect(m.isFreeGrid, isFalse);
        expect(m.warpSlot, isNull);
      }
      expect(GeometryMode.pc1.warpSlot, WarpSlot.pc1);
      expect(GeometryMode.pc2.warpSlot, WarpSlot.pc2);
      expect(GeometryMode.pc3.warpSlot, WarpSlot.pc3);
    });

    test('the memory of a slot maps back to its mode', () {
      expect(GeometryMode.forWarpSlot(WarpSlot.pc1), GeometryMode.pc1);
      expect(GeometryMode.forWarpSlot(WarpSlot.pc2), GeometryMode.pc2);
      expect(GeometryMode.forWarpSlot(WarpSlot.pc3), GeometryMode.pc3);
      expect(() => GeometryMode.forWarpSlot(WarpSlot.ram), throwsArgumentError);
    });

    test('the PC modes have labels and no registers to read', () {
      expect(GeometryMode.pc1.label, 'PC-1');
      expect(GeometryMode.pc2.label, 'PC-2');
      expect(GeometryMode.pc3.label, 'PC-3');
      for (final m in [GeometryMode.pc1, GeometryMode.pc2, GeometryMode.pc3]) {
        expect(m.shortLabel, m.label);
        expect(m.valueCount, 0);
      }
    });

    test(
      'the tile list is Off, Keystone, Curved, Corner without PC values',
      () {
        expect(GeometryMode.tileModes, [
          GeometryMode.off,
          GeometryMode.keystone,
          GeometryMode.curved,
          GeometryMode.corner,
        ]);
      },
    );
  });
}
