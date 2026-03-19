import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';

// Operating mode enum matching Panasonic OPEI1 protocol values.
enum _OperatingMode {
  normal,
  eco,
  quiet,
  user1,
  user2,
  user3;

  String get label => switch (this) {
    normal => 'Normal',
    eco => 'Eco',
    quiet => 'Quiet',
    user1 => 'User 1',
    user2 => 'User 2',
    user3 => 'User 3',
  };

  String get protocolValue => switch (this) {
    normal => '+00000',
    eco => '+00001',
    quiet => '+00021',
    user1 => '+00101',
    user2 => '+00102',
    user3 => '+00103',
  };

  static _OperatingMode fromProtocol(String value) => switch (value.trim()) {
    '+00001' => eco,
    '+00021' => quiet,
    '+00101' => user1,
    '+00102' => user2,
    '+00103' => user3,
    _ => normal,
  };

  bool get isUserMode => this == user1 || this == user2 || this == user3;
}

class BrightnessControlDialog extends StatefulWidget {
  final ProjectorNode node;

  const BrightnessControlDialog({super.key, required this.node});

  @override
  State<BrightnessControlDialog> createState() =>
      _BrightnessControlDialogState();
}

class _BrightnessControlDialogState extends State<BrightnessControlDialog> {
  final _service = PanasonicProtocolService();

  bool _loading = true;
  _OperatingMode _mode = _OperatingMode.normal;
  double _lightOutput = 100.0; // percentage 8–100
  double _maxLightOutput = 100.0; // percentage 8–100

  String get _ip => widget.node.ipAddress;
  int get _port => widget.node.port;
  String get _login => widget.node.login;
  String get _password => widget.node.password;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  // Protocol ↔ percentage conversion.
  // 50 = 8%, 1000 = 100% (linear).
  static double _toPercent(int v) => 8.0 + (v - 50) / 950 * 92;
  static int _toProtocol(double pct) => (50 + (pct - 8) / 92 * 950).round();
  static String _fmt(int v) => '+${v.toString().padLeft(5, '0')}';

  Future<void> _loadValues() async {
    final results = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:OPEI1'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:LOPI2'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:LOPI3'),
    ]);

    if (!mounted) return;

    final modeRaw = _parseValue(results[0], 'OPEI1');
    if (modeRaw != null) _mode = _OperatingMode.fromProtocol(modeRaw);

    final lopi2 = _parseInt(results[1], 'LOPI2');
    if (lopi2 != null) _lightOutput = _toPercent(lopi2).clamp(8.0, 100.0);

    final lopi3 = _parseInt(results[2], 'LOPI3');
    if (lopi3 != null) _maxLightOutput = _toPercent(lopi3).clamp(8.0, 100.0);

    setState(() => _loading = false);
  }

  // Extract value after "KEY=" from a protocol response string.
  String? _parseValue(String? response, String key) {
    if (response == null) return null;
    final idx = response.indexOf('$key=');
    if (idx < 0) return null;
    return response.substring(idx + key.length + 1).trim();
  }

  int? _parseInt(String? response, String key) {
    final raw = _parseValue(response, key);
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll('+', '').replaceAll('-', ''));
  }

  Future<void> _sendMode(_OperatingMode mode) async {
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'VXX:OPEI1=${mode.protocolValue}',
    );
  }

  Future<void> _sendLightOutput(double pct) async {
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'VXX:LOPI2=${_fmt(_toProtocol(pct))}',
    );
  }

  Future<void> _sendMaxLightOutput(double pct) async {
    await _service.sendRawCommand(
      _ip,
      _port,
      _login,
      _password,
      'VXX:LOPI3=${_fmt(_toProtocol(pct))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUserMode = _mode.isUserMode;
    // In user modes the light output ceiling is the max light output value.
    final lightMax = isUserMode ? _maxLightOutput : 100.0;
    final clampedLight = _lightOutput.clamp(8.0, lightMax);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title bar ───────────────────────────────────────────────
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Text(
              'Brightness Control - Projector ${widget.node.ipAddress}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Operating Mode ─────────────────────────────────────────
                  Text(
                    'Operating Mode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownMenu<_OperatingMode>(
                    requestFocusOnTap: false,
                    enableFilter: false,
                    initialSelection: _mode,
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _OperatingMode.values
                        .map((m) => DropdownMenuEntry(value: m, label: m.label))
                        .toList(),
                    onSelected: (m) {
                      if (m == null) return;
                      setState(() {
                        _mode = m;
                        // When switching to user mode clamp light output to max.
                        if (m.isUserMode && _lightOutput > _maxLightOutput) {
                          _lightOutput = _maxLightOutput;
                        }
                      });
                      _sendMode(m);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Light Output ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Light Output',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${clampedLight.round()}%',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  Slider(
                    min: 8,
                    max: lightMax,
                    divisions: (lightMax - 8).round().clamp(1, 92),
                    value: clampedLight,
                    label: '${clampedLight.round()}%',
                    onChanged: (v) => setState(() => _lightOutput = v),
                    onChangeEnd: _sendLightOutput,
                  ),
                  const SizedBox(height: 16),

                  // ── Max Light Output ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max Light Output',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUserMode ? null : theme.disabledColor,
                        ),
                      ),
                      Text(
                        '${_maxLightOutput.round()}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isUserMode ? null : theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 8,
                    max: 100,
                    divisions: 92,
                    value: _maxLightOutput,
                    label: '${_maxLightOutput.round()}%',
                    onChanged: isUserMode
                        ? (v) => setState(() {
                            _maxLightOutput = v;
                            // Keep light output within new ceiling.
                            if (_lightOutput > v) _lightOutput = v;
                          })
                        : null,
                    onChangeEnd: isUserMode ? _sendMaxLightOutput : null,
                  ),
                  Visibility(
                    maintainSize: true,
                    maintainState: true,
                    maintainAnimation: true,
                    visible: !isUserMode,
                    child: Text(
                      'Max Light Output is only available in User 1, 2 or 3 mode.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
