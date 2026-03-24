import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';

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
  int _customK = 6500;          // 3200–13000 step 100
  List<int> _whHigh = [128, 128, 128]; // R,G,B  0–255
  List<int> _whLow  = [0, 0, 0];      // R,G,B  -127..+127 (display)

  String get _ip       => widget.node.ipAddress;
  int    get _port     => widget.node.port;
  String get _login    => widget.node.login;
  String get _password => widget.node.password;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final results = await Future.wait([
      // Color Matching — indices 0–10
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:CMAI0'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QMB'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS0'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS1'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS2'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS3'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS4'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS5'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:C7CS6'),
      // Color Temperature — indices 11–17
      _service.sendRawCommand(_ip, _port, _login, _password, 'QTE'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QHB'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOR'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOG'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QOB'),
    ]);

    if (!mounted) return;

    // ── Color Matching ────────────────────────────────────────────────────
    final methodRaw = results[0];
    if (methodRaw != null && methodRaw.contains('+')) {
      _method = int.tryParse(methodRaw.split('+').last) ?? 0;
    }

    final keys3 = ['Red', 'Green', 'Blue'];
    for (int i = 0; i < 3; i++) {
      final raw = results[1 + i];
      if (raw != null) {
        final parsed = _parseRgb(raw);
        if (parsed != null) _values3[keys3[i]] = parsed;
      }
    }

    final keys7 = ['Red', 'Green', 'Blue', 'Cyan', 'Magenta', 'Yellow', 'White'];
    for (int i = 0; i < 7; i++) {
      final raw = results[4 + i];
      if (raw != null) {
        final valuePart = raw.contains('=') ? raw.split('=').last : raw;
        final parsed = _parseRgb(valuePart);
        if (parsed != null) _values7[keys7[i]] = parsed;
      }
    }

    // ── Color Temperature ─────────────────────────────────────────────────
    final qteVal = int.tryParse(results[11]?.trim() ?? '');
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

    // White Balance High: 0–255
    final hr = int.tryParse(results[12]?.trim() ?? '');
    final hg = int.tryParse(results[13]?.trim() ?? '');
    final hb = int.tryParse(results[14]?.trim() ?? '');
    _whHigh = [
      (hr ?? 128).clamp(0, 255),
      (hg ?? 128).clamp(0, 255),
      (hb ?? 128).clamp(0, 255),
    ];

    // White Balance Low: protocol 001–255, display = protocol - 128
    final lr = int.tryParse(results[15]?.trim() ?? '');
    final lg = int.tryParse(results[16]?.trim() ?? '');
    final lb = int.tryParse(results[17]?.trim() ?? '');
    _whLow = [
      ((lr ?? 128) - 128).clamp(-127, 127),
      ((lg ?? 128) - 128).clamp(-127, 127),
      ((lb ?? 128) - 128).clamp(-127, 127),
    ];

    setState(() => _loading = false);
  }

  List<int>? _parseRgb(String raw) {
    final parts = raw.trim().split(',');
    if (parts.length != 3) return null;
    final values = parts.map((p) => int.tryParse(p.trim())).toList();
    if (values.any((v) => v == null)) return null;
    return values.cast<int>();
  }

  static String _fmt(int v)  => v.toString().padLeft(4, '0');
  static String _fmt3(int v) => v.toString().padLeft(3, '0');

  // ── Color Matching sends ──────────────────────────────────────────────────
  Future<void> _setMethod(int method) async {
    setState(() => _method = method);
    await _service.sendRawCommand(
      _ip, _port, _login, _password,
      'VXX:CMAI0=+${method.toString().padLeft(5, '0')}',
    );
  }

  Future<void> _set3Color(String color, List<int> rgb) async {
    final prefix = switch (color) {
      'Red'   => 'VMR',
      'Green' => 'VMG',
      _       => 'VMB',
    };
    await _service.sendRawCommand(
      _ip, _port, _login, _password,
      '$prefix:${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}',
    );
  }

  Future<void> _set7Color(String color, List<int> rgb) async {
    const keys7 = ['Red', 'Green', 'Blue', 'Cyan', 'Magenta', 'Yellow', 'White'];
    final idx = keys7.indexOf(color);
    if (idx == -1) return;
    await _service.sendRawCommand(
      _ip, _port, _login, _password,
      'VXX:C7CS$idx=${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}',
    );
  }

  // ── Color Temperature sends ───────────────────────────────────────────────
  Future<void> _sendColorTemp(_TempMode mode) async {
    final code = switch (mode) {
      _TempMode.defaultTemp => '10',
      _TempMode.user1       => '04',
      _TempMode.user2       => '09',
      _TempMode.custom      => '$_customK',
    };
    await _service.sendRawCommand(_ip, _port, _login, _password, 'OTE:$code');
  }

  Future<void> _sendWhHigh(int channel, int value) async {
    final cmd = switch (channel) { 0 => 'VHR', 1 => 'VHG', _ => 'VHB' };
    await _service.sendRawCommand(_ip, _port, _login, _password, '$cmd:${_fmt3(value)}');
  }

  Future<void> _sendWhLow(int channel, int displayValue) async {
    final cmd = switch (channel) { 0 => 'VOR', 1 => 'VOG', _ => 'VOB' };
    final protocol = (displayValue + 128).clamp(1, 255);
    await _service.sendRawCommand(_ip, _port, _login, _password, '$cmd:${_fmt3(protocol)}');
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  static Color _swatchFor(String name) => switch (name) {
    'Red'     => Colors.red,
    'Green'   => Colors.green,
    'Blue'    => Colors.blue,
    'Cyan'    => Colors.cyan,
    'Magenta' => const Color(0xFFCC44CC),
    'Yellow'  => Colors.yellow,
    _         => Colors.white,
  };

  Widget _buildRgbSlider(
    BuildContext context, {
    required String label,
    required Color color,
    required int value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
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
          SizedBox(
            width: 42,
            child: Text(displayValue, style: const TextStyle(fontSize: 11), textAlign: TextAlign.right),
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
      displayValue: '$value',
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }

  Widget _buildColorTile(
    BuildContext context,
    String colorName,
    Map<String, List<int>> valuesMap,
    Future<void> Function(String, List<int>) onSend,
  ) {
    final rgb = valuesMap[colorName]!;
    final swatch = _swatchFor(colorName);

    return ExpansionTile(
      initiallyExpanded: true,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: swatch,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      title: Text(colorName, style: const TextStyle(fontSize: 13)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        _buildColorMatchSliderRow(
          context, 'R', Colors.red, rgb[0],
          (v) => setState(() => valuesMap[colorName]![0] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
        ),
        _buildColorMatchSliderRow(
          context, 'G', Colors.green, rgb[1],
          (v) => setState(() => valuesMap[colorName]![1] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
        ),
        _buildColorMatchSliderRow(
          context, 'B', Colors.blue, rgb[2],
          (v) => setState(() => valuesMap[colorName]![2] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
        ),
      ],
    );
  }

  // ── Color Temperature tab ─────────────────────────────────────────────────
  Widget _buildColorTempTab(BuildContext context) {
    final theme = Theme.of(context);
    final showCustom = _tempMode == _TempMode.custom;
    final showWhiteBalance = _tempMode == _TempMode.user1 || _tempMode == _TempMode.user2;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownMenu<_TempMode>(
          initialSelection: _tempMode,
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          enableFilter: false,
          label: const Text('Color Temperature'),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: _TempMode.defaultTemp, label: 'Default'),
            DropdownMenuEntry(value: _TempMode.user1, label: 'User 1'),
            DropdownMenuEntry(value: _TempMode.user2, label: 'User 2'),
            DropdownMenuEntry(value: _TempMode.custom, label: 'Custom'),
          ],
          onSelected: (mode) {
            if (mode == null) return;
            setState(() => _tempMode = mode);
            _sendColorTemp(mode);
          },
        ),

        if (showCustom) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Color Temperature', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text('${_customK}K', style: theme.textTheme.titleSmall),
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
                    onChanged: (v) => setState(() => _customK = (v.round() ~/ 100) * 100),
                    onChangeEnd: (_) => _sendColorTemp(_TempMode.custom),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (showWhiteBalance) ...[
          const SizedBox(height: 24),
          Text('White Balance High', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final t in [(0, 'R', Colors.red), (1, 'G', Colors.green), (2, 'B', Colors.blue)])
            _buildRgbSlider(
              context,
              label: t.$2,
              color: t.$3,
              value: _whHigh[t.$1],
              min: 0,
              max: 255,
              divisions: 255,
              displayValue: '${_whHigh[t.$1]}',
              onChanged: (v) => setState(() => _whHigh[t.$1] = v.round()),
              onChangeEnd: (v) => _sendWhHigh(t.$1, v.round()),
            ),

          const SizedBox(height: 20),
          Text('White Balance Low', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final t in [(0, 'R', Colors.red), (1, 'G', Colors.green), (2, 'B', Colors.blue)])
            _buildRgbSlider(
              context,
              label: t.$2,
              color: t.$3,
              value: _whLow[t.$1],
              min: -127,
              max: 127,
              divisions: 254,
              displayValue: '${_whLow[t.$1] >= 0 ? '+' : ''}${_whLow[t.$1]}',
              onChanged: (v) => setState(() => _whLow[t.$1] = v.abs() <= 3.0 ? 0 : v.round()),
              onChangeEnd: (_) => _sendWhLow(t.$1, _whLow[t.$1]),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        height: 660,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar
              Container(
                color: theme.colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Color Correction — ${widget.node.ipAddress}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: const [
                  Tab(text: 'Color Matching'),
                  Tab(text: 'Color Temperature'),
                ],
                labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 1),

              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
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
                                ButtonSegment(value: 1, label: Text('3 Colors')),
                                ButtonSegment(value: 2, label: Text('7 Colors')),
                              ],
                              selected: {_method},
                              onSelectionChanged: (s) => _setMethod(s.first),
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
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  )
                                : ListView(
                                    children: (_method == 1
                                            ? ['Red', 'Green', 'Blue']
                                            : ['Red', 'Green', 'Blue', 'Cyan', 'Magenta', 'Yellow', 'White'])
                                        .map((c) => _buildColorTile(
                                              context, c,
                                              _method == 1 ? _values3 : _values7,
                                              _method == 1 ? _set3Color : _set7Color,
                                            ))
                                        .toList(),
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
