import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/card_layout.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';

ProjectorNode _n(String id, double x, double y) =>
    ProjectorNode(id: id, name: id, ipAddress: '10.0.0.1', x: x, y: y);

/// The auto-layout grid from WorkspaceNotifier.addProjectors: 120×100 cards,
/// 20 px horizontal / 40 px vertical gaps.
List<ProjectorNode> _grid(int cols, int rows) => [
  for (var r = 0; r < rows; r++)
    for (var c = 0; c < cols; c++) _n('$r$c', 40 + c * 140.0, 40 + r * 140.0),
];

void main() {
  group('layoutOrder', () {
    test('reads left→right, top→bottom', () {
      final nodes = _grid(3, 2).reversed.toList();
      expect(layoutOrder(nodes).map((n) => n.id), [
        '00',
        '01',
        '02',
        '10',
        '11',
        '12',
      ]);
    });

    test('a card slightly lower stays in its row', () {
      final nodes = [_n('b', 180, 80), _n('a', 40, 40), _n('c', 40, 200)];
      expect(layoutOrder(nodes).map((n) => n.id), ['a', 'b', 'c']);
    });
  });

  group('neighbours', () {
    test('default auto-grid: four sides of a middle card', () {
      final nodes = _grid(3, 3);
      final middle = nodes.firstWhere((n) => n.id == '11');
      expect(neighbours(middle, nodes), {'01', '10', '12', '21'});
    });

    test('diagonals add the corners', () {
      final nodes = _grid(3, 3);
      final middle = nodes.firstWhere((n) => n.id == '11');
      expect(neighbours(middle, nodes, diagonals: true), {
        '00',
        '01',
        '02',
        '10',
        '12',
        '20',
        '21',
        '22',
      });
    });

    test('corner card of the grid', () {
      final nodes = _grid(3, 3);
      expect(neighbours(nodes.first, nodes), {'01', '10'});
    });

    test('staggered row: half a row lower still counts, a full row not', () {
      final a = _n('a', 0, 0);
      final half = _n('half', 140, 50); // 50 px vertical overlap
      final far = _n('far', 0, 250); // below, gap 150
      expect(neighbours(a, [a, half, far]), {'half'});
      final less = _n('less', 140, 60); // 40 px overlap < 50 %
      expect(neighbours(a, [a, less]), isEmpty);
    });

    test('gap wider than 60 px is not a neighbour', () {
      final a = _n('a', 0, 0);
      expect(neighbours(a, [a, _n('b', 181, 0)]), isEmpty);
      expect(neighbours(a, [a, _n('b', 180, 0)]), {'b'});
    });

    test('only the nearest card per side', () {
      final nodes = [_n('a', 0, 0), _n('b', 140, 0), _n('c', 280, 0)];
      expect(neighbours(nodes.first, nodes), {'b'});
    });

    test('single card has no neighbours', () {
      final a = _n('a', 0, 0);
      expect(neighbours(a, [a]), isEmpty);
    });
  });
}
