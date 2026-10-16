import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/color_correction.dart';
import '../../domain/projector_node.dart';
import '../providers/protocol_service_provider.dart';
import 'color_correction/card_heading.dart';
import 'color_correction/color_matching_card.dart';
import 'color_correction/kelvin_card.dart';
import 'color_correction/matching_off_card.dart';
import 'color_correction/method_card.dart';
import 'color_correction/temperature_mode_card.dart';
import 'color_correction/white_balance_card.dart';
import 'command_failure_notice.dart';
import 'common/debouncer.dart';
import 'common/dialog_parts.dart';
import 'common/projector_settings_client.dart';
import 'common/segmented_tabs.dart';
import 'common/skeleton.dart';
import 'dialog_title_bar.dart';

enum _Tab { matching, temperature }

class ColorCorrectionDialog extends ConsumerStatefulWidget {
  final ProjectorNode node;

  const ColorCorrectionDialog({super.key, required this.node});

  /// For layout tests: the tab strip and the first card of each tab.
  static const tabsKey = ValueKey('color-correction-tabs');
  static const firstCardKey = ValueKey('color-correction-first-card');

  @override
  ConsumerState<ColorCorrectionDialog> createState() =>
      _ColorCorrectionDialogState();
}

class _ColorCorrectionDialogState extends ConsumerState<ColorCorrectionDialog> {
  late final _client = ProjectorSettingsClient(
    service: ref.read(protocolServiceProvider),
    node: widget.node,
    onFailure: (cmd) {
      if (mounted) notifyCommandFailure(context, cmd);
    },
  );

  // One per register, so a burst of − / + presses, preset taps or value
  // field steps becomes one write each.
  final _debouncers = <String, Debouncer>{};

  // Every write and the reads that follow a switch go through one queue.
  // Each command is its own TCP connection, so without it a read could
  // reach the projector before the switch it depends on has applied.
  Future<void> _queue = Future.value();

  // Bumped on every method or mode switch, so a read for a state the user
  // has already left doesn't overwrite the current one.
  int _readSeq = 0;

  bool _loading = true;
  _Tab _tab = _Tab.matching;

  // ── Color Matching ────────────────────────────────────────────────────
  MatchMethod _method = MatchMethod.off;

  // 3 and 7 colors are separate registers on the projector.
  Map<MatchMethod, Map<MatchColor, List<int>>> _values = {
    for (final m in [MatchMethod.three, MatchMethod.seven])
      m: {for (final c in m.colors) c: c.defaultRgb},
  };
  MatchColor _selected = MatchColor.red;

