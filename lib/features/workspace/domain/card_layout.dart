/// Card geometry on the Controls canvas and the pure layout rules built on
/// it: reading order and neighbour detection for Alignment mode.
library;

import 'dart:math' show max, min;

import 'projector_node.dart';

const double kCardWidth = 120;
const double kCardHeight = 100;

/// Cards sorted left→right, top→bottom. Cards whose tops are within half a
/// card height of a row's first card count as the same row, so a card
/// dragged a few pixels lower doesn't jump to the next row.
List<ProjectorNode> layoutOrder(Iterable<ProjectorNode> nodes) {
  final byY = [...nodes]
    ..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
  final result = <ProjectorNode>[];
  var row = <ProjectorNode>[];
  double? rowTop;
  for (final n in byY) {
    if (rowTop != null && n.y - rowTop > kCardHeight / 2) {
      result.addAll(row..sort((a, b) => a.x.compareTo(b.x)));
      row = [];
      rowTop = null;
    }
    rowTop ??= n.y;
    row.add(n);
  }
  result.addAll(row..sort((a, b) => a.x.compareTo(b.x)));
  return result;
}

/// Ids of [focused]'s neighbours among [nodes]: per side (left / right /
/// above / below) the nearest card within [maxGap] edge to edge that
/// overlaps the focused card by at least [minOverlap] on the other axis.
/// With [diagonals], also the nearest card per corner that is within
/// [maxGap] on both axes but overlaps less than [minOverlap] on either.
Set<String> neighbours(
  ProjectorNode focused,
  Iterable<ProjectorNode> nodes, {
  double maxGap = 60,
  double minOverlap = 0.5,
  bool diagonals = false,
}) {
  final minH = kCardWidth * minOverlap;
  final minV = kCardHeight * minOverlap;
  final fcx = focused.x + kCardWidth / 2;
  final fcy = focused.y + kCardHeight / 2;

  // Best candidate per side / corner: key → (id, distance).
  final best = <String, (String, double)>{};
  void offer(String key, String id, double distance) {
    final current = best[key];
    if (current == null || distance < current.$2) best[key] = (id, distance);
  }

  for (final n in nodes) {
    if (n.id == focused.id) continue;
    // Edge-to-edge gaps; negative when the cards overlap on that axis.
    final hGap = max(
      n.x - (focused.x + kCardWidth),
      focused.x - (n.x + kCardWidth),
    );
    final vGap = max(
      n.y - (focused.y + kCardHeight),
      focused.y - (n.y + kCardHeight),
    );
    final hOverlap =
        min(n.x + kCardWidth, focused.x + kCardWidth) - max(n.x, focused.x);
    final vOverlap =
        min(n.y + kCardHeight, focused.y + kCardHeight) - max(n.y, focused.y);
    final right = n.x + kCardWidth / 2 > fcx;
    final below = n.y + kCardHeight / 2 > fcy;

    if (hGap <= maxGap && vOverlap >= minV && hGap >= vGap) {
      offer(right ? 'right' : 'left', n.id, hGap);
    } else if (vGap <= maxGap && hOverlap >= minH && vGap > hGap) {
      offer(below ? 'below' : 'above', n.id, vGap);
    } else if (diagonals &&
        hGap >= 0 &&
        vGap >= 0 &&
        hGap <= maxGap &&
        vGap <= maxGap &&
        hOverlap < minH &&
        vOverlap < minV) {
      offer('${below ? 'b' : 't'}${right ? 'r' : 'l'}', n.id, hGap + vGap);
    }
  }
  return {for (final c in best.values) c.$1};
}
