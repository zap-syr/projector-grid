import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';

class ColorCorrectionDialog extends StatefulWidget {
  final ProjectorNode node;

  const ColorCorrectionDialog({super.key, required this.node});

  @override
  State<ColorCorrectionDialog> createState() => _ColorCorrectionDialogState();
}

class _ColorCorrectionDialogState extends State<ColorCorrectionDialog> {
  final _service = PanasonicProtocolService();

  bool _loading = true;
  int _method = 0; // 0=off, 1=3colors, 2=7colors

  // 3-color target values: [r, g, b], range 0–2048
  final _values3 = <String, List<int>>{
    'Red': [2048, 0, 0],
    'Green': [0, 2048, 0],
    'Blue': [0, 0, 2048],
  };

  // 7-color target values: [r, g, b], range 0–2048
  final _values7 = <String, List<int>>{
    'Red': [2048, 0, 0],
    'Green': [0, 2048, 0],
    'Blue': [0, 0, 2048],
    'Cyan': [0, 2048, 2048],
    'Magenta': [2048, 0, 2048],
    'Yellow': [2048, 2048, 0],
    'White': [2048, 2048, 2048],
  };

  String get _ip => widget.node.ipAddress;
  int get _port => widget.node.port;
  String get _login => widget.node.login;
  String get _password => widget.node.password;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final results = await Future.wait([
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
    ]);

    if (!mounted) return;

    // Parse method: response "CMAI0=+00001" → extract int after '+'
    final methodRaw = results[0];
    if (methodRaw != null && methodRaw.contains('+')) {
      _method = int.tryParse(methodRaw.split('+').last) ?? 0;
    }

    // Parse 3-color values: response "RRRR,GGGG,BBBB"
    final keys3 = ['Red', 'Green', 'Blue'];
    for (int i = 0; i < 3; i++) {
      final raw = results[1 + i];
      if (raw != null) {
        final parsed = _parseRgb(raw);
        if (parsed != null) _values3[keys3[i]] = parsed;
      }
    }

    // Parse 7-color values: response "C7CSx=RRRR,GGGG,BBBB"
    final keys7 = [
      'Red',
      'Green',
      'Blue',
      'Cyan',
      'Magenta',
      'Yellow',
      'White',
    ];
    for (int i = 0; i < 7; i++) {
      final raw = results[4 + i];
      if (raw != null) {
        final valuePart = raw.contains('=') ? raw.split('=').last : raw;
        final parsed = _parseRgb(valuePart);
        if (parsed != null) _values7[keys7[i]] = parsed;
      }
    }

    setState(() => _loading = false);
  }

  List<int>? _parseRgb(String raw) {
    final parts = raw.trim().split(',');
    if (parts.length != 3) return null;
    final values = parts.map((p) => int.tryParse(p.trim())).toList();
    if (values.any((v) => v == null)) return null;
    return values.cast<int>();
  }

  static String _fmt(int v) => v.toString().padLeft(4, '0');

  Future<void> _setMethod(int method) async {
    setState(() => _method = method);
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'VXX:CMAI0=+${method.toString().padLeft(5, '0')}',
    );
  }

  Future<void> _set3Color(String color, List<int> rgb) async {
    final prefix = switch (color) {
      'Red' => 'VMR',
      'Green' => 'VMG',
      _ => 'VMB',
    };
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      '$prefix:${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}',
    );
  }

  Future<void> _set7Color(String color, List<int> rgb) async {
    final keys7 = [
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
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'VXX:C7CS$idx=${_fmt(rgb[0])},${_fmt(rgb[1])},${_fmt(rgb[2])}',
    );
  }

  static Color _swatchFor(String name) => switch (name) {
    'Red' => Colors.red,
    'Green' => Colors.green,
    'Blue' => Colors.blue,
    'Cyan' => Colors.cyan,
    'Magenta' => const Color(0xFFCC44CC),
    'Yellow' => Colors.yellow,
    _ => Colors.white,
  };

  Widget _buildSliderRow(
    BuildContext context,
    String label,
    Color color,
    int value,
    ValueChanged<double> onChanged,
    ValueChanged<double> onChangeEnd,
  ) {
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
                min: 0,
                max: 2048,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
        _buildSliderRow(
          context,
          'R',
          Colors.red,
          rgb[0],
          (v) => setState(() => valuesMap[colorName]![0] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
        ),
        _buildSliderRow(
          context,
          'G',
          Colors.green,
          rgb[1],
          (v) => setState(() => valuesMap[colorName]![1] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
        ),
        _buildSliderRow(
          context,
          'B',
          Colors.blue,
          rgb[2],
          (v) => setState(() => valuesMap[colorName]![2] = v.round()),
          (_) => onSend(colorName, List.from(valuesMap[colorName]!)),
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
        width: 520,
        height: 580,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title bar ─────────────────────────────────────────────
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Color Correction - Projector ${widget.node.ipAddress}',
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
            const Divider(height: 1),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              // Method selector
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

              // Color tiles or disabled message
              Expanded(
                child: _method == 0
                    ? Center(
                        child: Text(
                          'Color matching is disabled',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      )
                    : ListView(
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
                                  (c) => _buildColorTile(
                                    context,
                                    c,
                                    _method == 1 ? _values3 : _values7,
                                    _method == 1 ? _set3Color : _set7Color,
                                  ),
                                )
                                .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
