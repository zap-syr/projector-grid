import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/group_naming.dart';
import 'package:projector_grid/features/workspace/domain/group_palette.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';

void main() {
  group('groupPalette', () {
    test('48 distinct colours', () {
      expect(groupPalette, hasLength(48));
      expect(groupPalette.toSet(), hasLength(48));
    });

    test('keeps every colour of the old 24-colour palette', () {
      const old = [
        0xFFF87171, 0xFFFB923C, 0xFFFBBF24, 0xFF4ADE80, 0xFF2DD4BF, //
        0xFF60A5FA, 0xFFA78BFA, 0xFFF472B6, 0xFFEF4444, 0xFFF97316, //
        0xFFF59E0B, 0xFF22C55E, 0xFF14B8A6, 0xFF3B82F6, 0xFF8B5CF6, //
        0xFFEC4899, 0xFFB91C1C, 0xFFC2410C, 0xFFB45309, 0xFF15803D, //
        0xFF0F766E, 0xFF1D4ED8, 0xFF6D28D9, 0xFFBE185D,
      ];
      expect(groupPalette, containsAll(old));
    });

    test('names follow hue and tone', () {
      expect(groupPaletteName(0), 'Red light');
      expect(groupPaletteName(17), 'Orange');
      expect(groupPaletteName(47), 'Pink dark');
    });
  });

  group('firstUnusedGroupColor', () {
    test('no groups: the first base tone', () {
      expect(firstUnusedGroupColor(const []), 0xFFEF4444);
    });

    test('skips used colours in palette order', () {
      expect(firstUnusedGroupColor(const [0xFFEF4444, 0xFFF97316]), 0xFFF59E0B);
    });

    test('base row full: moves on to the light row', () {
      final base = groupPalette.sublist(16, 32);
      expect(firstUnusedGroupColor(base), 0xFFF87171);
    });

    test('every colour used: falls back to the first base tone', () {
      expect(firstUnusedGroupColor(groupPalette), 0xFFEF4444);
    });
  });

  group('group names', () {
    const groups = [
      ProjectorGroup(
        id: 'a',
        name: 'Left wall',
        color: 0,
        oscAddress: '/group/left-wall',
      ),
    ];

    test('OSC address from the name', () {
      expect(groupOscAddress('  Main Stage 2 '), '/group/main-stage-2');
    });

    test('empty and taken names are rejected', () {
      expect(groupNameError('  ', groups), isNotNull);
      expect(groupNameError('left WALL', groups), isNotNull);
      expect(groupNameError('Left-wall', groups), isNotNull);
      expect(groupNameError('Right wall', groups), isNull);
    });

    test('a group may keep its own name', () {
      expect(groupNameError('Left wall', groups, exceptId: 'a'), isNull);
    });
  });
}
