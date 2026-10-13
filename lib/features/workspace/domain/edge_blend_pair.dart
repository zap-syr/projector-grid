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

/// One facing edge as the pair layout reads it. A disabled edge darkens
/// nothing on the projector, so it adds nothing to the overlap.
typedef FacingEdge = ({bool enabled, int start, int width, int span});

/// The overlap the facing settings imply, in raster lengths (one raster
/// = 1): Start(A) + Start(B) + the wider of the two widths. The real
/// overlap is set on the screen with the markers and never known in
/// pixels, so this only shows what the values describe, not whether they
/// match the screen. Each value is a fraction of its own projector's span,
/// so mixed rasters line up too.
double pairOverlap(FacingEdge a, FacingEdge b) {
  double start(FacingEdge e) => e.enabled ? e.start / e.span : 0;
  double width(FacingEdge e) => e.enabled ? e.width / e.span : 0;
  return start(a) + start(b) + max(width(a), width(b));
}

/// Where A and B start along the axis, in raster lengths inside
/// [pairExtent]: the pair is centred, so a change in [overlap] moves both
/// rasters by half of it, towards or away from each other.
({double a, double b}) pairPositions(double overlap) =>
    (a: overlap / 2, b: 1 - overlap / 2);

/// The fixed extent the canvas scales to, in raster lengths: two rasters
/// with no overlap along the axis. A change in the overlap only moves the
/// rasters inside it, nothing rescales mid-drag.
({double h, double v}) pairExtent(PairArrangement arrangement) =>
    switch (arrangement) {
      PairArrangement.sideBySide => (h: 2, v: 1),
      PairArrangement.stacked => (h: 1, v: 2),
    };
