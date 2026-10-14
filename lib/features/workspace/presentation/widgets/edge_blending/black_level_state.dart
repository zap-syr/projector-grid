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

/// The channels the dialog edits. The wire tuple also carries W, which does
/// nothing to the image: it is only the OSD's "all channels" slider (§8 "W
/// channel"), written the way VSS writes it (see [RgbwLevel.withChannel]).
enum RgbChannel { r, g, b }

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

  /// R, G and B move together. The projector doesn't enforce it (§8), the
  /// dialog does: see [withChannel].
  final bool interlocked;

  const RgbwLevel({required this.value, required this.interlocked});

  /// The channel as the projector holds it. While Interlocked a tuple set
  /// elsewhere may disagree; it's shown as is and evened out by the next
  /// change.
  int channel(RgbChannel c) => switch (c) {
    RgbChannel.r => value.r,
    RgbChannel.g => value.g,
    RgbChannel.b => value.b,
  };

  /// Written as VSS writes it, so the OSD shows the same: Interlocked sets
  /// every channel, W included (`V,V,V,V`); otherwise one channel changes
  /// and W is 0.
  RgbwLevel withChannel(RgbChannel c, int v) => RgbwLevel(
    interlocked: interlocked,
    value: interlocked
        ? (w: v, r: v, g: v, b: v)
        : switch (c) {
            RgbChannel.r => (w: 0, r: v, g: value.g, b: value.b),
            RgbChannel.g => (w: 0, r: value.r, g: v, b: value.b),
            RgbChannel.b => (w: 0, r: value.r, g: value.g, b: v),
          },
  );

  /// Interlocked turned on (R, G and B evened out to R) or off (W to 0),
  /// both as VSS leaves the tuple.
  RgbwLevel withInterlocked(bool on) => RgbwLevel(
    interlocked: on,
    value: on
        ? (w: value.r, r: value.r, g: value.r, b: value.r)
        : (w: 0, r: value.r, g: value.g, b: value.b),
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

/// The Black Level tab's levels for one projector. The border widths live
/// with Start and Width in `EdgeSettings`.
@immutable
class BlackLevelState {
  final BlackLevelMode mode;
  final Map<LevelSlot, RgbwLevel> levels;

  const BlackLevelState({required this.mode, required this.levels});

  RgbwLevel operator [](LevelSlot slot) => levels[slot]!;

  BlackLevelState copyWith({BlackLevelMode? mode}) =>
      BlackLevelState(mode: mode ?? this.mode, levels: levels);

  BlackLevelState withLevel(LevelSlot slot, RgbwLevel level) =>
      BlackLevelState(mode: mode, levels: {...levels, slot: level});
}

/// Queries for [BlackLevelState], in the order [parseBlackLevelState] reads
/// them. Sent only when the tab is first opened.
List<String> blackLevelQueries() => [
  'QVX:EBMI1',
  for (final s in LevelSlot.values) s.query,
  for (final s in LevelSlot.values) 'QVX:${s.interlockKey}',
];

/// Replies of [blackLevelQueries] → the state; a missing reply reads as 0 /
/// off, like `parseEdgeBlendState`.
BlackLevelState parseBlackLevelState(List<String?> r) {
  const slots = LevelSlot.values;
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
  );
}
