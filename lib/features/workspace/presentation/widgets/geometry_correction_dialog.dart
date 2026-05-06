import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/projector_node.dart';
import '../../../../core/services/panasonic_protocol_service.dart';
import 'sleek_stepper_input.dart';

// ─── Mode enum ─────────────────────────────────────────────────────────────
enum _GeometryMode {
  off,
  keystone,
  curved,
  corner;

  String get label => switch (this) {
    off => 'Off',
    keystone => 'Keystone',
    curved => 'Curved Correction',
    corner => 'Corner Correction',
  };

  String get protocolValue => switch (this) {
    off => '+00000',
    keystone => '+00001',
    curved => '+00002',
    corner => '+00010',
  };

  static _GeometryMode fromProtocol(String value) => switch (value.trim()) {
    '+00001' => keystone,
    '+00002' => curved,
    '+00010' => corner,
    _ => off,
  };
}

// ─── Per-mode state holders ────────────────────────────────────────────────
class _CornerState {
  // V displacement (GMFI1–4): UL, UR, LL, LR
  int gmfi1 = 0, gmfi2 = 0, gmfi3 = 0, gmfi4 = 0;
  // H displacement (GMFI6–9): UL, UR, LL, LR
  int gmfi6 = 0, gmfi7 = 0, gmfi8 = 0, gmfi9 = 0;
  // Linearity V/H (GMFI5, GMFIA)
  int gmfi5 = 0, gmfia = 0;
  // Pincushion: upper, lower, left, right (GMFIB–E)
  int gmfib = 0, gmfic = 0, gmfid = 0, gmfie = 0;
  // Linearity/Pincushion mode: 0 = AUTO, 1 = MANUAL (GMFIF)
  int gmfif = 0;
}

class _KeystoneState {
  double gmks0 = 1.5; // throw ratio
  int gmki4 = 0;       // V balance
  int gmki7 = 0;       // H balance
  double gmks8 = 0.0;  // V keystone
  double gmks9 = 0.0;  // H keystone
}

class _CurvedState {
  double gmcs0 = 1.5; // throw ratio
  int gmci2 = 0;       // V balance
  int gmci3 = 0;       // V arc
  int gmci6 = 0;       // H balance
  int gmci7 = 0;       // H arc
  double gmcs8 = 0.0;  // V keystone
  double gmcs9 = 0.0;  // H keystone
  bool gmcia = false;  // maintain aspect ratio
}

// ─── Dialog ─────────────────────────────────────────────────────────────────
class GeometryCorrectionDialog extends StatefulWidget {
  final ProjectorNode node;

  const GeometryCorrectionDialog({super.key, required this.node});

  @override
  State<GeometryCorrectionDialog> createState() =>
      _GeometryCorrectionDialogState();
}

class _GeometryCorrectionDialogState extends State<GeometryCorrectionDialog> {
  final _service = PanasonicProtocolService();

  bool _loading = true;
  bool _modeLoading = false;
  _GeometryMode _mode = _GeometryMode.off;
  final Set<_GeometryMode> _loadedModes = {};

  final _corner = _CornerState();
  final _keystone = _KeystoneState();
  final _curved = _CurvedState();

  final _cornerCanvasKey = GlobalKey<_CornerCorrectionCanvasState>();

  String get _ip => widget.node.ipAddress;
  int get _port => widget.node.port;
  String get _login => widget.node.login;
  String get _password => widget.node.password;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // ─── Loading ─────────────────────────────────────────────────────────────
  Future<void> _loadInitial() async {
    final raw = await _service.sendRawCommand(
      _ip, _port, _login, _password, 'QVX:GMMI0',
    );
    if (!mounted) return;

    final modeRaw = _parseValue(raw, 'GMMI0');
    if (modeRaw != null) _mode = _GeometryMode.fromProtocol(modeRaw);

    setState(() => _loading = false);
    await _ensureModeLoaded(_mode);
  }

  Future<void> _ensureModeLoaded(_GeometryMode mode) async {
    if (_loadedModes.contains(mode)) return;
    if (mode == _GeometryMode.off) {
      _loadedModes.add(mode);
      return;
    }

    setState(() => _modeLoading = true);
    switch (mode) {
      case _GeometryMode.corner:
        await _loadCorner();
        break;
      case _GeometryMode.keystone:
        await _loadKeystone();
        break;
      case _GeometryMode.curved:
        await _loadCurved();
        break;
      default:
        break;
    }
    if (!mounted) return;
    _loadedModes.add(mode);
    setState(() => _modeLoading = false);
  }

  Future<void> _loadCorner() async {
    final keys = [
      'GMFI1', 'GMFI2', 'GMFI3', 'GMFI4',
      'GMFI6', 'GMFI7', 'GMFI8', 'GMFI9',
      'GMFI5', 'GMFIA',
      'GMFIB', 'GMFIC', 'GMFID', 'GMFIE',
      'GMFIF',
    ];
    final results = await Future.wait(
      keys.map((k) => _service.sendRawCommand(
        _ip, _port, _login, _password, 'QVX:$k',
      )),
    );
    if (!mounted) return;

    int parseAt(int i, String key) =>
        _parseInt(results[i], key) ?? 0;

    _corner
      ..gmfi1 = parseAt(0, 'GMFI1')
      ..gmfi2 = parseAt(1, 'GMFI2')
      ..gmfi3 = parseAt(2, 'GMFI3')
      ..gmfi4 = parseAt(3, 'GMFI4')
      ..gmfi6 = parseAt(4, 'GMFI6')
      ..gmfi7 = parseAt(5, 'GMFI7')
      ..gmfi8 = parseAt(6, 'GMFI8')
      ..gmfi9 = parseAt(7, 'GMFI9')
      ..gmfi5 = parseAt(8, 'GMFI5')
      ..gmfia = parseAt(9, 'GMFIA')
      ..gmfib = parseAt(10, 'GMFIB')
      ..gmfic = parseAt(11, 'GMFIC')
      ..gmfid = parseAt(12, 'GMFID')
      ..gmfie = parseAt(13, 'GMFIE')
      ..gmfif = parseAt(14, 'GMFIF');
  }

