/// Which part of the image each black level covers, as the projector applies
/// it (plan/EDGE_BLENDING_PLAN.md §8 "Black level zones", RQ25K by eye):
/// from an enabled edge inwards, the raster edge to Start stays black, Start
/// to the zone end gets the overlapped level, the zone end to the border
/// line gets the overlapped and border levels added up, and everything
/// inside all border lines the non-overlapped level. The same in both Black
/// Level Modes; a disabled edge has no bands at all.
library;

import 'dart:math';

import 'edge_blend_limits.dart';
import 'edge_blend_values.dart';

/// One enabled edge's band boundaries, in units in from its raster edge.
typedef BlendBands = ({int start, int end, int line});

BlendBands blendBands({
  required int start,
  required int width,
  required int border,
}) => (
  start: start,
  end: start + width,
  line: blendLineDepth(start: start, width: width, border: border),
);

/// The band between the zone end and the border line: overlapped + border
/// per channel, capped at the top of the range (seen as magenta for
/// overlapped red + border blue).
Rgbw stackLevels(Rgbw overlapped, Rgbw border) => (
  w: min(255, overlapped.w + border.w),
  r: min(255, overlapped.r + border.r),
  g: min(255, overlapped.g + border.g),
  b: min(255, overlapped.b + border.b),
);
