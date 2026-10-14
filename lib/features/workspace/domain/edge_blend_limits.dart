/// Edge Blending raster and value limits (plan/EDGE_BLENDING_PLAN.md §8).
/// The app follows VSS, which is stricter than the projector itself;
/// anything set elsewhere that breaks the rule shows up as ER402 or a
/// read-back.
library;

import 'dart:math';

import 'blend_edge.dart';
import 'geometry_values.dart';

typedef EdgeBlendRaster = ({int h, int v});

/// The blend raster is a property of the model tier, not of the Quad Pixel
/// Drive toggle (§8: limits identical with QPD on and off). An unknown or
/// unreadable model gets the WUXGA raster, the smallest one.
EdgeBlendRaster edgeBlendRasterFor(String model) =>
    switch (quadPixelTierFor(model)) {
      QuadPixelTier.a => (h: 3840, v: 2400),
      // Unconfirmed: no Tier B unit tested; ER402 read-back covers it.
      QuadPixelTier.b => (h: 5120, v: 3200),
      QuadPixelTier.none => (h: 1920, v: 1200),
    };

/// The raster length [edge]'s values are measured along.
int edgeBlendSpan(EdgeBlendRaster raster, BlendEdge edge) =>
    edge.isHorizontal ? raster.h : raster.v;

/// How far in from its raster edge an edge's border line sits: the black
/// border is measured from the zone end (Start + Width), not from the
/// raster edge (§8 "Black level zones").
int blendLineDepth({
  required int start,
  required int width,
  required int border,
}) => start + width + border;

/// The ceiling of one of an edge's Start, Width or Border: as in VSS, an
/// edge's border line never passes the opposite edge's (§8 "Limits rule"),
/// so the value gets what the span leaves after [oppositeLine] and the
/// edge's own other two values ([ownRest]). The projector itself lets the
/// lines cross; this rule implies every limit it enforces.
int maxBlendValue({
  required int span,
  required int oppositeLine,
  required int ownRest,
}) => max(0, span - oppositeLine - ownRest);