  Future<void> _loadKeystone() async {
    final results = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMKS0'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMKI4'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMKI7'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMKS8'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMKS9'),
    ]);
    if (!mounted) return;

    _keystone
      ..gmks0 = _parseDouble(results[0], 'GMKS0') ?? 1.5
      ..gmki4 = _parseInt(results[1], 'GMKI4') ?? 0
      ..gmki7 = _parseInt(results[2], 'GMKI7') ?? 0
      ..gmks8 = _parseDouble(results[3], 'GMKS8') ?? 0.0
      ..gmks9 = _parseDouble(results[4], 'GMKS9') ?? 0.0;
  }

  Future<void> _loadCurved() async {
    final results = await Future.wait([
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCS0'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCI2'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCI3'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCI6'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCI7'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCS8'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCS9'),
      _service.sendRawCommand(_ip, _port, _login, _password, 'QVX:GMCIA'),
    ]);
    if (!mounted) return;

    _curved
      ..gmcs0 = _parseDouble(results[0], 'GMCS0') ?? 1.5
      ..gmci2 = _parseInt(results[1], 'GMCI2') ?? 0
      ..gmci3 = _parseInt(results[2], 'GMCI3') ?? 0
      ..gmci6 = _parseInt(results[3], 'GMCI6') ?? 0
      ..gmci7 = _parseInt(results[4], 'GMCI7') ?? 0
      ..gmcs8 = _parseDouble(results[5], 'GMCS8') ?? 0.0
      ..gmcs9 = _parseDouble(results[6], 'GMCS9') ?? 0.0
      ..gmcia = (_parseInt(results[7], 'GMCIA') ?? 0) == 1;
  }

  // ─── Response parsing ────────────────────────────────────────────────────
  String? _parseValue(String? response, String key) {
    if (response == null) return null;
    final keyed = '$key=';
    final idx = response.indexOf(keyed);
    if (idx >= 0) return response.substring(idx + keyed.length).trim();
    final eq = response.indexOf('=');
    if (eq >= 0) return response.substring(eq + 1).trim();
    return response.trim();
  }

  int? _parseInt(String? response, String key) {
    final raw = _parseValue(response, key);
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll('+', ''));
  }

  double? _parseDouble(String? response, String key) {
    final raw = _parseValue(response, key);
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll('+', ''));
  }

  // ─── Formatters ──────────────────────────────────────────────────────────
  // Clean numeric string for SleekStepperInput: integer when whole, 1dp otherwise.
  static String _cleanStr(double v) {
    final r = v.roundToDouble();
    return v == r ? r.toInt().toString() : v.toStringAsFixed(1);
  }

  static String _fmtInt(int v) =>
      '${v >= 0 ? '+' : '-'}${v.abs().toString().padLeft(5, '0')}';

  static String _fmtDeg(double v) {
    final clamped = double.parse(v.toStringAsFixed(1));
    return '${clamped >= 0 ? '+' : '-'}${clamped.abs().toStringAsFixed(1)}';
  }

  static String _fmtThrow(double v) {
    final clamped = double.parse(v.toStringAsFixed(1));
    final body = clamped.toStringAsFixed(1).padLeft(4, '0');
    return '+$body';
  }

  // ─── Senders ─────────────────────────────────────────────────────────────
  Future<void> _sendMode(_GeometryMode m) => _service.sendRawCommand(
    _ip, _port, _login, _password, 'VXX:GMMI0=${m.protocolValue}',
  );

  Future<void> _sendInt(String key, int v) => _service.sendRawCommand(
    _ip, _port, _login, _password, 'VXX:$key=${_fmtInt(v)}',
  );

  Future<void> _sendDeg(String key, double v) => _service.sendRawCommand(
    _ip, _port, _login, _password, 'VXX:$key=${_fmtDeg(v)}',
  );

  Future<void> _sendThrow(String key, double v) => _service.sendRawCommand(
    _ip, _port, _login, _password, 'VXX:$key=${_fmtThrow(v)}',
  );

  Future<void> _sendBool(String key, bool on) =>
      _sendInt(key, on ? 1 : 0);

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 520,
          maxWidth: 920,
          maxHeight: screenHeight * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Geometry Correction - ${widget.node.ipAddress}',
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
              // Mode dropdown — full width across both columns
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: DropdownMenu<_GeometryMode>(
                  requestFocusOnTap: false,
                  enableFilter: false,
                  initialSelection: _mode,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Correction Mode'),
                  inputDecorationTheme: const InputDecorationTheme(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  dropdownMenuEntries: _GeometryMode.values
                      .map((m) => DropdownMenuEntry(value: m, label: m.label))
                      .toList(),
                  onSelected: (m) {
                    if (m == null || m == _mode) return;
                    setState(() => _mode = m);
                    _sendMode(m);
                    _ensureModeLoaded(m);
                  },
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: _modeLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() => switch (_mode) {
    _GeometryMode.off => _buildOffBody(),
    _GeometryMode.corner => _buildCornerBody(),
    _GeometryMode.keystone => _buildKeystoneBody(),
    _GeometryMode.curved => _buildCurvedBody(),
  };

  // Two-column split: canvas left (5 parts) + scrollable controls right (4 parts).
  // Both panels grow proportionally so the canvas stays large at any dialog width.
  Widget _buildSplitLayout({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: left),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: right,
          ),
        ),
      ],
    );
  }

  // ─── Off / PC placeholders ───────────────────────────────────────────────
  Widget _buildOffBody() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Text(
        'Geometry correction is disabled.\nSelect a mode above to enable it.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ),
  );

  // ─── Corner Correction ───────────────────────────────────────────────────
  Future<void> _resetAllCorners() async {
    setState(() {
      _corner
        ..gmfi1 = 0 ..gmfi2 = 0 ..gmfi3 = 0 ..gmfi4 = 0
        ..gmfi6 = 0 ..gmfi7 = 0 ..gmfi8 = 0 ..gmfi9 = 0;
    });
    for (final key in ['GMFI1','GMFI2','GMFI3','GMFI4','GMFI6','GMFI7','GMFI8','GMFI9']) {
      await _sendInt(key, 0);
    }
  }

  Widget _buildCornerBody() {
    return _buildSplitLayout(
      left: _buildCornerLeftPanel(),
      right: _buildCornerSliders(),
    );
  }

  Widget _buildCornerLeftPanel() {
    // GestureDetector with translucent behavior catches taps on any empty space
    // in the panel (padding, area above/below the scaled canvas) and clears
    // selection. Inner handle detectors still win the arena for handle taps.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _cornerCanvasKey.currentState?.clearSelection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reset all corners',
              iconSize: 20,
              onPressed: _resetAllCorners,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _CornerCorrectionCanvas(
                key: _cornerCanvasKey,
                state: _corner,
                onCornerChanged: () => setState(() {}),
                onCornerCommit: (List<(String, int)> commands) async {
                  for (final (key, value) in commands) {
                    await _sendInt(key, value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerSliders() {
    final manual = _corner.gmfif == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Linearity & Pincushion',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Auto')),
                ButtonSegment(value: 1, label: Text('Manual')),
              ],
              selected: {_corner.gmfif},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                setState(() => _corner.gmfif = v.first);
                _sendInt('GMFIF', v.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sliderRow(
          label: 'Linearity V',
          value: _corner.gmfi5.toDouble(),
          min: -127, max: 127,
          onChanged: manual ? (v) => setState(() => _corner.gmfi5 = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFI5', v.round()) : null,
        ),
        _sliderRow(
          label: 'Linearity H',
          value: _corner.gmfia.toDouble(),
          min: -127, max: 127,
          onChanged: manual ? (v) => setState(() => _corner.gmfia = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFIA', v.round()) : null,
        ),
        _sliderRow(
          label: 'Pincushion Upper',
          value: _corner.gmfib.toDouble(),
          min: -100, max: 100,
          onChanged: manual ? (v) => setState(() => _corner.gmfib = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFIB', v.round()) : null,
        ),
        _sliderRow(
          label: 'Pincushion Lower',
          value: _corner.gmfic.toDouble(),
          min: -100, max: 100,
          onChanged: manual ? (v) => setState(() => _corner.gmfic = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFIC', v.round()) : null,
        ),
        _sliderRow(
          label: 'Pincushion Left',
          value: _corner.gmfid.toDouble(),
          min: -100, max: 100,
          onChanged: manual ? (v) => setState(() => _corner.gmfid = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFID', v.round()) : null,
        ),
        _sliderRow(
          label: 'Pincushion Right',
          value: _corner.gmfie.toDouble(),
          min: -100, max: 100,
          onChanged: manual ? (v) => setState(() => _corner.gmfie = v.round()) : null,
          onChangeEnd: manual ? (v) => _sendInt('GMFIE', v.round()) : null,
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
    required ValueChanged<double>? onChangeEnd,
  }) {
    final enabled = onChanged != null || onChangeEnd != null;
    final stepper = SleekStepperInput(
      initialValue: _cleanStr(value),
      min: min,
      max: max,
      onValueChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) {
          onChanged?.call(v);
          onChangeEnd?.call(v);
        }
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
            const SizedBox(width: 16),
            enabled
                ? stepper
                : IgnorePointer(
                    child: Opacity(opacity: 0.38, child: stepper),
                  ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Keystone ────────────────────────────────────────────────────────────
  Widget _buildKeystoneBody() {
    return _buildSplitLayout(
      left: _buildPreviewUnavailable(),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledSlider(
            label: 'Vertical Keystone',
            value: _keystone.gmks8,
            min: -40, max: 40,
            step: 0.2,
            onChanged: (v) => setState(() =>
                _keystone.gmks8 = double.parse(v.toStringAsFixed(1))),
            onChangeEnd: (v) => _sendDeg('GMKS8',
                double.parse(v.toStringAsFixed(1))),
          ),
          _labeledSlider(
            label: 'Horizontal Keystone',
            value: _keystone.gmks9,
            min: -15, max: 15,
            step: 0.2,
            onChanged: (v) => setState(() =>
                _keystone.gmks9 = double.parse(v.toStringAsFixed(1))),
            onChangeEnd: (v) => _sendDeg('GMKS9',
                double.parse(v.toStringAsFixed(1))),
          ),
          _labeledSlider(
            label: 'Vertical Balance',
            value: _keystone.gmki4.toDouble(),
            min: -60, max: 60,
            onChanged: (v) => setState(() => _keystone.gmki4 = v.round()),
            onChangeEnd: (v) => _sendInt('GMKI4', v.round()),
          ),
          _labeledSlider(
            label: 'Horizontal Balance',
            value: _keystone.gmki7.toDouble(),
            min: -30, max: 30,
            onChanged: (v) => setState(() => _keystone.gmki7 = v.round()),
            onChangeEnd: (v) => _sendInt('GMKI7', v.round()),
          ),
          _throwRatioField(
            value: _keystone.gmks0,
            onCommit: (v) {
              setState(() => _keystone.gmks0 = v);
              _sendThrow('GMKS0', v);
            },
          ),
        ],
      ),
    );
  }

  // ─── Curved ──────────────────────────────────────────────────────────────
  Widget _buildCurvedBody() {
    return _buildSplitLayout(
      left: _buildPreviewUnavailable(),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledSlider(
            label: 'Vertical Arc',
            value: _curved.gmci3.toDouble(),
            min: -40, max: 40,
            onChanged: (v) => setState(() => _curved.gmci3 = v.round()),
            onChangeEnd: (v) => _sendInt('GMCI3', v.round()),
          ),
          _labeledSlider(
            label: 'Horizontal Arc',
            value: _curved.gmci7.toDouble(),
            min: -40, max: 40,
            onChanged: (v) => setState(() => _curved.gmci7 = v.round()),
            onChangeEnd: (v) => _sendInt('GMCI7', v.round()),
          ),
          _labeledSlider(
            label: 'Vertical Keystone',
            value: _curved.gmcs8,
            min: -40, max: 40,
            step: 0.2,
            onChanged: (v) => setState(() =>
                _curved.gmcs8 = double.parse(v.toStringAsFixed(1))),
            onChangeEnd: (v) => _sendDeg('GMCS8',
                double.parse(v.toStringAsFixed(1))),
          ),
          _labeledSlider(
            label: 'Horizontal Keystone',
            value: _curved.gmcs9,
            min: -15, max: 15,
            step: 0.2,
            onChanged: (v) => setState(() =>
                _curved.gmcs9 = double.parse(v.toStringAsFixed(1))),
            onChangeEnd: (v) => _sendDeg('GMCS9',
                double.parse(v.toStringAsFixed(1))),
          ),
          _labeledSlider(
            label: 'Vertical Balance',
            value: _curved.gmci2.toDouble(),
            min: -60, max: 60,
            onChanged: (v) => setState(() => _curved.gmci2 = v.round()),
            onChangeEnd: (v) => _sendInt('GMCI2', v.round()),
          ),
          _labeledSlider(
            label: 'Horizontal Balance',
            value: _curved.gmci6.toDouble(),
            min: -30, max: 30,
            onChanged: (v) => setState(() => _curved.gmci6 = v.round()),
            onChangeEnd: (v) => _sendInt('GMCI6', v.round()),
          ),
          _throwRatioField(
            value: _curved.gmcs0,
            onCommit: (v) {
              setState(() => _curved.gmcs0 = v);
              _sendThrow('GMCS0', v);
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Maintain Aspect Ratio',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _curved.gmcia,
                onChanged: (v) {
                  setState(() => _curved.gmcia = v);
                  _sendBool('GMCIA', v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Preview not available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Left panel canvas for keystone/curved modes — fills available height.
  // ignore: unused_element
  Widget _buildTrapezoidPanel({
    required double vKeystone,
    required double hKeystone,
    required int vArc,
    required int hArc,
    required int vBalance,
    required int hBalance,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Preview',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _TrapezoidCanvas(
              vKeystone: vKeystone,
              hKeystone: hKeystone,
              vArc: vArc,
              hArc: hArc,
              vBalance: vBalance,
              hBalance: hBalance,
            ),
          ),
        ),
      ],
    );
  }

  // Slider with label/stepper row above; full-width track.
  Widget _labeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    double step = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: ((max - min) / step).round(),
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SleekStepperInput(
              initialValue: _cleanStr(value),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _throwRatioField({
    required double value,
    required ValueChanged<double> onCommit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lens Throw Ratio',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: 16),
            SleekStepperInput(
              initialValue: value.toStringAsFixed(1),
              min: 0.7,
              max: 16.5,
              step: 0.1,
              onValueChanged: (s) {
                final v = double.tryParse(s);
                if (v != null) onCommit(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}


// ─── Trapezoid Canvas (keystone + curved preview) ──────────────────────────
class _TrapezoidCanvas extends StatelessWidget {
  final double vKeystone; // -40..40
  final double hKeystone; // -15..15
  final int vArc;          // -40..40
  final int hArc;          // -40..40
  final int vBalance;      // -60..60
  final int hBalance;      // -30..30

  const _TrapezoidCanvas({
    required this.vKeystone,
    required this.hKeystone,
    required this.vArc,
    required this.hArc,
    required this.vBalance,
    required this.hBalance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FittedBox scales to fill whatever space the parent gives while preserving
    // the 480×280 internal coordinate system used by the painter.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 480,
        height: 280,
        child: CustomPaint(
          painter: _TrapezoidPainter(
            vKeystone: vKeystone,
            hKeystone: hKeystone,
            vArc: vArc,
            hArc: hArc,
            vBalance: vBalance,
            hBalance: hBalance,
            outline: theme.colorScheme.primary,
            fill: theme.colorScheme.primary.withValues(alpha: 0.10),
            defaultColor: theme.dividerColor,
          ),
        ),
      ),
    );
  }
}

class _TrapezoidPainter extends CustomPainter {
  final double vKeystone, hKeystone;
  final int vArc, hArc;
  final int vBalance, hBalance;
  final Color outline, fill, defaultColor;

  _TrapezoidPainter({
    required this.vKeystone,
    required this.hKeystone,
    required this.vArc,
    required this.hArc,
    required this.vBalance,
    required this.hBalance,
    required this.outline,
    required this.fill,
    required this.defaultColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const defaultRect = Rect.fromLTRB(120, 60, 360, 220);

    // Reference outline — outside clip so it is always fully visible.
    canvas.drawRect(
      defaultRect,
      Paint()
        ..color = defaultColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Vertex calculation ──────────────────────────────────────────────────
    double min(double a, double b) => a < b ? a : b;

    final double vK = vKeystone.abs() / 40.0;
    final double hK = hKeystone.abs() / 15.0;

    final double vPinchX = vK * 60.0;
    final double vCompY  = vK * 40.0;

    final double hPinchY = hK * 40.0;
    final double hCompX  = hK * 60.0;

    double tlX = defaultRect.left;   double tlY = defaultRect.top;
    double trX = defaultRect.right;  double trY = defaultRect.top;
    double blX = defaultRect.left;   double blY = defaultRect.bottom;
    double brX = defaultRect.right;  double brY = defaultRect.bottom;

    // 1. Base Vertical Keystone
    if (vKeystone > 0) {
      tlX += vPinchX; trX -= vPinchX; // Top pinches inward
      blY -= vCompY;  brY -= vCompY;  // Bottom compensates UP
    } else if (vKeystone < 0) {
      blX += vPinchX; brX -= vPinchX; // Bottom pinches inward
      tlY += vCompY;  trY += vCompY;  // Top compensates DOWN
    }

    // 2. Horizontal Keystone with Matrix Overlap Sliding

    // [!] TWEAK THIS VALUE (0.35 - 0.40) TO ADJUST THE MAXIMUM SLIDE LIMIT
    final double maxSlideY = defaultRect.height * 0.46;

    if (hKeystone > 0) {
      tlY += hPinchY; blY -= hPinchY; // Left pinches inward

      if (vKeystone > 0) {
        // vKeystone moved bottom edge UP. LEFT edge slides DOWN to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(slideY, maxSlideY); // Apply hard limit to prevent triangle folding
        tlY += slideY; blY += slideY;

        double remRatio = hPinchY == 0 ? 0.0 : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        trX -= hCompX * remRatio; brX -= hCompX * remRatio;
      } else if (vKeystone < 0) {
        // vKeystone moved top edge DOWN. LEFT edge slides UP to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(slideY, maxSlideY); // Apply hard limit to prevent triangle folding
        tlY -= slideY; blY -= slideY;

        double remRatio = hPinchY == 0 ? 0.0 : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        trX -= hCompX * remRatio; brX -= hCompX * remRatio;
      } else {
        trX -= hCompX; brX -= hCompX;
      }
    } else if (hKeystone < 0) {
      trY += hPinchY; brY -= hPinchY; // Right pinches inward

      if (vKeystone > 0) {
        // vKeystone moved bottom edge UP. RIGHT edge slides DOWN to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(slideY, maxSlideY); // Apply hard limit to prevent triangle folding
        trY += slideY; brY += slideY;

        double remRatio = hPinchY == 0 ? 0.0 : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        tlX += hCompX * remRatio; blX += hCompX * remRatio;
      } else if (vKeystone < 0) {
        // vKeystone moved top edge DOWN. RIGHT edge slides UP to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(slideY, maxSlideY); // Apply hard limit to prevent triangle folding
        trY -= slideY; brY -= slideY;

        double remRatio = hPinchY == 0 ? 0.0 : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        tlX += hCompX * remRatio; blX += hCompX * remRatio;
      } else {
        tlX += hCompX; blX += hCompX;
      }
    }

    // ── Balance adjustments ─────────────────────────────────────────────────
    // Applied after keystone; clamped to defaultRect so nothing escapes.
    final vBalDelta = (vBalance / 60.0) * 20.0;
    final hBalDelta = (hBalance / 30.0) * 12.0;

    if (vKeystone.abs() > 0.01) {
      if (vKeystone > 0) {
        // vBalance shifts bottom (unpinched) edge vertically — inverted.
        blY -= vBalDelta;  brY -= vBalDelta;
        // hBalance shifts top (pinched) corners horizontally (positive = left).
        tlX -= hBalDelta;  trX -= hBalDelta;
      } else {
        // vBalance shifts top (unpinched) edge — inverted.
        tlY -= vBalDelta;  trY -= vBalDelta;
        blX -= hBalDelta;  brX -= hBalDelta;
      }
    }

    if (hKeystone.abs() > 0.01) {
      if (hKeystone > 0) {
        // hBalance shifts right (unpinched) edge — inverted.
        trX += hBalDelta;  brX += hBalDelta;
        // vBalance shifts left (pinched) corners vertically (positive = down).
        tlY += vBalDelta;  blY += vBalDelta;
      } else {
        // hBalance shifts left (unpinched) edge — inverted.
        tlX += hBalDelta;  blX += hBalDelta;
        trY += vBalDelta;  brY += vBalDelta;
      }
    }

    // Clamp — the physical matrix is the hard limit.
    double cx(double x) => x.clamp(defaultRect.left, defaultRect.right);
    double cy(double y) => y.clamp(defaultRect.top, defaultRect.bottom);

    final topLeft     = Offset(cx(tlX), cy(tlY));
    final topRight    = Offset(cx(trX), cy(trY));
    final bottomLeft  = Offset(cx(blX), cy(blY));
    final bottomRight = Offset(cx(brX), cy(brY));

    // ── Arc bows (curved mode only; both 0 in keystone mode) ───────────────
    final vBow = (vArc / 40.0) * 30.0;
    final hBow = (hArc / 40.0) * 30.0;

    // ── Build path ──────────────────────────────────────────────────────────
    final path = Path()..moveTo(topLeft.dx, topLeft.dy);

    final topMid   = Offset((topLeft.dx   + topRight.dx)    / 2,       (topLeft.dy    + topRight.dy)    / 2 - vBow);
    final rightMid = Offset((topRight.dx  + bottomRight.dx) / 2 + hBow, (topRight.dy  + bottomRight.dy) / 2);
    final botMid   = Offset((bottomRight.dx + bottomLeft.dx) / 2,       (bottomRight.dy + bottomLeft.dy) / 2 + vBow);
    final leftMid  = Offset((bottomLeft.dx + topLeft.dx)    / 2 - hBow, (bottomLeft.dy + topLeft.dy)    / 2);

    path.quadraticBezierTo(topMid.dx,   topMid.dy,   topRight.dx,    topRight.dy);
    path.quadraticBezierTo(rightMid.dx, rightMid.dy, bottomRight.dx, bottomRight.dy);
    path.quadraticBezierTo(botMid.dx,   botMid.dy,   bottomLeft.dx,  bottomLeft.dy);
    path.quadraticBezierTo(leftMid.dx,  leftMid.dy,  topLeft.dx,     topLeft.dy);
    path.close();

    // Clip so arc bows cannot bleed outside the grey reference frame.
    canvas.save();
    canvas.clipRect(defaultRect);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrapezoidPainter old) =>
      old.vKeystone != vKeystone ||
      old.hKeystone != hKeystone ||
      old.vArc != vArc ||
      old.hArc != hArc ||
      old.vBalance != vBalance ||
      old.hBalance != hBalance ||
      old.outline != outline ||
      old.fill != fill ||
      old.defaultColor != defaultColor;
}


// ─── Corner Correction Canvas ──────────────────────────────────────────────
class _CornerCorrectionCanvas extends StatefulWidget {
  final _CornerState state;
  final VoidCallback onCornerChanged;
  // Commands list is paired (param_key, value) for atomic per-drag commit.
  final Future<void> Function(List<(String, int)>) onCornerCommit;

  const _CornerCorrectionCanvas({
    super.key,
    required this.state,
    required this.onCornerChanged,
    required this.onCornerCommit,
  });

  @override
  State<_CornerCorrectionCanvas> createState() =>
      _CornerCorrectionCanvasState();
}

class _CornerCorrectionCanvasState extends State<_CornerCorrectionCanvas> {
  // Canvas dimensions and frame layout.
  // Frame (320×200) represents the full 1920×1200 projector canvas at scale 6.0.
  static const double _w = 480;
  static const double _h = 300;
  // Default frame corners — the un-warped rectangle, centered with 80/50px margins.
  static const Map<_Corner, Offset> _defaults = {
    _Corner.ul: Offset(80, 50),
    _Corner.ur: Offset(400, 50),
    _Corner.ll: Offset(80, 250),
    _Corner.lr: Offset(400, 250),
  };

  // 1 canvas pixel = 6 projector pixels (1920/320 = 1200/200 = 6.0).
  // Protocol range ±480 H / ±300 V maps to ±80 / ±50 canvas pixels.
  static const double _scale = 6.0;

  // Asymmetrical hardware limits (protocol values ÷ 6 = canvas pixels):
  // H: outward 384 (64px), inward 480 (80px). V: outward 240 (40px), inward 300 (50px).
  static const Map<_Corner, Rect> _bounds = {
    // Left default X:80. Outward -64px → 16. Inward +80px → 160.
    // Top default Y:50.  Outward -40px → 10. Inward +50px → 100.
    _Corner.ul: Rect.fromLTRB(16, 10, 160, 100),
    // Right default X:400. Inward -80px → 320. Outward +64px → 464.
    _Corner.ur: Rect.fromLTRB(320, 10, 464, 100),
    // Bottom default Y:250. Inward -50px → 200. Outward +40px → 290.
    _Corner.ll: Rect.fromLTRB(16, 200, 160, 290),
    _Corner.lr: Rect.fromLTRB(320, 200, 464, 290),
  };

  final Set<_Corner> _selected = {};
  final Map<_Corner, Offset> _dragStartPositions = {};
  Offset? _dragStartGlobal;

  // Tracks how the canvas is scaled relative to its logical _w×_h size.
  // Used to compensate global pointer deltas when the canvas is rendered smaller.
  double _renderScale = 1.0;

  // Manual double-tap tracking — avoids GestureDetector onDoubleTap which
  // delays onTap by kDoubleTapTimeout on every single tap.
  _Corner? _lastTappedCorner;
  DateTime? _lastTapTime;

  final FocusNode _focusNode = FocusNode();
  Timer? _keyHoldTimer;  // fires after hold threshold to begin continuous movement
  Timer? _keyTimer;      // drives continuous movement once hold threshold is reached
  LogicalKeyboardKey? _heldKey;

  // Short tap → 1 step only. Hold past this delay → continuous movement.
  static const _keyHoldDelay = Duration(milliseconds: 400);
  // Continuous movement rate — intentionally slow for fine control.
  static const _keyRepeatInterval = Duration(milliseconds: 40);

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  };

  static Offset _keyDelta(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowLeft  => const Offset(-1 / _scale, 0),
    LogicalKeyboardKey.arrowRight => const Offset(1 / _scale, 0),
    LogicalKeyboardKey.arrowUp    => const Offset(0, -1 / _scale),
    LogicalKeyboardKey.arrowDown  => const Offset(0, 1 / _scale),
    _ => Offset.zero,
  };

  @override
  void dispose() {
    _keyHoldTimer?.cancel();
    _keyTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void clearSelection() => setState(() => _selected.clear());

  // ─── Arrow-key movement ───────────────────────────────────────────────────
  void _applyStep(Offset delta) {
    if (!mounted || _selected.isEmpty) return;
    for (final c in _selected) {
      _applyCornerPosition(c, _positionOf(c) + delta);
    }
    setState(() {});
  }

  void _startKeyMovement(LogicalKeyboardKey key) {
    if (_heldKey == key) return;
    _keyHoldTimer?.cancel();
    _keyTimer?.cancel();
    _heldKey = key;
    final delta = _keyDelta(key);

    // Immediate single step on first press.
    _applyStep(delta);

    // After hold delay, begin slow continuous movement.
    _keyHoldTimer = Timer(_keyHoldDelay, () {
      _keyTimer = Timer.periodic(_keyRepeatInterval, (_) => _applyStep(delta));
    });
  }

  Future<void> _stopKeyMovement() async {
    _keyHoldTimer?.cancel();
    _keyHoldTimer = null;
    _keyTimer?.cancel();
    _keyTimer = null;
    _heldKey = null;
    final commands = <(String, int)>[];
    for (final c in _selected) {
      commands.addAll(_commandsFor(c));
    }
    await widget.onCornerCommit(commands);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_arrowKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (_selected.isEmpty) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _startKeyMovement(event.logicalKey);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _stopKeyMovement();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  // ─── Param ↔ canvas conversions ──────────────────────────────────────────
  Offset _positionOf(_Corner c) {
    final s = widget.state;
    final d = _defaults[c]!;
    return switch (c) {
      _Corner.ul => Offset(d.dx + s.gmfi6 / _scale, d.dy + s.gmfi1 / _scale),
      _Corner.ur => Offset(d.dx + s.gmfi7 / _scale, d.dy + s.gmfi2 / _scale),
      _Corner.ll => Offset(d.dx + s.gmfi8 / _scale, d.dy + s.gmfi3 / _scale),
      _Corner.lr => Offset(d.dx + s.gmfi9 / _scale, d.dy + s.gmfi4 / _scale),
    };
  }

  void _applyCornerPosition(_Corner which, Offset position) {
    final rect = _bounds[which]!;
    final defaultPos = _defaults[which]!;
    final clamped = Offset(
      position.dx.clamp(rect.left, rect.right),
      position.dy.clamp(rect.top, rect.bottom),
    );
    final hValue = ((clamped.dx - defaultPos.dx) * _scale).round();
    final vValue = ((clamped.dy - defaultPos.dy) * _scale).round();

    switch (which) {
      case _Corner.ul:
        widget.state.gmfi6 = hValue.clamp(-384, 480);
        widget.state.gmfi1 = vValue.clamp(-240, 300);
        break;
      case _Corner.ur:
        widget.state.gmfi7 = hValue.clamp(-480, 384);
        widget.state.gmfi2 = vValue.clamp(-240, 300);
        break;
      case _Corner.ll:
        widget.state.gmfi8 = hValue.clamp(-384, 480);
        widget.state.gmfi3 = vValue.clamp(-300, 240);
        break;
      case _Corner.lr:
        widget.state.gmfi9 = hValue.clamp(-480, 384);
        widget.state.gmfi4 = vValue.clamp(-300, 240);
        break;
    }
    widget.onCornerChanged();
  }

  List<(String, int)> _commandsFor(_Corner which) {
    final s = widget.state;
    return switch (which) {
      _Corner.ul => [('GMFI6', s.gmfi6), ('GMFI1', s.gmfi1)],
      _Corner.ur => [('GMFI7', s.gmfi7), ('GMFI2', s.gmfi2)],
      _Corner.ll => [('GMFI8', s.gmfi8), ('GMFI3', s.gmfi3)],
      _Corner.lr => [('GMFI9', s.gmfi9), ('GMFI4', s.gmfi4)],
    };
  }

  bool get _multiSelectActive {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  void _onHandleTap(_Corner which) {
    final now = DateTime.now();
    final isDoubleTap = _lastTappedCorner == which &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= kDoubleTapTimeout;
    _lastTappedCorner = which;
    _lastTapTime = now;

    if (isDoubleTap) {
      _onHandleDoubleTap(which);
      return;
    }

    _focusNode.requestFocus();
    setState(() {
      if (_multiSelectActive) {
        if (!_selected.add(which)) _selected.remove(which);
      } else {
        _selected
          ..clear()
          ..add(which);
      }
    });
  }

  Future<void> _onHandleDoubleTap(_Corner which) async {
    switch (which) {
      case _Corner.ul:
        widget.state.gmfi6 = 0;
        widget.state.gmfi1 = 0;
      case _Corner.ur:
        widget.state.gmfi7 = 0;
        widget.state.gmfi2 = 0;
      case _Corner.ll:
        widget.state.gmfi8 = 0;
        widget.state.gmfi3 = 0;
      case _Corner.lr:
        widget.state.gmfi9 = 0;
        widget.state.gmfi4 = 0;
    }
    widget.onCornerChanged();
    await widget.onCornerCommit(_commandsFor(which));
  }

  void _onHandlePanStart(_Corner which, DragStartDetails details) {
    _focusNode.requestFocus();
    if (!_selected.contains(which)) {
      setState(() {
        if (!_multiSelectActive) _selected.clear();
        _selected.add(which);
      });
    }
    _dragStartPositions
      ..clear()
      ..addAll({for (final c in _selected) c: _positionOf(c)});
    _dragStartGlobal = details.globalPosition;
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    if (_dragStartGlobal == null) return;
    // Divide by _renderScale to convert screen-space delta to canvas-space delta
    // when the canvas is displayed smaller than its logical _w×_h size.
    final totalDelta = (details.globalPosition - _dragStartGlobal!) / _renderScale;
    for (final c in _selected) {
      final start = _dragStartPositions[c];
      if (start == null) continue;
      _applyCornerPosition(c, start + totalDelta);
    }
  }

  Future<void> _onHandlePanEnd() async {
    final commands = <(String, int)>[];
    for (final c in _selected) {
      commands.addAll(_commandsFor(c));
    }
    await widget.onCornerCommit(commands);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compute the uniform scale that fits _w×_h into the available space.
          final scaleX = constraints.maxWidth.isFinite
              ? (constraints.maxWidth / _w).clamp(0.0, 1.0)
              : 1.0;
          final scaleY = constraints.maxHeight.isFinite
              ? (constraints.maxHeight / _h).clamp(0.0, 1.0)
              : 1.0;
          _renderScale = scaleX < scaleY ? scaleX : scaleY;

          // FittedBox scales the logical canvas to the rendered size while
          // preserving aspect ratio. GestureDetector sits inside the logical
          // coordinate system so handle positions need no adjustment.
          return Center(
            child: SizedBox(
              width: _w * _renderScale,
              height: _h * _renderScale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _w,
                  height: _h,
                  child: GestureDetector(
                    // Background tap clears selection; opaque so empty-space taps register.
                    // Inner handle GestureDetectors win the arena over this outer one,
                    // so handle taps don't trigger this clear.
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected.clear()),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CornerCorrectionPainter(
                                ul: _positionOf(_Corner.ul),
                                ur: _positionOf(_Corner.ur),
                                ll: _positionOf(_Corner.ll),
                                lr: _positionOf(_Corner.lr),
                                outline: theme.colorScheme.primary,
                                fill: theme.colorScheme.primary.withValues(alpha: 0.10),
                                defaultColor: theme.dividerColor,
                              ),
                            ),
                          ),
                        ),
                        for (final c in _Corner.values) _handle(c, _positionOf(c)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handle(_Corner which, Offset pos) {
    const radius = 10.0;
    final theme = Theme.of(context);
    final isSelected = _selected.contains(which);
    return Positioned(
      left: pos.dx - radius,
      top: pos.dy - radius,
      child: GestureDetector(
        onTap: () => _onHandleTap(which),
        onPanStart: (details) => _onHandlePanStart(which, details),
        onPanUpdate: (details) => _onHandlePanUpdate(details),
        onPanEnd: (_) => _onHandlePanEnd(),
        child: MouseRegion(
          cursor: Platform.isMacOS ? SystemMouseCursors.grab : SystemMouseCursors.move,
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: isSelected ? 6 : 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Corner { ul, ur, ll, lr }

class _CornerCorrectionPainter extends CustomPainter {
  final Offset ul, ur, ll, lr;
  final Color outline, fill, defaultColor;

  _CornerCorrectionPainter({
    required this.ul,
    required this.ur,
    required this.ll,
    required this.lr,
    required this.outline,
    required this.fill,
    required this.defaultColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Default frame outline (faint reference rectangle).
    final defaultPaint = Paint()
      ..color = defaultColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      const Rect.fromLTRB(80, 50, 400, 250),
      defaultPaint,
    );

    // Warped quadrilateral: fill + outline.
    final path = Path()
      ..moveTo(ul.dx, ul.dy)
      ..lineTo(ur.dx, ur.dy)
      ..lineTo(lr.dx, lr.dy)
      ..lineTo(ll.dx, ll.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 3x3 reference grid inside the warped quad.
    final gridPaint = Paint()
      ..color = outline.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      canvas.drawLine(Offset.lerp(ul, ur, t)!, Offset.lerp(ll, lr, t)!, gridPaint);
      canvas.drawLine(Offset.lerp(ul, ll, t)!, Offset.lerp(ur, lr, t)!, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerCorrectionPainter old) =>
      old.ul != ul || old.ur != ur || old.ll != ll || old.lr != lr ||
      old.outline != outline || old.fill != fill || old.defaultColor != defaultColor;
}
