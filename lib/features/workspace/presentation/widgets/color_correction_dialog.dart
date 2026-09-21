import 'package:flutter/material.dart';

import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';
import 'command_failure_notice.dart';
import 'dialog_title_bar.dart';
import 'sleek_stepper_input.dart';

enum _TempMode { defaultTemp, user1, user2, custom }

// Blackbody approximation stops for 3200 K → 13 000 K.
// Stop values = (K - 3200) / 9800.
const _kKelvinGradient = LinearGradient(
  colors: [
    Color(0xFFFF9329), // 3200 K — warm amber
    Color(0xFFFFBE70), // 4500 K — orange-white
    Color(0xFFFFE4B4), // 5500 K — warm white
    Color(0xFFFFFEFA), // 6500 K — neutral white
    Color(0xFFCADBFF), // 8000 K — cool blue-white
    Color(0xFFBECFFF), // 10000 K — blue-white
    Color(0xFFB6C8FF), // 13000 K — cool blue
  ],
  stops: [0.000, 0.133, 0.235, 0.337, 0.490, 0.694, 1.000],
);

class _KelvinThumbShape extends SliderComponentShape {
  const _KelvinThumbShape();

  static const double _radius = 8;

  @override
  Size getPreferredSize(bool isEnabled, bool isInteractive) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas
      ..drawCircle(center, _radius, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        _radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }
}

class ColorCorrectionDialog extends StatefulWidget {
  final ProjectorNode node;

  const ColorCorrectionDialog({super.key, required this.node});

  @override
  State<ColorCorrectionDialog> createState() => _ColorCorrectionDialogState();
}

class _ColorCorrectionDialogState extends State<ColorCorrectionDialog> {
  final _service = PanasonicProtocolService();

  bool _loading = true;

  // ── Color Matching ────────────────────────────────────────────────────────
  int _method = 0; // 0=off, 1=3colors, 2=7colors

  final _values3 = <String, List<int>>{
    'Red': [2048, 0, 0],
    'Green': [0, 2048, 0],
    'Blue': [0, 0, 2048],
  };

  final _values7 = <String, List<int>>{
    'Red': [2048, 0, 0],
    'Green': [0, 2048, 0],
    'Blue': [0, 0, 2048],
    'Cyan': [0, 2048, 2048],
    'Magenta': [2048, 0, 2048],
    'Yellow': [2048, 2048, 0],
    'White': [2048, 2048, 2048],
  };

  // ── Color Temperature ─────────────────────────────────────────────────────
  _TempMode _tempMode = _TempMode.defaultTemp;
  int _customK = 6500; // 3200–13000 step 100
  List<int> _whHigh = [128, 128, 128]; // R,G,B  0–255
  List<int> _whLow = [0, 0, 0]; // R,G,B  -127..+127 (display)