  // ── Color Temperature ─────────────────────────────────────────────────
  TempMode _tempMode = TempMode.defaultTemp;
  int _kelvin = 6500;
  List<int> _whHigh = const [128, 128, 128];
  List<int> _whLow = const [0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  @override
  void dispose() {
    // Flush, not cancel: the last press before ✕ still reaches the projector.
    for (final d in _debouncers.values) {
      d.flush();
    }
    super.dispose();
  }

  // Only asks which method and mode are active, then reads the values of
  // those alone: Off and Default need none, and Custom's kelvin comes with
  // QTE. Reading every register on open used to open up to 18 TCP
  // connections, most of them for values the dialog wasn't showing.
  Future<void> _loadValues() async {
    final (cmai, qte) = await (
      _client.query('QVX:CMAI0'),
      _client.query('QTE'),
    ).wait;
    if (!mounted) return;
    if (cmai != null && cmai.contains('+')) {
      _method = MatchMethod.fromProtocol(
        int.tryParse(cmai.split('+').last) ?? 0,
      );
    }
    _applyTemperature(qte);
    final seq = _readSeq;
    await Future.wait([
      if (_method != MatchMethod.off) _readMatching(_method, seq),
      // White balance is also what Color Matching edits; QTE reads ER401
      // then, so the method decides, not the mode.
      if (_method != MatchMethod.off || _tempMode.isUser)
        _readWhiteBalance(seq),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  void _applyTemperature(String? qte) {
    final parsed = parseColorTemperature(qte);
    if (parsed == null) return;
    _tempMode = parsed.$1;
    final kelvin = parsed.$2;
    if (kelvin != null) _kelvin = kelvin;
  }

  // QTE reads ER401 the whole time Color Matching is on, so the mode is
  // only known again once it is back to Off.
  Future<void> _readTemperature(int seq) async {
    final raw = await _client.query('QTE');
    if (!mounted || seq != _readSeq) return;
    setState(() => _applyTemperature(raw));
  }

  // QHR..QOB report whichever User slot (OTE:04 / OTE:09) is active: there
  // is no per-slot query (confirmed live), so they are read again on every
  // switch.
  Future<void> _readWhiteBalance(int seq) async {
    final r = await Future.wait([
      for (final cmd in ['QHR', 'QHG', 'QHB', 'QOR', 'QOG', 'QOB'])
        _client.query(cmd),
    ]);
    if (!mounted || seq != _readSeq) return;
    setState(() {
      _whHigh = List.unmodifiable([
        for (var i = 0; i < 3; i++) parseWhiteBalanceHigh(r[i], _whHigh[i]),
      ]);
      _whLow = List.unmodifiable([
        for (var i = 0; i < 3; i++) parseWhiteBalanceLow(r[i + 3], _whLow[i]),
      ]);
    });
  }

  // Read on every switch to the method, also back to one already seen, so
  // values changed elsewhere meanwhile show up.
  Future<void> _readMatching(MatchMethod m, int seq) async {
    final results = await Future.wait([
      for (final c in m.colors) _client.query(colorMatchingQuery(m, c)),
    ]);
    if (!mounted || seq != _readSeq) return;
    setState(() {
      final next = {..._values[m]!};
      for (final (i, c) in m.colors.indexed) {
        final raw = results[i];
        final rgb = raw == null ? null : parseRgbTriple(raw);
        if (rgb != null) next[c] = rgb;
      }
      _values = {..._values, m: next};
    });
  }

  // ── Writes ────────────────────────────────────────────────────────────

  Future<void> _enqueue(Future<void> Function() op) =>
      _queue = _queue.then((_) => op());

  void _write(String cmd) => _enqueue(() => _client.writeRaw(cmd));

  /// A slider release or Reset: sent now, replacing a press still waiting.
  void _sendNow(String key, String cmd) {
    _debouncers[key]?.cancel();
    _write(cmd);
  }

  /// − / +, presets and value fields: [cmd] is built when the burst ends,
  /// from the value then.
  void _sendDebounced(String key, String Function() cmd) =>
      _debouncers.putIfAbsent(key, Debouncer.new).run(() => _write(cmd()));

  void _flushPending() {
    for (final d in _debouncers.values) {
      d.flush();
    }
  }

  // ── Color Matching ────────────────────────────────────────────────────

  void _selectMethod(MatchMethod m) {
    final seq = ++_readSeq;
    // A press still waiting belongs to the method being left.
    _flushPending();
    setState(() {
      _method = m;
      if (m != MatchMethod.off && !m.colors.contains(_selected)) {
        _selected = MatchColor.red;
      }
    });
    _write(m.writeCommand);
    if (m == MatchMethod.off) {
      _enqueue(() => _readTemperature(seq));
    } else {
      _enqueue(
        () => Future.wait([_readMatching(m, seq), _readWhiteBalance(seq)]),
      );
    }
  }

  List<int> get _rgb => _values[_method]![_selected]!;

  void _setRgb(MatchColor c, List<int> rgb) => setState(() {
    _values = {
      ..._values,
      _method: {..._values[_method]!, c: List.unmodifiable(rgb)},
    };
  });

  List<int> _withChannel(int channel, int v) => [
    for (var i = 0; i < 3; i++) i == channel ? v : _rgb[i],
  ];

  String _matchingKey(MatchColor c) => 'match-${_method.name}-${c.name}';

  void _commitChannel(int channel, int v) {
    final c = _selected;
    _setRgb(c, _withChannel(channel, v));
    _sendNow(_matchingKey(c), colorMatchingWrite(_method, c, _rgb));
  }

  void _typeChannel(int channel, int v) {
    final (m, c) = (_method, _selected);
    _setRgb(c, _withChannel(channel, v));
    _sendDebounced(
      _matchingKey(c),
      () => colorMatchingWrite(m, c, _values[m]![c]!),
    );
  }

  void _resetColor() {
    final c = _selected;
    _setRgb(c, c.defaultRgb);
    _sendNow(_matchingKey(c), colorMatchingWrite(_method, c, c.defaultRgb));
  }

  // ── Color Temperature ─────────────────────────────────────────────────

  void _selectTempMode(TempMode m) {
    if (m == _tempMode) return;
    final seq = ++_readSeq;
    _flushPending();
    setState(() => _tempMode = m);
    _write(m.writeCommand(_kelvin));
    if (m.isUser) _enqueue(() => _readWhiteBalance(seq));
  }

  static String _wbKey(bool isHigh, int channel) =>
      'wb-${isHigh ? 'high' : 'low'}-$channel';

  String _wbWrite(bool isHigh, int channel) => isHigh
      ? whiteBalanceHighWrite(channel, _whHigh[channel])
      : whiteBalanceLowWrite(channel, _whLow[channel]);

  void _setWb(bool isHigh, int channel, int v) => setState(() {
    List<int> put(List<int> l) => List.unmodifiable([
      for (var i = 0; i < 3; i++) i == channel ? v : l[i],
    ]);
    if (isHigh) {
      _whHigh = put(_whHigh);
    } else {
      _whLow = put(_whLow);
    }
  });

  void _dragWb(bool isHigh, int channel, int v) =>
      _setWb(isHigh, channel, isHigh ? v : snapWhiteBalanceLow(v));

  void _commitWb(bool isHigh, int channel, int v) {
    _dragWb(isHigh, channel, v);
    _sendNow(_wbKey(isHigh, channel), _wbWrite(isHigh, channel));
  }

  // A typed or stepped value is taken as is: the snap to 0 only helps a
  // drag land on the neutral point.
  void _typeWb(bool isHigh, int channel, int v) {
    _setWb(isHigh, channel, v);
    _sendDebounced(_wbKey(isHigh, channel), () => _wbWrite(isHigh, channel));
  }

  static const _kelvinKey = 'kelvin';

  String _kelvinWrite() => TempMode.custom.writeCommand(_kelvin);

  void _commitKelvin(int k) {
    setState(() => _kelvin = k);
    _sendNow(_kelvinKey, _kelvinWrite());
  }

  void _stepKelvin(int steps) {
    setState(
      () =>
          _kelvin = (_kelvin + steps * kelvinStep).clamp(kelvinMin, kelvinMax),
    );
    _sendDebounced(_kelvinKey, _kelvinWrite);
  }

  void _presetKelvin(int k) {
    setState(() => _kelvin = k);
    _sendDebounced(_kelvinKey, _kelvinWrite);
  }

  // ── Layout ────────────────────────────────────────────────────────────

  String? get _temperaturePill {
    if (_loading) return null;
    if (_method != MatchMethod.off) return 'Fixed';
    return _tempMode == TempMode.custom ? '$_kelvin K' : _tempMode.label;
  }

  Widget _matchingBody() {
    final first = MethodCard(
      key: ColorCorrectionDialog.firstCardKey,
      method: _loading ? null : _method,
      onChanged: _selectMethod,
    );
    if (_loading || _method == MatchMethod.off) {
      return DialogScrollBody(
        key: const ValueKey('matching-fill'),
        padding: _bodyPadding,
        fillGap: _cardGap,
        fill: _loading ? const _LoadingCard() : const MatchingOffCard(),
        child: first,
      );
    }
    return DialogScrollBody(
      key: const ValueKey('matching-colors'),
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _cardGap,
        children: [
          first,
          ColorMatchingCard(
            method: _method,
            values: _values[_method]!,
            selected: _selected,
            onSelect: (c) => setState(() => _selected = c),
            onChannelChanged: (ch, v) =>
                _setRgb(_selected, _withChannel(ch, v)),
            onChannelCommit: _commitChannel,
            onChannelTyped: _typeChannel,
            onReset: _resetColor,
          ),
        ],
      ),
    );
  }

  Widget _temperatureBody() {
    final matchingOn = _method != MatchMethod.off;
    final Widget? second = _loading
        ? null
        // Color Matching edits the same registers, so white balance stays
        // usable while it fixes the mode.
        : matchingOn || _tempMode.isUser
        ? WhiteBalanceCard(
            high: _whHigh,
            low: _whLow,
            underColorMatching: matchingOn,
            onChanged: _dragWb,
            onCommit: _commitWb,
            onTyped: _typeWb,
          )
        : _tempMode == TempMode.custom
        ? KelvinCard(
            kelvin: _kelvin,
            onChanged: (k) => setState(() => _kelvin = k),
            onCommit: _commitKelvin,
            onStep: _stepKelvin,
            onPreset: _presetKelvin,
          )
        : null;
    return DialogScrollBody(
      key: const ValueKey('temperature'),
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _cardGap,
        children: [
          TemperatureModeCard(
            key: ColorCorrectionDialog.firstCardKey,
            mode: _tempMode,
            fixedBy: matchingOn ? _method : null,
            loading: _loading,
            onSelected: _selectTempMode,
          ),
          ?second,
        ],
      ),
    );
  }

  static const _bodyPadding = EdgeInsets.fromLTRB(24, 16, 24, 20);
  static const double _cardGap = 16;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      // A cap: the smallest window (800×600) leaves about 720×550 inside
      // the Dialog insets, and the body scrolls there. Within it the dialog
      // has one size for both tabs, every method and mode, and loading
      // (SizedBox.expand), so nothing moves on a switch.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 580),
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DialogTitleBar(
                icon: Icons.palette_outlined,
                title: 'Color Correction',
                projectorId: widget.node.id,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: SegmentedTabs<_Tab>(
                  key: ColorCorrectionDialog.tabsKey,
                  selected: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                  tabs: [
                    SegmentedTab(
                      value: _Tab.matching,
                      label: 'Color Matching',
                      pill: _loading ? null : _method.label,
                    ),
                    SegmentedTab(
                      value: _Tab.temperature,
                      label: 'Color Temperature',
                      pill: _temperaturePill,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  _Tab.matching => _matchingBody(),
                  _Tab.temperature => _temperatureBody(),
                },
              ),
              DialogFooter(message: SentRightAwayNote(loading: _loading)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Color Matching's second card while the method is still being read.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const ColorCard(
    child: Center(
      child: SkeletonPulse(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Skeleton(width: 34, height: 34, radius: 10),
            Skeleton(width: 180, height: 16),
            Skeleton(width: 300, height: 12),
          ],
        ),
      ),
    ),
  );
}
