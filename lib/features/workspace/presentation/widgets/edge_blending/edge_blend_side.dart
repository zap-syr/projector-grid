import 'package:flutter/foundation.dart';

import '../../../../../core/services/panasonic_protocol_service.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../../../domain/edge_blend_values.dart';
import '../../../domain/geometry_values.dart';
import '../../../domain/projector_node.dart';
import '../common/projector_settings_client.dart';
import '../common/serial_queue.dart';
import 'black_level_state.dart';
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

  bool blackLoading = false;
  bool blackUnreachable = false;

  /// What the dialog shows, including drag previews not sent yet.
  _Values? _values;

  /// What the projector will hold once every queued write lands. A commit
  /// equal to it sends nothing (a stepper re-commits its value on blur).
  _Values? _target;

  EdgeBlendState get blend => _values!.blend;

  /// Null until the Black Level tab has loaded.
  BlackLevelState? get black => _values?.black;

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
      _values = _Values(state, null);
      _target = _values;
      this.raster = raster;
    }
    notifyListeners();
  }

  /// The Black Level tab's ~17 queries, sent the first time it opens.
  Future<void> loadBlack() async {
    if (blackLoading) return;
    blackLoading = true;
    blackUnreachable = false;
    notifyListeners();
    final replies = await client.queryAll(blackLevelQueries());
    if (_disposed) return;
    blackLoading = false;
    if (replies.every((r) => r == null)) {
      blackUnreachable = true;
    } else {
      final state = parseBlackLevelState(replies);
      _values = _values!.withBlack(state);
      _target = _target!.withBlack(state);
    }
    notifyListeners();
  }

  void setMode(EdgeBlendMode mode) => _set(_modeField, mode);

  void setMarkers(bool on) => _set(_markersField, on);

  void setAutoPattern(bool on) => _set(_autoPatternField, on);

  void setEnabled(BlendEdge edge, bool on) => _set(_enabledField(edge), on);

  void setBlackMode(BlackLevelMode mode) => _set(_blackModeField, mode);

  /// Shows [v] without sending it — slider and handle drags call this on
  /// every move, then [commit] once at the end.
  void preview(BlendEdge edge, EdgePart part, int v) {
    _values = _partField(edge, part).set(_values!, v);
    notifyListeners();
  }

  void commit(BlendEdge edge, EdgePart part) => _send(_partField(edge, part));

  /// Start and Width to 0. Width goes first, but both only shrink, so
  /// neither write can be out of range in either order.
  void resetEdge(BlendEdge edge) {
    preview(edge, EdgePart.width, 0);
    preview(edge, EdgePart.start, 0);
    commit(edge, EdgePart.width);
    commit(edge, EdgePart.start);
  }

  void resetBorder(BlendEdge edge) {
    preview(edge, EdgePart.border, 0);
    commit(edge, EdgePart.border);
  }

  /// Like [preview]; while Interlocked any channel moves all four.
  void previewLevel(LevelSlot slot, RgbwChannel channel, int v) {
    final level = black![slot].withChannel(channel, v);
    _values = _values!.withBlack(black!.withLevel(slot, level));
    notifyListeners();
  }

  /// Shows a whole tuple at once, as a linked level mirrors the other
  /// projector's (the channel-wise [previewLevel] would apply this side's
  /// own Interlocked to it).
  void previewLevelValue(LevelSlot slot, Rgbw value) {
    _values = _levelField(slot).set(_values!, value);
    notifyListeners();
  }

  void commitLevel(LevelSlot slot) => _send(_levelField(slot));

  /// Takes over [level] as it is, flag and tuple: only what differs is
  /// written.
  void copyLevel(LevelSlot slot, RgbwLevel level) {
    _set(_interlockField(slot), level.interlocked);
    _set(_levelField(slot), level.value);
  }

  /// ON writes the flag, then the tuple with R/G/B set to W. OFF writes only
  /// the flag: the four channels stay as they are (§1).
  void setInterlocked(LevelSlot slot, bool on) {
    _set(_interlockField(slot), on);
    if (!on) return;
    final w = black![slot].value.w;
    _set(_levelField(slot), (w: w, r: w, g: w, b: w));
  }

  void _set<T>(_Field<T> field, T v) {
    _values = field.set(_values!, v);
    notifyListeners();
    _send(field);
  }

  void _send<T>(_Field<T> field) {
    final v = field.get(_values!);
    final before = field.get(_target!);
    if (before == v) return;
    _target = field.set(_target!, v);
    _pending.update(field.query, (n) => n + 1, ifAbsent: () => 1);
    _writes.run(() => _write(field, v, before));
  }

  /// Queued or running writes per field (keyed by its query): a failed
  /// write only touches the field when no later one will overwrite it.
  final _pending = <String, int>{};

  bool _isLastWrite<T>(_Field<T> field) => _pending[field.query] == 1;

  Future<void> _write<T>(_Field<T> field, T v, T before) async {
    final cmd = field.command(v);
    try {
      final reply = await client.writeRawWithCode(cmd);
      if (_disposed) return;
      if (reply == null) {
        // No reply, already reported by the client. The projector still
        // holds the old value, so re-entering [v] has to send it again.
        if (_isLastWrite(field)) _target = field.set(_target!, before);
        return;
      }
      if (!PanasonicProtocolService.isErrorCode(reply)) return;
      // ER402 is an out-of-range value the §8 limits didn't foresee:
      // expected often enough not to be worth a notice, the read-back shows
      // the result.
      if (reply != 'ER402') client.onFailure(cmd);
      // A later write to this field decides what the projector ends up
      // with; reading back now would show a value about to be replaced.
      if (!_isLastWrite(field)) return;
      final actual = field.parse(await client.query(field.query));
      if (_disposed || !_isLastWrite(field)) return;
      if (actual == null) {
        _target = field.set(_target!, before);
        return;
      }
      _values = field.set(_values!, actual);
      _target = field.set(_target!, actual);
      notifyListeners();
    } finally {
      _pending.update(field.query, (n) => n - 1);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Both tabs' values. [black] stays null until that tab loads; its fields
/// are only reachable from the tab, so they never see it null.
@immutable
class _Values {
  const _Values(this.blend, this.black);

  final EdgeBlendState blend;
  final BlackLevelState? black;

  _Values withBlend(EdgeBlendState s) => _Values(s, black);

  _Values withBlack(BlackLevelState s) => _Values(blend, s);
}

/// One writable value: how to send it, read it back and where it lives in
/// [_Values].
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
  final T Function(_Values s) get;
  final _Values Function(_Values s, T v) set;
}

_Field<T> _blendField<T>({
  required String query,
  required T? Function(String? reply) parse,
  required String Function(T v) command,
  required T Function(EdgeBlendState s) get,
  required EdgeBlendState Function(EdgeBlendState s, T v) set,
}) => _Field<T>(
  query: query,
  parse: parse,
  command: command,
  get: (s) => get(s.blend),
  set: (s, v) => s.withBlend(set(s.blend, v)),
);

_Field<T> _blackField<T>({
  required String query,
  required T? Function(String? reply) parse,
  required String Function(T v) command,
  required T Function(BlackLevelState s) get,
  required BlackLevelState Function(BlackLevelState s, T v) set,
}) => _Field<T>(
  query: query,
  parse: parse,
  command: command,
  get: (s) => get(s.black!),
  set: (s, v) => s.withBlack(set(s.black!, v)),
);

bool? _parseFlag(String? reply, String key) {
  final v = parseKeyedInt(reply, key);
  return v == null ? null : v == 1;
}

final _modeField = _blendField<EdgeBlendMode>(
  query: 'QVX:EDBI0',
  parse: (r) {
    final v = parseKeyedInt(r, 'EDBI0');
    return v == null ? null : EdgeBlendMode.fromProtocol(v);
  },
  command: (m) => 'VXX:EDBI0=${formatNtInt(m.index)}',
  get: (s) => s.mode,
  set: (s, m) => s.copyWith(mode: m),
);

final _markersField = _blendField<bool>(
  query: 'QGM',
  parse: (r) => _parseFlag(r, 'GM'),
  command: (on) => 'VGM:${on ? 1 : 0}',
  get: (s) => s.markers,
  set: (s, on) => s.copyWith(markers: on),
);

final _autoPatternField = _blendField<bool>(
  query: 'QVX:EATI1',
  parse: (r) => _parseFlag(r, 'EATI1'),
  command: (on) => 'VXX:EATI1=${formatNtInt(on ? 1 : 0)}',
  get: (s) => s.autoPattern,
  set: (s, on) => s.copyWith(autoPattern: on),
);

_Field<bool> _enabledField(BlendEdge edge) => _blendField<bool>(
  query: 'Q${edge.enableCmd}',
  parse: (r) => _parseFlag(r, edge.enableCmd),
  command: (on) => 'V${edge.enableCmd}:${on ? 1 : 0}',
  get: (s) => s[edge].enabled,
  set: (s, on) => s.withEdge(edge, s[edge].copyWith(enabled: on)),
);

_Field<int> _partField(BlendEdge edge, EdgePart part) => switch (part) {
  EdgePart.start => _blendField<int>(
    query: 'Q${edge.startCmd}',
    parse: (r) => parseKeyedInt(r, edge.startCmd),
    command: (v) => 'V${edge.startCmd}:${formatNt4(v)}',
    get: (s) => s[edge].start,
    set: (s, v) => s.withEdge(edge, s[edge].copyWith(start: v)),
  ),
  EdgePart.width => _blendField<int>(
    query: 'QVX:${edge.widthKey}',
    parse: (r) => parseKeyedInt(r, edge.widthKey),
    command: (v) => 'VXX:${edge.widthKey}=${formatNtInt(v)}',
    get: (s) => s[edge].width,
    set: (s, v) => s.withEdge(edge, s[edge].copyWith(width: v)),
  ),
  EdgePart.border => _blackField<int>(
    query: 'Q${edge.borderCmd}',
    parse: (r) => parseKeyedInt(r, edge.borderCmd),
    command: (v) => 'V${edge.borderCmd}:${formatNt4(v)}',
    get: (s) => s.borderWidth(edge),
    set: (s, v) => s.withBorderWidth(edge, v),
  ),
};

final _blackModeField = _blackField<BlackLevelMode>(
  query: 'QVX:EBMI1',
  parse: (r) {
    final v = parseKeyedInt(r, 'EBMI1');
    return v == null ? null : BlackLevelMode.fromProtocol(v);
  },
  command: (m) => 'VXX:EBMI1=${formatNtInt(m.index)}',
  get: (s) => s.mode,
  set: (s, m) => s.copyWith(mode: m),
);

_Field<Rgbw> _levelField(LevelSlot slot) => _blackField<Rgbw>(
  query: slot.query,
  parse: parseRgbw,
  command: slot.command,
  get: (s) => s[slot].value,
  set: (s, v) => s.withLevel(slot, s[slot].copyWith(value: v)),
);

_Field<bool> _interlockField(LevelSlot slot) => _blackField<bool>(
  query: 'QVX:${slot.interlockKey}',
  parse: (r) => _parseFlag(r, slot.interlockKey),
  command: (on) => 'VXX:${slot.interlockKey}=${formatNtInt(on ? 1 : 0)}',
  get: (s) => s[slot].interlocked,
  set: (s, on) => s.withLevel(slot, s[slot].copyWith(interlocked: on)),
);
