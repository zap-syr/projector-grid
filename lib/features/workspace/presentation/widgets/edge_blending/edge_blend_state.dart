import 'package:flutter/foundation.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/geometry_values.dart';

/// `VXX:EDBI0`: Off / On / User (the user curve lives on the projector).
enum EdgeBlendMode {
  off('Off'),
  on('On'),
  user('User');

  final String label;
  const EdgeBlendMode(this.label);

  static EdgeBlendMode fromProtocol(int? v) => switch (v) {
    1 => on,
    2 => user,
    _ => off,
  };
}

/// What a canvas handle or a slider moves. [border] is the black border
/// width, which lives in `BlackLevelState`, not in [EdgeSettings].
enum EdgePart { start, width, border }

@immutable
class EdgeSettings {
  final bool enabled;
  final int start;
  final int width;

  const EdgeSettings({
    required this.enabled,
    required this.start,
    required this.width,
  });

  int valueOf(EdgePart part) => switch (part) {
    EdgePart.start => start,
    EdgePart.width => width,
    EdgePart.border => throw ArgumentError.value(part, 'part'),
  };

  EdgeSettings copyWith({bool? enabled, int? start, int? width}) =>
      EdgeSettings(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        width: width ?? this.width,
      );

  EdgeSettings withPart(EdgePart part, int v) => switch (part) {
    EdgePart.start => copyWith(start: v),
    EdgePart.width => copyWith(width: v),
    EdgePart.border => throw ArgumentError.value(part, 'part'),
  };

  @override
  bool operator ==(Object other) =>
      other is EdgeSettings &&
      other.enabled == enabled &&
      other.start == start &&
      other.width == width;

  @override
  int get hashCode => Object.hash(enabled, start, width);
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
  /// (§8 rules in `edge_blend_limits.dart`).
  int maxFor(BlendEdge edge, EdgePart part, EdgeBlendRaster raster) {
    final span = edgeBlendSpan(raster, edge);
    final e = this[edge];
    return switch (part) {
      EdgePart.start => maxBlendStart(span: span, width: e.width),
      EdgePart.width => maxBlendWidth(
        span: span,
        start: e.start,
        oppositeWidth: this[edge.opposite].width,
      ),
      EdgePart.border => maxBorderWidth(span: span, width: e.width),
    };
  }
}

/// Queries for [EdgeBlendState], in the order [parseEdgeBlendState] reads
/// them. `QID` rides along so the raster comes with the same batch.
List<String> edgeBlendQueries() => [
  'QVX:EDBI0',
  'QID',
  for (final e in BlendEdge.values) 'Q${e.enableCmd}',
  for (final e in BlendEdge.values) 'Q${e.startCmd}',
  for (final e in BlendEdge.values) 'QVX:${e.widthKey}',
  'QGM',
  'QVX:EATI1',
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
        ),
    },
    markers: intAt(2 + 3 * n, 'GM') == 1,
    autoPattern: intAt(3 + 3 * n, 'EATI1') == 1,
  );
  return (state, edgeBlendRasterFor(r[1] ?? ''));
}
