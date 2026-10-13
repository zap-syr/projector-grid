import 'package:flutter/foundation.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_values.dart';
import '../../../domain/geometry_values.dart';

/// `VXX:EBMI1`: whether the blend zones get the soft edge or only the black
/// level lift.
enum BlackLevelMode {
  softEdgeAndBlack('Soft edge + Black level'),
  blackOnly('Black level only');

  final String label;
  const BlackLevelMode(this.label);

  static BlackLevelMode fromProtocol(int? v) =>
      v == 1 ? blackOnly : softEdgeAndBlack;
}

enum RgbwChannel { w, r, g, b }

/// Where a black level lives: the non-overlapped area, the black border, or
/// one edge's overlapped zone. Each has a `W,R,G,B` tuple and an
/// Interlocked flag.
enum LevelSlot {
  nonOverlapped(null),
  border(null),
  upper(BlendEdge.upper),
  lower(BlendEdge.lower),
  left(BlendEdge.left),
  right(BlendEdge.right);

  /// The edge of an overlapped slot, null for the other two.
  final BlendEdge? edge;
  const LevelSlot(this.edge);

  static LevelSlot overlap(BlendEdge edge) => switch (edge) {
    BlendEdge.upper => upper,
    BlendEdge.lower => lower,
    BlendEdge.left => left,
    BlendEdge.right => right,
  };

  String get query => switch (this) {
    nonOverlapped => 'QJI',
    border => 'QJO',
    _ => 'QVX:${edge!.overlapKey}',
  };

  String command(Rgbw v) => switch (this) {
    nonOverlapped => 'VJI:${formatRgbw(v)}',
    border => 'VJO:${formatRgbw(v)}',
    _ => 'VXX:${edge!.overlapKey}=${formatRgbw(v)}',
  };

  String get interlockKey => switch (this) {
    nonOverlapped => 'EBII1',
    border => 'EBII2',
    _ => edge!.overlapInterlockKey,
  };
}

const Rgbw _black = (w: 0, r: 0, g: 0, b: 0);

@immutable
class RgbwLevel {
  final Rgbw value;

  /// W drives all four channels. The projector doesn't enforce it (§8), the
  /// dialog does: see [withChannel].
  final bool interlocked;

  const RgbwLevel({required this.value, required this.interlocked});

  /// What a channel reads as: while Interlocked that's W, even if a tuple
  /// set elsewhere disagrees (left alone until the user changes it).
  int shown(RgbwChannel c) => interlocked
      ? value.w
      : switch (c) {
          RgbwChannel.w => value.w,
          RgbwChannel.r => value.r,
          RgbwChannel.g => value.g,
          RgbwChannel.b => value.b,
        };

  /// Interlocked: every write is `W,W,W,W`, so any channel sets all four.
  RgbwLevel withChannel(RgbwChannel c, int v) => RgbwLevel(
    interlocked: interlocked,
    value: interlocked
        ? (w: v, r: v, g: v, b: v)
        : switch (c) {
            RgbwChannel.w => (w: v, r: value.r, g: value.g, b: value.b),
            RgbwChannel.r => (w: value.w, r: v, g: value.g, b: value.b),
            RgbwChannel.g => (w: value.w, r: value.r, g: v, b: value.b),
            RgbwChannel.b => (w: value.w, r: value.r, g: value.g, b: v),
          },
  );

  RgbwLevel copyWith({Rgbw? value, bool? interlocked}) => RgbwLevel(
    value: value ?? this.value,
    interlocked: interlocked ?? this.interlocked,
  );

  @override
  bool operator ==(Object other) =>
      other is RgbwLevel &&
      other.value == value &&
      other.interlocked == interlocked;

  @override
  int get hashCode => Object.hash(value, interlocked);
}

/// The Black Level tab's values for one projector.
@immutable
class BlackLevelState {
  final BlackLevelMode mode;
  final Map<LevelSlot, RgbwLevel> levels;
  final Map<BlendEdge, int> borderWidths;

  const BlackLevelState({
    required this.mode,
    required this.levels,
    required this.borderWidths,
  });

  RgbwLevel operator [](LevelSlot slot) => levels[slot]!;

  int borderWidth(BlendEdge edge) => borderWidths[edge]!;

  BlackLevelState copyWith({BlackLevelMode? mode}) => BlackLevelState(
    mode: mode ?? this.mode,
    levels: levels,
    borderWidths: borderWidths,
  );

  BlackLevelState withLevel(LevelSlot slot, RgbwLevel level) => BlackLevelState(
    mode: mode,
    levels: {...levels, slot: level},
    borderWidths: borderWidths,
  );

  BlackLevelState withBorderWidth(BlendEdge edge, int v) => BlackLevelState(
    mode: mode,
    levels: levels,
    borderWidths: {...borderWidths, edge: v},
  );
}

/// Queries for [BlackLevelState], in the order [parseBlackLevelState] reads
/// them. Sent only when the tab is first opened.
List<String> blackLevelQueries() => [
  'QVX:EBMI1',
  for (final s in LevelSlot.values) s.query,
  for (final s in LevelSlot.values) 'QVX:${s.interlockKey}',
  for (final e in BlendEdge.values) 'Q${e.borderCmd}',
];

/// Replies of [blackLevelQueries] → the state; a missing reply reads as 0 /
/// off, like `parseEdgeBlendState`.
BlackLevelState parseBlackLevelState(List<String?> r) {
  const slots = LevelSlot.values;
  const edges = BlendEdge.values;
  final n = slots.length;
  return BlackLevelState(
    mode: BlackLevelMode.fromProtocol(parseKeyedInt(r[0], 'EBMI1')),
    levels: {
      for (var i = 0; i < n; i++)
        slots[i]: RgbwLevel(
          value: parseRgbw(r[1 + i]) ?? _black,
          interlocked: parseKeyedInt(r[1 + n + i], slots[i].interlockKey) == 1,
        ),
    },
    borderWidths: {
      for (var i = 0; i < edges.length; i++)
        edges[i]: parseKeyedInt(r[1 + 2 * n + i], edges[i].borderCmd) ?? 0,
    },
  );
}
