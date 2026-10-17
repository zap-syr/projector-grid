import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/geometry_values.dart';

/// `VXX:EDBI0`: Off / On / User (the user curve lives on the projector).
enum EdgeBlendMode {
  off('Off', detail: 'No blending'),
  on('On', detail: 'Built-in blend curve'),
  user('User', detail: 'Curve stored on the projector');

  final String label;

  /// The mode tile's muted second line.
  final String detail;
  const EdgeBlendMode(this.label, {required this.detail});

  static EdgeBlendMode fromProtocol(int? v) => switch (v) {
    1 => on,
    2 => user,
    _ => off,
  };
}

/// What a canvas handle or a slider moves. [border] is the black border
/// width, edited on the Black Level tab.
enum EdgePart { start, width, border }

@immutable
class EdgeSettings {
  final bool enabled;
  final int start;
  final int width;

  /// The black border width, measured from the zone end (Start + Width).
  /// Kept here, not with the levels: it moves the edge's border line, which
  /// bounds every value of the opposite edge on both tabs (§8).
  final int border;

  const EdgeSettings({
    required this.enabled,
    required this.start,
    required this.width,
    this.border = 0,
  });

  /// The zone end, Start + Width, in units in from the raster edge.
  int get end => start + width;

  /// The border line, in units in from the raster edge.
  int get line => blendLineDepth(start: start, width: width, border: border);

  int valueOf(EdgePart part) => switch (part) {
    EdgePart.start => start,
    EdgePart.width => width,
    EdgePart.border => border,
  };

  EdgeSettings copyWith({bool? enabled, int? start, int? width, int? border}) =>
      EdgeSettings(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        width: width ?? this.width,
        border: border ?? this.border,
      );

  EdgeSettings withPart(EdgePart part, int v) => switch (part) {
    EdgePart.start => copyWith(start: v),
    EdgePart.width => copyWith(width: v),
    EdgePart.border => copyWith(border: v),
  };

  @override
  bool operator ==(Object other) =>
      other is EdgeSettings &&
      other.enabled == enabled &&
      other.start == start &&
      other.width == width &&
      other.border == border;

  @override
  int get hashCode => Object.hash(enabled, start, width, border);
}

/// The Edge Blending tab's values for one projector.
@immutable
class EdgeBlendState {
  final EdgeBlendMode mode;
  final Map<BlendEdge, EdgeSettings> edges;
  final bool markers;
  final bool autoPattern;

  const EdgeBlendState({
    required this.mode,
    required this.edges,
    required this.markers,
    required this.autoPattern,
  });

  EdgeSettings operator [](BlendEdge edge) => edges[edge]!;

  EdgeBlendState copyWith({
    EdgeBlendMode? mode,
    bool? markers,
    bool? autoPattern,
  }) => EdgeBlendState(
    mode: mode ?? this.mode,
    edges: edges,
    markers: markers ?? this.markers,
    autoPattern: autoPattern ?? this.autoPattern,
  );

  EdgeBlendState withEdge(BlendEdge edge, EdgeSettings settings) =>
      EdgeBlendState(
        mode: mode,
        edges: {...edges, edge: settings},
        markers: markers,
        autoPattern: autoPattern,
      );

  /// The slider ceiling for [part] of [edge] given every other current value
  /// (§8 "Limits rule": border lines never cross). A disabled edge counts
  /// with its stored values, which come back when it's enabled. Values set
  /// elsewhere may already break the rule; the ceiling then stays at the
  /// current value so touching it doesn't jump, it can only go down.
  int maxFor(BlendEdge edge, EdgePart part, EdgeBlendRaster raster) {
    final e = this[edge];
    final own = e.valueOf(part);
    final rule = maxBlendValue(
      span: edgeBlendSpan(raster, edge),
      oppositeLine: this[edge.opposite].line,
      ownRest: e.line - own,
    );
    return max(rule, own);
  }
}

/// Queries for [EdgeBlendState], in the order [parseEdgeBlendState] reads
/// them. `QID` rides along so the raster comes with the same batch, and the
/// border widths because the limits need them on both tabs.
List<String> edgeBlendQueries() => [
  'QVX:EDBI0',
  'QID',
  for (final e in BlendEdge.values) 'Q${e.enableCmd}',
  for (final e in BlendEdge.values) 'Q${e.startCmd}',
  for (final e in BlendEdge.values) 'QVX:${e.widthKey}',
  'QGM',
  'QVX:EATI1',
  for (final e in BlendEdge.values) 'Q${e.borderCmd}',
];

/// Replies of [edgeBlendQueries] → the state and the model's raster. A
/// missing reply falls back to off / 0, like the other settings dialogs.
(EdgeBlendState, EdgeBlendRaster) parseEdgeBlendState(List<String?> r) {
  const edges = BlendEdge.values;
  int intAt(int i, String key) => parseKeyedInt(r[i], key) ?? 0;
  final n = edges.length;
  final state = EdgeBlendState(
    mode: EdgeBlendMode.fromProtocol(parseKeyedInt(r[0], 'EDBI0')),
    edges: {
      for (var i = 0; i < n; i++)
        edges[i]: EdgeSettings(
          enabled: intAt(2 + i, edges[i].enableCmd) == 1,
          start: intAt(2 + n + i, edges[i].startCmd),
          width: intAt(2 + 2 * n + i, edges[i].widthKey),
          border: intAt(4 + 3 * n + i, edges[i].borderCmd),
        ),
    },
    markers: intAt(2 + 3 * n, 'GM') == 1,
    autoPattern: intAt(3 + 3 * n, 'EATI1') == 1,
  );
  return (state, edgeBlendRasterFor(r[1] ?? ''));
}
