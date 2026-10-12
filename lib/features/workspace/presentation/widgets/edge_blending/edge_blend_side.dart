import 'package:flutter/foundation.dart';

import '../../../../../core/services/panasonic_protocol_service.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/edge_blend_values.dart';
import '../../../domain/geometry_values.dart';
import '../../../domain/projector_node.dart';
import '../common/projector_settings_client.dart';
import '../common/serial_queue.dart';
import 'edge_blend_state.dart';

/// One projector in the Edge Blending dialog: its values, loading and
/// writes. A list of these is what lets the dialog take a second projector
/// later (plan §9) without changing the panels.
class EdgeBlendSide extends ChangeNotifier {
  EdgeBlendSide({required this.node, required this.client});

  final ProjectorNode node;
  final ProjectorSettingsClient client;

  /// Writes go out one at a time: two Start/Width writes racing each other
  /// can be refused (ER402) in an order the UI never showed.
  final _writes = SerialQueue();

  bool loading = true;
  bool unreachable = false;
  EdgeBlendRaster raster = edgeBlendRasterFor('');

  /// What the dialog shows, including drag previews not sent yet.
  EdgeBlendState get blend => _blend!;
  EdgeBlendState? _blend;

  /// What the projector will hold once every queued write lands. A commit
  /// equal to it sends nothing (a stepper re-commits its value on blur).
  EdgeBlendState? _target;

  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    unreachable = false;
    notifyListeners();
    final replies = await client.queryAll(edgeBlendQueries());
    if (_disposed) return;
    loading = false;
    if (replies.every((r) => r == null)) {
      unreachable = true;
    } else {
      final (state, raster) = parseEdgeBlendState(replies);
      _blend = state;
      _target = state;
      this.raster = raster;
    }
    notifyListeners();
  }

  void setMode(EdgeBlendMode mode) => _set(_modeField, mode);

  void setMarkers(bool on) => _set(_markersField, on);

  void setAutoPattern(bool on) => _set(_autoPatternField, on);

  void setEnabled(BlendEdge edge, bool on) => _set(_enabledField(edge), on);

  /// Shows [v] without sending it — slider and handle drags call this on
  /// every move, then [commit] once at the end.
  void preview(BlendEdge edge, EdgePart part, int v) {
    _blend = blend.withEdge(edge, blend[edge].withPart(part, v));
    notifyListeners();
  }

  void commit(BlendEdge edge, EdgePart part) => _send(_partField(edge, part));

  void _set<T>(_Field<T> field, T v) {
    _blend = field.set(blend, v);
    notifyListeners();
    _send(field);
  }

  void _send<T>(_Field<T> field) {
    final v = field.get(blend);
    if (field.get(_target!) == v) return;
    _target = field.set(_target!, v);
    _writes.run(() => _write(field, v));
  }

  Future<void> _write<T>(_Field<T> field, T v) async {
    final cmd = field.command(v);
    final reply = await client.writeRawWithCode(cmd);
    // null: no reply at all, already reported by the client.
    if (_disposed ||
        reply == null ||
        !PanasonicProtocolService.isErrorCode(reply)) {
      return;
    }
    // ER402 is an out-of-range value the §8 limits didn't foresee: expected
    // often enough not to be worth a notice, the read-back shows the result.
    if (reply != 'ER402') client.onFailure(cmd);
    final actual = field.parse(await client.query(field.query));
    if (_disposed || actual == null) return;
    _blend = field.set(blend, actual);
    _target = field.set(_target!, actual);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One writable value: how to send it, read it back and where it lives in
/// [EdgeBlendState].
class _Field<T> {
  const _Field({
    required this.query,
    required this.parse,
    required this.command,
    required this.get,
    required this.set,
  });

  final String query;
  final T? Function(String? reply) parse;
  final String Function(T v) command;
  final T Function(EdgeBlendState s) get;
  final EdgeBlendState Function(EdgeBlendState s, T v) set;
}

bool? _parseFlag(String? reply, String key) {
  final v = parseKeyedInt(reply, key);
  return v == null ? null : v == 1;
}

final _modeField = _Field<EdgeBlendMode>(
  query: 'QVX:EDBI0',
  parse: (r) {
    final v = parseKeyedInt(r, 'EDBI0');
    return v == null ? null : EdgeBlendMode.fromProtocol(v);
  },
  command: (m) => 'VXX:EDBI0=${formatNtInt(m.index)}',
  get: (s) => s.mode,
  set: (s, m) => s.copyWith(mode: m),
);

final _markersField = _Field<bool>(
  query: 'QGM',
  parse: (r) => _parseFlag(r, 'GM'),
  command: (on) => 'VGM:${on ? 1 : 0}',
  get: (s) => s.markers,
  set: (s, on) => s.copyWith(markers: on),
);

final _autoPatternField = _Field<bool>(
  query: 'QVX:EATI1',
  parse: (r) => _parseFlag(r, 'EATI1'),
  command: (on) => 'VXX:EATI1=${formatNtInt(on ? 1 : 0)}',
  get: (s) => s.autoPattern,
  set: (s, on) => s.copyWith(autoPattern: on),
);

_Field<bool> _enabledField(BlendEdge edge) => _Field<bool>(
  query: 'Q${edge.enableCmd}',
  parse: (r) => _parseFlag(r, edge.enableCmd),
  command: (on) => 'V${edge.enableCmd}:${on ? 1 : 0}',
  get: (s) => s[edge].enabled,
  set: (s, on) => s.withEdge(edge, s[edge].copyWith(enabled: on)),
);

_Field<int> _partField(BlendEdge edge, EdgePart part) => switch (part) {
  EdgePart.start => _Field<int>(
    query: 'Q${edge.startCmd}',
    parse: (r) => parseKeyedInt(r, edge.startCmd),
    command: (v) => 'V${edge.startCmd}:${formatNt4(v)}',
    get: (s) => s[edge].start,
    set: (s, v) => s.withEdge(edge, s[edge].copyWith(start: v)),
  ),
  EdgePart.width => _Field<int>(
    query: 'QVX:${edge.widthKey}',
    parse: (r) => parseKeyedInt(r, edge.widthKey),
    command: (v) => 'VXX:${edge.widthKey}=${formatNtInt(v)}',
    get: (s) => s[edge].width,
    set: (s, v) => s.withEdge(edge, s[edge].copyWith(width: v)),
  ),
};
