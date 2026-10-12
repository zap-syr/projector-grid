/// Edge Blending raster and value limits, from the live tests on PT-RQ25K and
/// PT-RZ34K (plan/EDGE_BLENDING_PLAN.md §8). Anything these rules don't model
/// shows up as ER402, which the dialog answers with a read-back.
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

/// Start + own width must stay within the raster.
int maxBlendStart({required int span, required int width}) =>
    max(0, span - width);

/// Bounded by the edge's own start and by the opposite edge's width (the two
/// widths share the raster); the opposite edge's start doesn't count.
int maxBlendWidth({
  required int span,
  required int start,
  required int oppositeWidth,
}) => max(0, min(span - start, span - oppositeWidth));

/// Black border width shares the raster with the edge's own blend width.
int maxBorderWidth({required int span, required int width}) =>
    max(0, span - width);
