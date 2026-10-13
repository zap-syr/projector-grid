/// Pair mode of the Edge Blending dialog: two projectors that meet along one
/// edge pair (plan/EDGE_BLENDING_PLAN.md §9).
library;

import 'dart:math';

import 'blend_edge.dart';
import 'edge_blend_limits.dart';
import 'projector_node.dart';

/// How the two rasters sit; A is the left / upper one.
enum PairArrangement {
  sideBySide('Side by side', facingA: BlendEdge.right, facingB: BlendEdge.left),
  stacked('Stacked', facingA: BlendEdge.lower, facingB: BlendEdge.upper);

  final String label;

  /// The edges that blend into each other: A.Right ↔ B.Left side by side,
  /// A.Lower ↔ B.Upper stacked.
  final BlendEdge facingA;
  final BlendEdge facingB;

  const PairArrangement(
    this.label, {
    required this.facingA,
    required this.facingB,
  });

  /// The facing edge of side [index] (0 = A, 1 = B).
  BlendEdge facingOf(int index) => index == 0 ? facingA : facingB;
}

/// Who the dialog opens for: the clicked card's selection when it has
/// exactly two projectors, else the clicked card alone.
List<ProjectorNode> edgeBlendTargets(
  ProjectorNode clicked,
  Set<String> selectedIds,
  List<ProjectorNode> all,
) {
  if (!selectedIds.contains(clicked.id) || selectedIds.length != 2) {
    return [clicked];
  }
  return all.where((n) => selectedIds.contains(n.id)).toList();
}

/// The first guess from the cards on the workspace: the axis with the bigger
/// centre distance wins (side by side on a tie), and A is the left / upper
/// card. [swapped] means [second] is A.
({PairArrangement arrangement, bool swapped}) guessPairArrangement(
  ({double x, double y}) first,
  ({double x, double y}) second,
) {
  final dx = second.x - first.x;
  final dy = second.y - first.y;
  return dx.abs() >= dy.abs()
      ? (arrangement: PairArrangement.sideBySide, swapped: dx < 0)
      : (arrangement: PairArrangement.stacked, swapped: dy < 0);
}

/// Link mirrors widths, which are in each projector's own raster units: with
/// different rasters a fixed ratio would be a guess.
bool canLinkRasters(EdgeBlendRaster a, EdgeBlendRaster b) => a == b;

/// A linked value has to fit both projectors.
int linkedMax(int a, int b) => min(a, b);

/// The pair canvas in raster lengths along the arrangement axis (one raster
/// = 1): A sits at 0, B at the returned offset. The rasters overlap by
/// Start(A) + Width(A) + Start(B) of the facing edges, so A's zone end lands
/// on B's Start line and the two ramps cover the same pixels (A's width when
/// the widths differ). Each value is taken as a fraction of its own
/// projector's span, so mixed rasters line up too.
double pairOffsetB({
  required int startA,
  required int widthA,
  required int spanA,
  required int startB,
  required int spanB,
}) => 1 - ((startA + widthA) / spanA + startB / spanB);

/// The fixed extent the canvas scales to, in raster lengths: two rasters
/// with no overlap along the axis. Moving a facing value only slides B
/// inside it, nothing rescales mid-drag.
({double h, double v}) pairExtent(PairArrangement arrangement) =>
    switch (arrangement) {
      PairArrangement.sideBySide => (h: 2, v: 1),
      PairArrangement.stacked => (h: 1, v: 2),
    };