  String get _ip => widget.node.ipAddress;
  int get _port => widget.node.port;
  String get _login => widget.node.login;
  String get _password => widget.node.password;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  // Only queries which mode/method is active on each axis (Color Matching,
  // Color Temperature) — the actual slider values are fetched afterward, and
  // only for whichever mode/method turns out to be selected (below). Off/
  // Default need no slider query at all, and Custom's Kelvin comes straight
  // from QTE's own value — querying every mode's sliders unconditionally
  // used to open up to 18 simultaneous TCP connections to the projector on
  // every open, most of them for sliders the dialog wasn't even showing.
  Future<void> _loadValues() async {
    final modeResults = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:CMAI0'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QTE'),
    ]);

    if (!mounted) return;

    // ── Color Matching method ───────────────────────────────────────────────
    final methodRaw = modeResults[0];
    if (methodRaw != null && methodRaw.contains('+')) {
      _method = int.tryParse(methodRaw.split('+').last) ?? 0;
    }

    // ── Color Temperature mode ──────────────────────────────────────────────
    final qteVal = int.tryParse(modeResults[1]?.trim() ?? '');
    if (qteVal != null) {
      if (qteVal == 4) {
        _tempMode = _TempMode.user1;
      } else if (qteVal == 9) {
        _tempMode = _TempMode.user2;
      } else if (qteVal == 10) {
        _tempMode = _TempMode.defaultTemp;
      } else if (qteVal >= 3200 && qteVal <= 13000) {
        _tempMode = _TempMode.custom;
        _customK = (qteVal ~/ 100) * 100;
      }
    }

    await Future.wait([
      if (_method == 1) _refreshColorMatching3(),
      if (_method == 2) _refreshColorMatching7(),
      // White Balance is also the register Color Matching (3/7 colors) edits
      // directly — QTE reads ER401 there (confirmed live) so _tempMode can't
      // tell us to fetch it, _method has to.
      if (_method != 0 ||
          _tempMode == _TempMode.user1 ||
          _tempMode == _TempMode.user2)
        _refreshWhiteBalance(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  // White Balance High: 0–255, direct from the register.
  static List<int> _parseWhHigh(List<String?> raw, List<int> fallback) {
    final hr = int.tryParse(raw[0]?.trim() ?? '');
    final hg = int.tryParse(raw[1]?.trim() ?? '');
    final hb = int.tryParse(raw[2]?.trim() ?? '');
    return [
      (hr ?? fallback[0]).clamp(0, 255),
      (hg ?? fallback[1]).clamp(0, 255),
      (hb ?? fallback[2]).clamp(0, 255),
    ];
  }

  // White Balance Low: protocol 001–255, display = protocol - 128.
  static List<int> _parseWhLow(List<String?> raw, List<int> fallback) {
    final lr = int.tryParse(raw[0]?.trim() ?? '');
    final lg = int.tryParse(raw[1]?.trim() ?? '');
    final lb = int.tryParse(raw[2]?.trim() ?? '');
    return [
      lr == null ? fallback[0] : (lr - 128).clamp(-127, 127),
      lg == null ? fallback[1] : (lg - 128).clamp(-127, 127),
      lb == null ? fallback[2] : (lb - 128).clamp(-127, 127),
    ];
  }

  // Re-derives _tempMode/_customK from a fresh QTE read. QTE reads ER401 the
  // entire time Color Matching is active, so _tempMode can't be trusted the
  // instant it returns to Off — needed both here and once at initial load
  // (_loadValues has its own inline copy of this parse, batched together
  // with the CMAI0 query there instead of calling this).
  Future<void> _refreshTempMode() async {
    final raw = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'QTE',
    );
    if (!mounted) return;
    final qteVal = int.tryParse(raw?.trim() ?? '');
    if (qteVal == null) return;
    setState(() {
      if (qteVal == 4) {
        _tempMode = _TempMode.user1;
      } else if (qteVal == 9) {
        _tempMode = _TempMode.user2;
      } else if (qteVal == 10) {
        _tempMode = _TempMode.defaultTemp;
      } else if (qteVal >= 3200 && qteVal <= 13000) {
        _tempMode = _TempMode.custom;
        _customK = (qteVal ~/ 100) * 100;
      }
    });
  }

  // QHR/QHG/QHB/QOR/QOG/QOB are shared registers that report whichever User
  // slot (OTE:04 / OTE:09) is currently active — the projector has no
  // separate per-slot query command, confirmed live: switching modes changed
  // what these registers returned, and switching back reproduced the
  // original values exactly. Without this, the sliders kept showing
  // whichever slot's values were current when the dialog first opened,
  // unchanged by a mode switch.
  Future<void> _refreshWhiteBalance() async {
    final results = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHB'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOB'),
    ]);
    if (!mounted) return;
    setState(() {
      _whHigh = _parseWhHigh(results.sublist(0, 3), _whHigh);
      _whLow = _parseWhLow(results.sublist(3, 6), _whLow);
    });
  }

  // QMR/QMG/QMB only report the 3-color method's values — refetched every
  // time the method is switched to (including back to one already visited
  // this session) so values changed externally while viewing 7-color still
  // show up correctly.
  Future<void> _refreshColorMatching3() async {
    final results = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMB'),
    ]);
    if (!mounted) return;
    const keys3 = ['Red', 'Green', 'Blue'];
    setState(() {
      for (int i = 0; i < 3; i++) {
        final raw = results[i];
        if (raw != null) {
          final parsed = _parseRgb(raw);
          if (parsed != null) _values3[keys3[i]] = parsed;
        }
      }
    });
  }

  // QVX:C7CS0..6 only report the 7-color method's values — same rationale
  // as _refreshColorMatching3.
  Future<void> _refreshColorMatching7() async {
    final results = await Future.wait([
      for (var i = 0; i < 7; i++)
        _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS$i'),
    ]);
    if (!mounted) return;
    const keys7 = [
      'Red',
      'Green',
      'Blue',
      'Cyan',
      'Magenta',
      'Yellow',
      'White',
    ];
    setState(() {
      for (int i = 0; i < 7; i++) {
        final raw = results[i];
        if (raw != null) {
          final valuePart = raw.contains('=') ? raw.split('=').last : raw;
          final parsed = _parseRgb(valuePart);
          if (parsed != null) _values7[keys7[i]] = parsed;
        }
      }
    });
  }

  List<int>? _parseRgb(String raw) {
    final parts = raw.trim().split(',');
    if (parts.length != 3) return null;
    final values = parts.map((p) => int.tryParse(p.trim())).toList();
    if (values.any((v) => v == null)) return null;
    return values.cast<int>();
  }

  static String _fmt(int v) => v.toString().padLeft(4, '0');
  static String _fmt3(int v) => v.toString().padLeft(3, '0');

  void _notifyFailure(String cmd) {
    if (mounted) notifyCommandFailure(context, cmd);
  }

  // ── Color Matching sends ──────────────────────────────────────────────────
  Future<void> _setMethod(int method) async {
    setState(() => _method = method);
    final cmd = 'VXX:CMAI0=+${method.toString().padLeft(5, '0')}';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  Future<void> _set3Color(String color, List<int> rgb) async {
    final prefix = switch (color) {
      'Red' => 'VMR',
      'Green' => 'VMG',
      _ => 'VMB',
    };
    final cmd = '$prefix:${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  Future<void> _set7Color(String color, List<int> rgb) async {
    const keys7 = [
      'Red',
      'Green',
      'Blue',
      'Cyan',
      'Magenta',
      'Yellow',
      'White',
    ];
    final idx = keys7.indexOf(color);
    if (idx == -1) return;
    final cmd = 'VXX:C7CS$idx=${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  // ── Color Temperature sends ───────────────────────────────────────────────
  Future<void> _sendColorTemp(_TempMode mode) async {
    final code = switch (mode) {
      _TempMode.defaultTemp => '10',
      _TempMode.user1 => '04',
      _TempMode.user2 => '09',
      _TempMode.custom => '$_customK',
    };
    final cmd = 'OTE:$code';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  Future<void> _sendWhHigh(int channel, int value) async {
    final prefix = switch (channel) {
      0 => 'VHR',
      1 => 'VHG',
      _ => 'VHB',
    };
    final cmd = '$prefix:${_fmt3(value)}';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  Future<void> _sendWhLow(int channel, int displayValue) async {
    final prefix = switch (channel) {
      0 => 'VOR',
      1 => 'VOG',
      _ => 'VOB',
    };
    final protocol = (displayValue + 128).clamp(1, 255);
    final cmd = '$prefix:${_fmt3(protocol)}';
    final response = await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      cmd,
    );
    if (response == null) _notifyFailure(cmd);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  static Color _swatchFor(String name) => switch (name) {
    'Red' => Colors.red,
    'Green' => Colors.green,
    'Blue' => Colors.blue,
    'Cyan' => Colors.cyan,
    'Magenta' => const Color(0xFFCC44CC),
    'Yellow' => Colors.yellow,
    _ => Colors.white,
  };

  Widget _buildRgbSlider(
    BuildContext context, {
    required String label,
    required Color color,
    required int value,
    required double min,
    required double max,
    required int divisions,
    double step = 1.0,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color.withValues(alpha: 0.8),
                thumbColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value.toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SleekStepperInput(
            initialValue: value.toString(),
            min: min,
            max: max,
            step: step,
            onValueChanged: (s) {
              final v = double.tryParse(s);
              if (v != null) {
                onChanged(v);
                onChangeEnd(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorMatchSliderRow(
    BuildContext context,
    String label,
    Color color,
    int value,
    ValueChanged<double> onChanged,
    ValueChanged<double> onChangeEnd,
  ) {
    return _buildRgbSlider(
      context,
      label: label,
      color: color,
      value: value,
      min: 0,
      max: 2048,
      divisions: 2048,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }

  // Flat, always-visible section card used for both color-matching entries
  // and color-temperature groups — no collapse/expand, so nothing gets added
  // to or removed from the accessibility tree when switching modes.
  Widget _sectionCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        // surfaceContainerHighest, not surfaceContainerHigh: the Dialog's own
        // Material background already uses surfaceContainerHigh by default,
        // so matching it here would make the cards blend into the dialog body.
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildColorCard(
    BuildContext context,
    String colorName,
    Map<String, List<int>> valuesMap,
    Future<void> Function(String, List<int>) onSend,
  ) {
    final rgb = valuesMap[colorName]!;
    final swatch = _swatchFor(colorName);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _sectionCard(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  colorName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildColorMatchSliderRow(
              context,
              'R',
              Colors.red,
              rgb[0],
              (v) => setState(() => valuesMap[colorName]![0] = v.round()),
              (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
            ),
            _buildColorMatchSliderRow(
              context,
              'G',
              Colors.green,
              rgb[1],
              (v) => setState(() => valuesMap[colorName]![1] = v.round()),
              (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
            ),
            _buildColorMatchSliderRow(
              context,
              'B',
              Colors.blue,
              rgb[2],
              (v) => setState(() => valuesMap[colorName]![2] = v.round()),
              (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Color Temperature tab ─────────────────────────────────────────────────
  Widget _buildKelvinCard(BuildContext context) {
    final theme = Theme.of(context);
    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Color Temperature',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SleekStepperInput(
                    initialValue: _customK.toString(),
                    min: 3200,
                    max: 13000,
                    step: 100,
                    onValueChanged: (s) {
                      final v = double.tryParse(s);
                      if (v != null) {
                        setState(() => _customK = v.round());
                        _sendColorTemp(_TempMode.custom);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Text('K', style: theme.textTheme.titleSmall),
                ],
              ),
            ],
          ),
          // Stack: gradient Container behind a transparent-track Slider.
          // The 24 px horizontal padding matches Flutter's internal slider
          // track inset so the gradient aligns with the actual track bounds.
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: _kKelvinGradient,
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const _KelvinThumbShape(),
                    trackHeight: 10,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    overlayColor: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    min: 3200,
                    max: 13000,
                    // (13000 - 3200) / 100 = 98 steps → 98 divisions
                    divisions: 98,
                    value: _customK.toDouble(),
                    label: '${_customK}K',
                    onChanged: (v) =>
                        setState(() => _customK = (v.round() ~/ 100) * 100),
                    onChangeEnd: (_) => _sendColorTemp(_TempMode.custom),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteBalanceCard(
    BuildContext context, {
    required String title,
    required List<int> values,
    required double min,
    required double max,
    required int divisions,
    required void Function(int channel, int value) onChanged,
    required void Function(int channel, int value) onChangeEnd,
  }) {
    final theme = Theme.of(context);
    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final t in [
            (0, 'R', Colors.red),
            (1, 'G', Colors.green),
            (2, 'B', Colors.blue),
          ])
            _buildRgbSlider(
              context,
              label: t.$2,
              color: t.$3,
              value: values[t.$1],
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) => onChanged(t.$1, v.round()),
              onChangeEnd: (v) => onChangeEnd(t.$1, v.round()),
            ),
        ],
      ),
    );
  }

  Widget _buildWhiteBalanceSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWhiteBalanceCard(
            context,
            title: 'White Balance High',
            values: _whHigh,
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: (ch, v) => setState(() => _whHigh[ch] = v),
            onChangeEnd: (ch, v) => _sendWhHigh(ch, v),
          ),
          const SizedBox(height: 10),
          _buildWhiteBalanceCard(
            context,
            title: 'White Balance Low',
            values: _whLow,
            min: -127,
            max: 127,
            divisions: 254,
            onChanged: (ch, v) =>
                setState(() => _whLow[ch] = v.abs() <= 3 ? 0 : v),
            onChangeEnd: (ch, v) => _sendWhLow(ch, _whLow[ch]),
          ),
        ],
      ),
    );
  }

  Widget _buildColorTempTab(BuildContext context) {
    final theme = Theme.of(context);
    // While Color Matching (3/7 colors) is active, the projector has no
    // notion of a Color Temperature mode — QTE reads ER401 (confirmed live)
    // — but White Balance High/Low remain live-editable through the same
    // VHR/VHG/VHB/VOR/VOG/VOB registers Color Temperature's User 1/2 use.
    // Lock the mode picker instead of leaving it selectable to a state the
    // projector rejects, while keeping the sliders themselves usable.
    final matchingActive = _method != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: SegmentedButton<_TempMode>(
            segments: const [
              ButtonSegment(
                value: _TempMode.defaultTemp,
                label: Text('Default'),
              ),
              ButtonSegment(value: _TempMode.user1, label: Text('User 1')),
              ButtonSegment(value: _TempMode.user2, label: Text('User 2')),
              ButtonSegment(value: _TempMode.custom, label: Text('Custom')),
            ],
            selected: {_tempMode},
            showSelectedIcon: false,
            onSelectionChanged: matchingActive
                ? null
                : (s) async {
                    final mode = s.first;
                    setState(() => _tempMode = mode);
                    // Awaited: each NTCONTROL command is its own TCP
                    // connection, so firing the refresh without waiting for
                    // this write's response first risks the read reaching
                    // the projector before the switch actually applied.
                    await _sendColorTemp(mode);
                    if (mode == _TempMode.user1 || mode == _TempMode.user2) {
                      await _refreshWhiteBalance();
                    }
                  },
          ),
        ),
        if (matchingActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'Fixed while Color Matching is active.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: matchingActive
              ? _buildWhiteBalanceSection(context)
              : switch (_tempMode) {
                  _TempMode.defaultTemp => Center(
                    child: Text(
                      'Using the factory default color temperature',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ),
                  _TempMode.custom => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: _buildKelvinCard(context),
                  ),
                  _TempMode.user1 ||
                  _TempMode.user2 => _buildWhiteBalanceSection(context),
                },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        height: 680,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DialogTitleBar(
                title: 'Color Correction - ${widget.node.ipAddress}',
              ),
              TabBar(
                tabs: const [
                  Tab(text: 'Color Matching'),
                  Tab(text: 'Color Temperature'),
                ],
                labelStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 1),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: TabBarView(
                    children: [
                      // ── Color Matching ──────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('Off')),
                                ButtonSegment(
                                  value: 1,
                                  label: Text('3 Colors'),
                                ),
                                ButtonSegment(
                                  value: 2,
                                  label: Text('7 Colors'),
                                ),
                              ],
                              selected: {_method},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) async {
                                final method = s.first;
                                // Awaited: same reasoning as the Color
                                // Temperature switch — the reads below must
                                // land after CMAI0's write actually applies.
                                await _setMethod(method);
                                if (method == 0) {
                                  // QTE only reports something meaningful
                                  // once Color Matching is off again —
                                  // _tempMode may otherwise still be an
                                  // unverified guess (never resolved if the
                                  // dialog was opened while already in 3/7
                                  // colors) or stale from before switching.
                                  await _refreshTempMode();
                                  return;
                                }
                                // White Balance is the same shared register
                                // Color Temperature's User 1/2 edit — refresh
                                // it too whenever Color Matching becomes
                                // active, since QTE (and so _tempMode) can't
                                // be trusted to reflect it in that state.
                                await Future.wait([
                                  if (method == 1) _refreshColorMatching3(),
                                  if (method == 2) _refreshColorMatching7(),
                                  _refreshWhiteBalance(),
                                ]);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          Expanded(
                            child: _method == 0
                                ? Center(
                                    child: Text(
                                      'Color matching is disabled',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      14,
                                      20,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children:
                                          (_method == 1
                                                  ? ['Red', 'Green', 'Blue']
                                                  : [
                                                      'Red',
                                                      'Green',
                                                      'Blue',
                                                      'Cyan',
                                                      'Magenta',
                                                      'Yellow',
                                                      'White',
                                                    ])
                                              .map(
                                                (c) => _buildColorCard(
                                                  context,
                                                  c,
                                                  _method == 1
                                                      ? _values3
                                                      : _values7,
                                                  _method == 1
                                                      ? _set3Color
                                                      : _set7Color,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      // ── Color Temperature ───────────────────────────────
                      _buildColorTempTab(context),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
