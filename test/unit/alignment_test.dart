import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alignment.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/test_patterns.dart';

ProjectorNode _n(String id, double x) =>
    ProjectorNode(id: id, name: id, ipAddress: '10.0.0.1', x: x, y: 0);

void main() {
  // One row: a | b | c | d, 20 px apart.
  final row = [_n('a', 0), _n('b', 140), _n('c', 280), _n('d', 420)];
  final all = {'a', 'b', 'c', 'd'};

  Map<String, AlignmentRole> roles({
    Set<String>? scope,
    String focused = 'b',
    bool showAll = false,
    bool showNeighbours = false,
    Set<String> manual = const {},
  }) => alignmentRoles(
    nodes: row,
    scope: scope ?? all,
    focusedId: focused,
    showAll: showAll,
    showNeighbours: showNeighbours,
    includeDiagonals: false,
    manualNeighbours: manual,
  );

  const f = AlignmentRole.focused;
  const s = AlignmentRole.shown;
  const x = AlignmentRole.closed;

  group('alignmentRoles', () {
    test('solo: only the focused projector is open', () {
      expect(roles(), {'a': x, 'b': f, 'c': x, 'd': x});
    });

    test('neighbours open next to the focused one', () {
      expect(roles(showNeighbours: true), {'a': s, 'b': f, 'c': s, 'd': x});
    });

    test('Show All opens everyone and wins over neighbours', () {
      expect(roles(showAll: true, showNeighbours: true), {
        'a': s,
        'b': f,
        'c': s,
        'd': s,
      });
    });

    test('manual picks add a card or hide a detected neighbour', () {
      expect(roles(showNeighbours: true, manual: {'c', 'd'}), {
        'a': s,
        'b': f,
        'c': x,
        'd': s,
      });
    });

    test('projectors outside the scope get no role', () {
      expect(roles(scope: {'a', 'b'}, showAll: true), {'a': s, 'b': f});
    });
  });

  group('outputs and commands', () {
    test('Others falls back to the focused pattern', () {
      expect(
        outputFor(
          AlignmentRole.shown,
          focusedPattern: 'OTS:01',
          othersPattern: null,
        ),
        (open: true, pattern: 'OTS:01'),
      );
      expect(
        outputFor(
          AlignmentRole.closed,
          focusedPattern: 'OTS:01',
          othersPattern: 'OTS:70',
        ),
        (open: false, pattern: null),
      );
    });

    test('pattern is sent before the shutter opens', () {
      expect(
        commandsFor(
          (open: false, pattern: 'OTS:00'),
          (open: true, pattern: 'OTS:07'),
        ),
        ['OTS:07', 'OSH:0'],
      );
    });

    test('closing leaves the pattern alone; no-op when already there', () {
      expect(
        commandsFor(
          (open: true, pattern: 'OTS:07'),
          (open: false, pattern: null),
        ),
        ['OSH:1'],
      );
      expect(
        commandsFor(
          (open: true, pattern: 'OTS:07'),
          (open: true, pattern: 'OTS:07'),
        ),
        isEmpty,
      );
    });
  });

  group('presets', () {
    test('Geometry offers cross hatches, Color solid colours', () {
      expect(AlignmentPreset.geometry.patterns, contains('OTS:70'));
      expect(AlignmentPreset.geometry.patterns, isNot(contains('OTS:01')));
      expect(AlignmentPreset.color.patterns, contains('OTS:01'));
      expect(AlignmentPreset.color.defaultOthers, isNull);
      expect(
        AlignmentPreset.custom.patterns,
        containsAll(kTestPatternLabels.keys),
      );
    });
  });

  group('parsing', () {
    test('QTS reply → OTS code', () {
      expect(parseTestPattern('07'), 'OTS:07');
      expect(parseTestPattern('00'), 'OTS:00');
      expect(parseTestPattern(null), isNull);
      expect(parseTestPattern('ER401'), isNull);
    });

    test('unknown pattern codes still get a label', () {
      expect(testPatternLabel('OTS:70'), 'Cross Hatch Red');
      expect(testPatternLabel('OTS:52'), 'Pattern 52');
    });

    test('shutter fade reply', () {
      expect(parseShutterFade('SEFS1=2.0'), '2.0');
      expect(parseShutterFade('SEFS2=10.0'), '10.0');
      expect(parseShutterFade('ER401'), isNull);
      expect(parseShutterFade(null), isNull);
      expect(isZeroFade('0.0'), isTrue);
      expect(isZeroFade('0.5'), isFalse);
    });
  });
}
