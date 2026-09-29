import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/geometry_values.dart';
import '../../domain/projector_node.dart';
import '../providers/protocol_service_provider.dart';
import 'command_failure_notice.dart';
import 'common/dialog_split_layout.dart';
import 'common/labeled_slider_row.dart';
import 'common/projector_settings_client.dart';
import 'custom_tooltip.dart';
import 'dialog_title_bar.dart';
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
  int gmki4 = 0; // V balance
  int gmki7 = 0; // H balance
  double gmks8 = 0.0; // V keystone
  double gmks9 = 0.0; // H keystone
}

class _CurvedState {
  double gmcs0 = 1.5; // throw ratio
  int gmci2 = 0; // V balance
  int gmci3 = 0; // V arc
  int gmci6 = 0; // H balance
  int gmci7 = 0; // H arc
  double gmcs8 = 0.0; // V keystone
  double gmcs9 = 0.0; // H keystone
  bool gmcia = false; // maintain aspect ratio
}

// ─── Dialog ─────────────────────────────────────────────────────────────────
class GeometryCorrectionDialog extends ConsumerStatefulWidget {
  final ProjectorNode node;

  const GeometryCorrectionDialog({super.key, required this.node});

  @override
  ConsumerState<GeometryCorrectionDialog> createState() =>
      _GeometryCorrectionDialogState();
}

class _GeometryCorrectionDialogState
    extends ConsumerState<GeometryCorrectionDialog> {
  late final _client = ProjectorSettingsClient(
    service: ref.read(protocolServiceProvider),
    node: widget.node,
    onFailure: (cmd) {
      if (mounted) notifyCommandFailure(context, cmd);
    },
  );

  bool _loading = true;
  bool _modeLoading = false;
  _GeometryMode _mode = _GeometryMode.off;
  final Set<_GeometryMode> _loadedModes = {};

  // Geometry correction modes require Quad Pixel Drive ON on models that
  // have it — the projector's own menu refuses to enter Keystone/Curved/
  // Corner while it's OFF. QVX:QPDI1 can't be read reliably to detect this
  // (it only answers while mode is Off, returning ER401 the instant any mode
  // is active, regardless of model) so capability is determined once from
  // the model name (QID) instead of a live register read.
  bool _extendedCornerLimits = false; // Tier A only
  bool _autoEnableQuadPixelDrive = false; // Tier A + Tier B

  final _corner = _CornerState();
  final _keystone = _KeystoneState();
  final _curved = _CurvedState();

  final _cornerCanvasKey = GlobalKey<_CornerCorrectionCanvasState>();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // ─── Loading ─────────────────────────────────────────────────────────────
  Future<void> _loadInitial() async {
    final (modeRaw, model) = await (
      _client.readValue('GMMI0'),
      _client.query('QID'),
    ).wait;
    if (!mounted) return;

    if (modeRaw != null) _mode = _GeometryMode.fromProtocol(modeRaw);

    final tier = quadPixelTierFor(model ?? '');
    _extendedCornerLimits = tier == QuadPixelTier.a;
    _autoEnableQuadPixelDrive = tier != QuadPixelTier.none;

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
      'GMFI1',
      'GMFI2',
      'GMFI3',
      'GMFI4',
      'GMFI6',
      'GMFI7',
      'GMFI8',
      'GMFI9',
      'GMFI5',
      'GMFIA',
      'GMFIB',
      'GMFIC',
      'GMFID',
      'GMFIE',
      'GMFIF',
    ];
    // A 15-wide burst stalls ~5% of the queries ~1s on a flagship; batches
    // of 8 keep the load well under 200ms.
    final results = await _client.queryAll([for (final k in keys) 'QVX:$k']);
    if (!mounted) return;

    int parseAt(int i, String key) => parseKeyedInt(results[i], key) ?? 0;

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
    final (gmks0, gmki4, gmki7, gmks8, gmks9) = await (
      _client.readDouble('GMKS0'),
      _client.readInt('GMKI4'),
      _client.readInt('GMKI7'),
      _client.readDouble('GMKS8'),
      _client.readDouble('GMKS9'),
    ).wait;
    if (!mounted) return;

    _keystone
      ..gmks0 = gmks0 ?? 1.5
      ..gmki4 = gmki4 ?? 0
      ..gmki7 = gmki7 ?? 0
      ..gmks8 = gmks8 ?? 0.0
      ..gmks9 = gmks9 ?? 0.0;
  }

  Future<void> _loadCurved() async {
    final (gmcs0, gmci2, gmci3, gmci6, gmci7, gmcs8, gmcs9, gmcia) = await (
      _client.readDouble('GMCS0'),
      _client.readInt('GMCI2'),
      _client.readInt('GMCI3'),
      _client.readInt('GMCI6'),
      _client.readInt('GMCI7'),
      _client.readDouble('GMCS8'),
      _client.readDouble('GMCS9'),
      _client.readInt('GMCIA'),
    ).wait;
    if (!mounted) return;

    _curved
      ..gmcs0 = gmcs0 ?? 1.5
      ..gmci2 = gmci2 ?? 0
      ..gmci3 = gmci3 ?? 0
      ..gmci6 = gmci6 ?? 0
      ..gmci7 = gmci7 ?? 0
      ..gmcs8 = gmcs8 ?? 0.0
      ..gmcs9 = gmcs9 ?? 0.0
      ..gmcia = (gmcia ?? 0) == 1;
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
            DialogTitleBar(
              title: 'Geometry Correction - ${widget.node.ipAddress}',
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              // Mode switch — a SegmentedButton, like the other mode/kind
              // toggles in the app (e.g. Add Projector's Single/Range).
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: SegmentedButton<_GeometryMode>(
                  segments: _GeometryMode.values
                      .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                      .toList(),
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) async {
                    final m = set.first;
                    if (m == _mode) return;
                    final wasOff = _mode == _GeometryMode.off;
                    final needsLoad =
                        m != _GeometryMode.off && !_loadedModes.contains(m);
                    // Switch the selection and panel instantly — the network
                    // round trips below (QPDI1 enable, mode command, and a
                    // first-time parameter load are each a separate TCP
                    // connection to the projector, see _ensureModeLoaded) run
                    // in the background under the mode panel's own spinner
                    // instead of freezing the SegmentedButton until they land.
                    setState(() {
                      _mode = m;
                      if (needsLoad) _modeLoading = true;
                    });
                    // Quad-pixel-capable models refuse to enter any geometry
                    // mode while Quad Pixel Drive is off — enable it first so
                    // the mode switch itself doesn't error out. VXX:QPDI1=ON
                    // is idempotent, so no need to track current state.
                    if (_autoEnableQuadPixelDrive && wasOff) {
                      await _client.writeBool('QPDI1', true);
                    }
                    await _client.writeRaw('VXX:GMMI0=${m.protocolValue}');
                    await _ensureModeLoaded(m);
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
        ..gmfi1 = 0
        ..gmfi2 = 0
        ..gmfi3 = 0
        ..gmfi4 = 0
        ..gmfi6 = 0
        ..gmfi7 = 0
        ..gmfi8 = 0
        ..gmfi9 = 0;
    });
    for (final key in [
      'GMFI1',
      'GMFI2',
      'GMFI3',
      'GMFI4',
      'GMFI6',
      'GMFI7',
      'GMFI8',
      'GMFI9',
    ]) {
      await _client.writeInt(key, 0);
    }
  }

  Widget _buildCornerBody() {
    return DialogSplitLayout(
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
            child: CustomTooltip(
              message: 'Reset all corners',
              child: IconButton(
                icon: const Icon(Icons.restart_alt),
                iconSize: 20,
                onPressed: _resetAllCorners,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _CornerCorrectionCanvas(
                key: _cornerCanvasKey,
                state: _corner,
                extendedCornerLimits: _extendedCornerLimits,
                onCornerCommit: (List<(String, int)> commands) async {
                  for (final (key, value) in commands) {
                    await _client.writeInt(key, value);
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
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
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
                _client.writeInt('GMFIF', v.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LabeledSliderRow(
          snap: false,
          label: 'Linearity V',
          value: _corner.gmfi5.toDouble(),
          min: -127,
          max: 127,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfi5 = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFI5', v.round())
              : null,
        ),
        LabeledSliderRow(
          snap: false,
          label: 'Linearity H',
          value: _corner.gmfia.toDouble(),
          min: -127,
          max: 127,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfia = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFIA', v.round())
              : null,
        ),
        LabeledSliderRow(
          snap: false,
          label: 'Pincushion Upper',
          value: _corner.gmfib.toDouble(),
          min: -100,
          max: 100,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfib = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFIB', v.round())
              : null,
        ),
        LabeledSliderRow(
          snap: false,
          label: 'Pincushion Lower',
          value: _corner.gmfic.toDouble(),
          min: -100,
          max: 100,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfic = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFIC', v.round())
              : null,
        ),
        LabeledSliderRow(
          snap: false,
          label: 'Pincushion Left',
          value: _corner.gmfid.toDouble(),
          min: -100,
          max: 100,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfid = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFID', v.round())
              : null,
        ),
        LabeledSliderRow(
          snap: false,
          label: 'Pincushion Right',
          value: _corner.gmfie.toDouble(),
          min: -100,
          max: 100,
          onChanged: manual
              ? (v) => setState(() => _corner.gmfie = v.round())
              : null,
          onChangeEnd: manual
              ? (v) => _client.writeInt('GMFIE', v.round())
              : null,
        ),
      ],
    );
  }

  // ─── Keystone ────────────────────────────────────────────────────────────
  Widget _buildKeystoneBody() {
    return DialogSplitLayout(
      left: _buildPreviewUnavailable(),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSliderRow(
            label: 'Vertical Keystone',
            value: _keystone.gmks8,
            min: -40,
            max: 40,
            step: 0.2,
            onChanged: (v) => setState(
              () => _keystone.gmks8 = double.parse(v.toStringAsFixed(1)),
            ),
            onChangeEnd: (v) =>
                _client.writeDeg('GMKS8', double.parse(v.toStringAsFixed(1))),
          ),
          LabeledSliderRow(
            label: 'Horizontal Keystone',
            value: _keystone.gmks9,
            min: -15,
            max: 15,
            step: 0.2,
            onChanged: (v) => setState(
              () => _keystone.gmks9 = double.parse(v.toStringAsFixed(1)),
            ),
            onChangeEnd: (v) =>
                _client.writeDeg('GMKS9', double.parse(v.toStringAsFixed(1))),
          ),
          LabeledSliderRow(
            label: 'Vertical Balance',
            value: _keystone.gmki4.toDouble(),
            min: -60,
            max: 60,
            onChanged: (v) => setState(() => _keystone.gmki4 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMKI4', v.round()),
          ),
          LabeledSliderRow(
            label: 'Horizontal Balance',
            value: _keystone.gmki7.toDouble(),
            min: -30,
            max: 30,
            onChanged: (v) => setState(() => _keystone.gmki7 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMKI7', v.round()),
          ),
          _throwRatioField(
            value: _keystone.gmks0,
            onCommit: (v) {
              setState(() => _keystone.gmks0 = v);
              _client.writeThrow('GMKS0', v);
            },
          ),
        ],
      ),
    );
  }

  // ─── Curved ──────────────────────────────────────────────────────────────
  Widget _buildCurvedBody() {
    return DialogSplitLayout(
      left: _buildPreviewUnavailable(),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSliderRow(
            label: 'Vertical Arc',
            value: _curved.gmci3.toDouble(),
            min: -40,
            max: 40,
            onChanged: (v) => setState(() => _curved.gmci3 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMCI3', v.round()),
          ),
          LabeledSliderRow(
            label: 'Horizontal Arc',
            value: _curved.gmci7.toDouble(),
            min: -40,
            max: 40,
            onChanged: (v) => setState(() => _curved.gmci7 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMCI7', v.round()),
          ),
          LabeledSliderRow(
            label: 'Vertical Keystone',
            value: _curved.gmcs8,
            min: -40,
            max: 40,
            step: 0.2,
            onChanged: (v) => setState(
              () => _curved.gmcs8 = double.parse(v.toStringAsFixed(1)),
            ),
            onChangeEnd: (v) =>
                _client.writeDeg('GMCS8', double.parse(v.toStringAsFixed(1))),
          ),
          LabeledSliderRow(
            label: 'Horizontal Keystone',
            value: _curved.gmcs9,
            min: -15,
            max: 15,
            step: 0.2,
            onChanged: (v) => setState(
              () => _curved.gmcs9 = double.parse(v.toStringAsFixed(1)),
            ),
            onChangeEnd: (v) =>
                _client.writeDeg('GMCS9', double.parse(v.toStringAsFixed(1))),
          ),
          LabeledSliderRow(
            label: 'Vertical Balance',
            value: _curved.gmci2.toDouble(),
            min: -60,
            max: 60,
            onChanged: (v) => setState(() => _curved.gmci2 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMCI2', v.round()),
          ),
          LabeledSliderRow(
            label: 'Horizontal Balance',
            value: _curved.gmci6.toDouble(),
            min: -30,
            max: 30,
            onChanged: (v) => setState(() => _curved.gmci6 = v.round()),
            onChangeEnd: (v) => _client.writeInt('GMCI6', v.round()),
          ),
          _throwRatioField(
            value: _curved.gmcs0,
            onCommit: (v) {
              setState(() => _curved.gmcs0 = v);
              _client.writeThrow('GMCS0', v);
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Maintain Aspect Ratio',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: _curved.gmcia,
                onChanged: (v) {
                  setState(() => _curved.gmcia = v);
                  _client.writeBool('GMCIA', v);
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
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Preview not available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.45),
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
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
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

  Widget _throwRatioField({
    required double value,
    required ValueChanged<double> onCommit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lens Throw Ratio',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
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
  final int vArc; // -40..40
  final int hArc; // -40..40
  final int vBalance; // -60..60
  final int hBalance; // -30..30

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
    final double vCompY = vK * 40.0;

    final double hPinchY = hK * 40.0;
    final double hCompX = hK * 60.0;

    double tlX = defaultRect.left;
    double tlY = defaultRect.top;
    double trX = defaultRect.right;
    double trY = defaultRect.top;
    double blX = defaultRect.left;
    double blY = defaultRect.bottom;
    double brX = defaultRect.right;
    double brY = defaultRect.bottom;

    // 1. Base Vertical Keystone
    if (vKeystone > 0) {
      tlX += vPinchX;
      trX -= vPinchX; // Top pinches inward
      blY -= vCompY;
      brY -= vCompY; // Bottom compensates UP
    } else if (vKeystone < 0) {
      blX += vPinchX;
      brX -= vPinchX; // Bottom pinches inward
      tlY += vCompY;
      trY += vCompY; // Top compensates DOWN
    }

    // 2. Horizontal Keystone with Matrix Overlap Sliding

    // [!] TWEAK THIS VALUE (0.35 - 0.40) TO ADJUST THE MAXIMUM SLIDE LIMIT
    final double maxSlideY = defaultRect.height * 0.46;

    if (hKeystone > 0) {
      tlY += hPinchY;
      blY -= hPinchY; // Left pinches inward

      if (vKeystone > 0) {
        // vKeystone moved bottom edge UP. LEFT edge slides DOWN to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(
          slideY,
          maxSlideY,
        ); // Apply hard limit to prevent triangle folding
        tlY += slideY;
        blY += slideY;

        double remRatio = hPinchY == 0
            ? 0.0
            : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        trX -= hCompX * remRatio;
        brX -= hCompX * remRatio;
      } else if (vKeystone < 0) {
        // vKeystone moved top edge DOWN. LEFT edge slides UP to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(
          slideY,
          maxSlideY,
        ); // Apply hard limit to prevent triangle folding
        tlY -= slideY;
        blY -= slideY;

        double remRatio = hPinchY == 0
            ? 0.0
            : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        trX -= hCompX * remRatio;
        brX -= hCompX * remRatio;
      } else {
        trX -= hCompX;
        brX -= hCompX;
      }
    } else if (hKeystone < 0) {
      trY += hPinchY;
      brY -= hPinchY; // Right pinches inward

      if (vKeystone > 0) {
        // vKeystone moved bottom edge UP. RIGHT edge slides DOWN to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(
          slideY,
          maxSlideY,
        ); // Apply hard limit to prevent triangle folding
        trY += slideY;
        brY += slideY;

        double remRatio = hPinchY == 0
            ? 0.0
            : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        tlX += hCompX * remRatio;
        blX += hCompX * remRatio;
      } else if (vKeystone < 0) {
        // vKeystone moved top edge DOWN. RIGHT edge slides UP to absorb hPinch.
        double slideY = min(vCompY + hPinchY, 2 * hPinchY);
        slideY = min(
          slideY,
          maxSlideY,
        ); // Apply hard limit to prevent triangle folding
        trY -= slideY;
        brY -= slideY;

        double remRatio = hPinchY == 0
            ? 0.0
            : ((hPinchY - vCompY) / hPinchY).clamp(0.0, 1.0);
        tlX += hCompX * remRatio;
        blX += hCompX * remRatio;
      } else {
        tlX += hCompX;
        blX += hCompX;
      }
    }

    // ── Balance adjustments ─────────────────────────────────────────────────
    // Applied after keystone; clamped to defaultRect so nothing escapes.
    final vBalDelta = (vBalance / 60.0) * 20.0;
    final hBalDelta = (hBalance / 30.0) * 12.0;

    if (vKeystone.abs() > 0.01) {
      if (vKeystone > 0) {
        // vBalance shifts bottom (unpinched) edge vertically — inverted.
        blY -= vBalDelta;
        brY -= vBalDelta;
        // hBalance shifts top (pinched) corners horizontally (positive = left).
        tlX -= hBalDelta;
        trX -= hBalDelta;
      } else {
        // vBalance shifts top (unpinched) edge — inverted.
        tlY -= vBalDelta;
        trY -= vBalDelta;
        blX -= hBalDelta;
        brX -= hBalDelta;
      }
    }

    if (hKeystone.abs() > 0.01) {
      if (hKeystone > 0) {
        // hBalance shifts right (unpinched) edge — inverted.
        trX += hBalDelta;
        brX += hBalDelta;
        // vBalance shifts left (pinched) corners vertically (positive = down).
        tlY += vBalDelta;
        blY += vBalDelta;
      } else {
        // hBalance shifts left (unpinched) edge — inverted.
        tlX += hBalDelta;
        blX += hBalDelta;
        trY += vBalDelta;
        brY += vBalDelta;
      }
    }

    // Clamp — the physical matrix is the hard limit.
    double cx(double x) => x.clamp(defaultRect.left, defaultRect.right);
    double cy(double y) => y.clamp(defaultRect.top, defaultRect.bottom);

    final topLeft = Offset(cx(tlX), cy(tlY));
    final topRight = Offset(cx(trX), cy(trY));
    final bottomLeft = Offset(cx(blX), cy(blY));
    final bottomRight = Offset(cx(brX), cy(brY));

    // ── Arc bows (curved mode only; both 0 in keystone mode) ───────────────
    final vBow = (vArc / 40.0) * 30.0;
    final hBow = (hArc / 40.0) * 30.0;

    // ── Build path ──────────────────────────────────────────────────────────
    final path = Path()..moveTo(topLeft.dx, topLeft.dy);

    final topMid = Offset(
      (topLeft.dx + topRight.dx) / 2,
      (topLeft.dy + topRight.dy) / 2 - vBow,
    );
    final rightMid = Offset(
      (topRight.dx + bottomRight.dx) / 2 + hBow,
      (topRight.dy + bottomRight.dy) / 2,
    );
    final botMid = Offset(
      (bottomRight.dx + bottomLeft.dx) / 2,
      (bottomRight.dy + bottomLeft.dy) / 2 + vBow,
    );
    final leftMid = Offset(
      (bottomLeft.dx + topLeft.dx) / 2 - hBow,
      (bottomLeft.dy + topLeft.dy) / 2,
    );

    path.quadraticBezierTo(topMid.dx, topMid.dy, topRight.dx, topRight.dy);
    path.quadraticBezierTo(
      rightMid.dx,
      rightMid.dy,
      bottomRight.dx,
      bottomRight.dy,
    );
    path.quadraticBezierTo(botMid.dx, botMid.dy, bottomLeft.dx, bottomLeft.dy);
    path.quadraticBezierTo(leftMid.dx, leftMid.dy, topLeft.dx, topLeft.dy);
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
  // Tier A models only — widens the inward-facing movement limits for every
  // corner (3840x2400 virtual canvas instead of the native panel's canvas).
  // Outward limits never change.
  final bool extendedCornerLimits;
  // Commands list is paired (param_key, value) for atomic per-drag commit.
  final Future<void> Function(List<(String, int)>) onCornerCommit;

  const _CornerCorrectionCanvas({
    super.key,
    required this.state,
    required this.extendedCornerLimits,
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

  // Protocol range ±480 H / ±300 V maps to ±80 / ±50 canvas pixels at
  // cornerCanvasScale. This is the VISUAL scale and never changes with Quad
  // Pixel Drive — QPD doubles the inward protocol-unit ceiling (480→960,
  // 300→600) because it doubles the addressing resolution, not because the
  // physical/visual inward reach gets any bigger. See _toCanvas/_toRaw for
  // the doubled-precision inward conversion that keeps drag behavior visually
  // identical across models.
  //
  // Fixed canvas-pixel bounds, same on every model regardless of Quad Pixel
  // Drive — visual reach doesn't change, only how many raw protocol units it
  // takes to express it.
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

  // Converts a raw protocol value to a canvas-pixel delta from the corner's
  // default position. On Quad Pixel Drive models, the inward direction uses
  // double the precision (scale 12 instead of 6) since QPD's wider inward
  // ceiling (e.g. 960 instead of 480) represents the SAME physical maximum
  // reach expressed in twice-as-fine units, not a bigger reach. Outward
  // always uses the base scale — that limit is a fixed lens/mechanical
  // constraint, unaffected by QPD.
  double _toCanvas(int raw, {required bool inwardIsPositive}) => cornerToCanvas(
    raw,
    inwardIsPositive: inwardIsPositive,
    extended: widget.extendedCornerLimits,
  );

  // Inverse of _toCanvas — canvas-pixel delta back to a raw protocol value.
  int _toRaw(double canvasDelta, {required bool inwardIsPositive}) =>
      cornerToRaw(
        canvasDelta,
        inwardIsPositive: inwardIsPositive,
        extended: widget.extendedCornerLimits,
      );

  // Absolute outward ceiling — union of all 4 corners' outward-facing edges.
  // Unlike _bounds, this never changes with Quad Pixel Drive, since outward
  // reach is fixed. Drawn on the canvas so dragging stops at a visible
  // frame instead of empty space.
  Rect get _outerLimitRect => Rect.fromLTRB(
    _bounds[_Corner.ul]!.left,
    _bounds[_Corner.ul]!.top,
    _bounds[_Corner.ur]!.right,
    _bounds[_Corner.ll]!.bottom,
  );

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
  Timer?
  _keyHoldTimer; // fires after hold threshold to begin continuous movement
  Timer? _keyTimer; // drives continuous movement once hold threshold is reached
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

  // Raw protocol-unit deltas (H, V) — always exactly 1 unit per key press.
  // Increasing H always moves a corner right on screen and increasing V
  // always moves it down, for every corner (raw/scale in _toCanvas is
  // monotonic with a positive scale regardless of inward/outward zone), so a
  // single pair of signed deltas works uniformly across all 4 corners —
  // unlike a canvas-space delta, this isn't affected by the doubled inward
  // scale on Quad Pixel Drive models.
  static (int, int) _keyRawDelta(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowLeft => (-1, 0),
    LogicalKeyboardKey.arrowRight => (1, 0),
    LogicalKeyboardKey.arrowUp => (0, -1),
    LogicalKeyboardKey.arrowDown => (0, 1),
    _ => (0, 0),
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
  void _applyRawStep(int dh, int dv) {
    if (!mounted || _selected.isEmpty || (dh == 0 && dv == 0)) return;
    final inwardH = cornerInwardH(extended: widget.extendedCornerLimits);
    final inwardV = cornerInwardV(extended: widget.extendedCornerLimits);
    for (final c in _selected) {
      switch (c) {
        case _Corner.ul:
          widget.state.gmfi6 = (widget.state.gmfi6 + dh).clamp(
            -cornerOutwardH,
            inwardH,
          );
          widget.state.gmfi1 = (widget.state.gmfi1 + dv).clamp(
            -cornerOutwardV,
            inwardV,
          );
          break;
        case _Corner.ur:
          widget.state.gmfi7 = (widget.state.gmfi7 + dh).clamp(
            -inwardH,
            cornerOutwardH,
          );
          widget.state.gmfi2 = (widget.state.gmfi2 + dv).clamp(
            -cornerOutwardV,
            inwardV,
          );
          break;
        case _Corner.ll:
          widget.state.gmfi8 = (widget.state.gmfi8 + dh).clamp(
            -cornerOutwardH,
            inwardH,
          );
          widget.state.gmfi3 = (widget.state.gmfi3 + dv).clamp(
            -inwardV,
            cornerOutwardV,
          );
          break;
        case _Corner.lr:
          widget.state.gmfi9 = (widget.state.gmfi9 + dh).clamp(
            -inwardH,
            cornerOutwardH,
          );
          widget.state.gmfi4 = (widget.state.gmfi4 + dv).clamp(
            -inwardV,
            cornerOutwardV,
          );
          break;
      }
    }
    setState(() {});
  }

  void _startKeyMovement(LogicalKeyboardKey key) {
    if (_heldKey == key) return;
    _keyHoldTimer?.cancel();
    _keyTimer?.cancel();
    _heldKey = key;
    final (dh, dv) = _keyRawDelta(key);

    // Immediate single step on first press.
    _applyRawStep(dh, dv);

    // After hold delay, begin slow continuous movement.
    _keyHoldTimer = Timer(_keyHoldDelay, () {
      _keyTimer = Timer.periodic(
        _keyRepeatInterval,
        (_) => _applyRawStep(dh, dv),
      );
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
      _Corner.ul => Offset(
        d.dx + _toCanvas(s.gmfi6, inwardIsPositive: true),
        d.dy + _toCanvas(s.gmfi1, inwardIsPositive: true),
      ),
      _Corner.ur => Offset(
        d.dx + _toCanvas(s.gmfi7, inwardIsPositive: false),
        d.dy + _toCanvas(s.gmfi2, inwardIsPositive: true),
      ),
      _Corner.ll => Offset(
        d.dx + _toCanvas(s.gmfi8, inwardIsPositive: true),
        d.dy + _toCanvas(s.gmfi3, inwardIsPositive: false),
      ),
      _Corner.lr => Offset(
        d.dx + _toCanvas(s.gmfi9, inwardIsPositive: false),
        d.dy + _toCanvas(s.gmfi4, inwardIsPositive: false),
      ),
    };
  }

  void _applyCornerPosition(_Corner which, Offset position) {
    final rect = _bounds[which]!;
    final defaultPos = _defaults[which]!;
    final clamped = Offset(
      position.dx.clamp(rect.left, rect.right),
      position.dy.clamp(rect.top, rect.bottom),
    );
    final dxCanvas = clamped.dx - defaultPos.dx;
    final dyCanvas = clamped.dy - defaultPos.dy;

    // Defensive safety clamp against the true protocol range, in case of
    // rounding at the boundary — the canvas-pixel clamp above already keeps
    // values in range under normal operation.
    final inwardH = cornerInwardH(extended: widget.extendedCornerLimits);
    final inwardV = cornerInwardV(extended: widget.extendedCornerLimits);

    switch (which) {
      case _Corner.ul:
        widget.state.gmfi6 = _toRaw(
          dxCanvas,
          inwardIsPositive: true,
        ).clamp(-cornerOutwardH, inwardH);
        widget.state.gmfi1 = _toRaw(
          dyCanvas,
          inwardIsPositive: true,
        ).clamp(-cornerOutwardV, inwardV);
        break;
      case _Corner.ur:
        widget.state.gmfi7 = _toRaw(
          dxCanvas,
          inwardIsPositive: false,
        ).clamp(-inwardH, cornerOutwardH);
        widget.state.gmfi2 = _toRaw(
          dyCanvas,
          inwardIsPositive: true,
        ).clamp(-cornerOutwardV, inwardV);
        break;
      case _Corner.ll:
        widget.state.gmfi8 = _toRaw(
          dxCanvas,
          inwardIsPositive: true,
        ).clamp(-cornerOutwardH, inwardH);
        widget.state.gmfi3 = _toRaw(
          dyCanvas,
          inwardIsPositive: false,
        ).clamp(-inwardV, cornerOutwardV);
        break;
      case _Corner.lr:
        widget.state.gmfi9 = _toRaw(
          dxCanvas,
          inwardIsPositive: false,
        ).clamp(-inwardH, cornerOutwardH);
        widget.state.gmfi4 = _toRaw(
          dyCanvas,
          inwardIsPositive: false,
        ).clamp(-inwardV, cornerOutwardV);
        break;
    }
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
    final isDoubleTap =
        _lastTappedCorner == which &&
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
    setState(() {
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
    });
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
    final totalDelta =
        (details.globalPosition - _dragStartGlobal!) / _renderScale;
    // Local setState only — repaints just this canvas instead of forcing the
    // whole dialog (tooltip, segmented button, 6 sliders) to rebuild on every
    // pointer-move frame of the drag.
    setState(() {
      for (final c in _selected) {
        final start = _dragStartPositions[c];
        if (start == null) continue;
        _applyCornerPosition(c, start + totalDelta);
      }
    });
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
                                outerLimit: _outerLimitRect,
                                linearityV: widget.state.gmfi5,
                                linearityH: widget.state.gmfia,
                                pincushionUpper: widget.state.gmfib,
                                pincushionLower: widget.state.gmfic,
                                pincushionLeft: widget.state.gmfid,
                                pincushionRight: widget.state.gmfie,
                                outline: theme.colorScheme.primary,
                                fill: theme.colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                                defaultColor: theme.dividerColor,
                              ),
                            ),
                          ),
                        ),
                        for (final c in _Corner.values)
                          _handle(c, _positionOf(c)),
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
          cursor: Platform.isMacOS
              ? SystemMouseCursors.grab
              : SystemMouseCursors.move,
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
  final Rect outerLimit;
  // Linearity V/H (GMFI5/GMFIA, ±127) and Pincushion Upper/Lower/Left/Right
  // (GMFIB–E, ±100) — see plan discussion: Linearity shifts where the single
  // cross line sits between opposite edges; Pincushion bows each edge with a
  // parabola (zero at its two corners, peak at its midpoint). Both are pure
  // preview math — the values themselves are already sent to the projector
  // via the sliders in _buildCornerSliders, this only affects the drawing.
  final int linearityV, linearityH;
  final int pincushionUpper, pincushionLower, pincushionLeft, pincushionRight;
  final Color outline, fill, defaultColor;

  _CornerCorrectionPainter({
    required this.ul,
    required this.ur,
    required this.ll,
    required this.lr,
    required this.outerLimit,
    required this.linearityV,
    required this.linearityH,
    required this.pincushionUpper,
    required this.pincushionLower,
    required this.pincushionLeft,
    required this.pincushionRight,
    required this.outline,
    required this.fill,
    required this.defaultColor,
  });

  // Fraction of the 0.5 default position the cross line can shift toward an
  // edge at full ±127 linearity — calibrated against VSS screenshots (the
  // cross moved roughly 12-15% of the frame at the slider extremes).
  static const double _crossAmplitude = 0.15;

  // Pincushion bow amplitude in canvas pixels at value=±100 — calibrated
  // against VSS screenshots (~12% of the default 320×200 frame per axis).
  static const double _pincushionAmplitudeV = 24.0;
  static const double _pincushionAmplitudeH = 38.0;

  static double _parabola(double u) => 4 * u * (1 - u);

  // Edge curves — each passes exactly through its two corner points (the
  // parabola is zero at u=0/1) and bows by its own Pincushion value in
  // between.
  //
  // Sign convention confirmed against the real projector (VSS's own preview
  // turned out to render some edges with the opposite sign, so that was not
  // trustworthy as a reference): positive Pincushion always bows that edge
  // INWARD, toward the rectangle's center; negative always bows it OUTWARD.
  // Same relative sense for all 4 edges, even though "inward" is a different
  // absolute direction per edge (down for Upper, up for Lower, right for
  // Left, left for Right).
  Offset _top(double u) => Offset.lerp(
    ul,
    ur,
    u,
  )!.translate(0, pincushionUpper / 100 * _pincushionAmplitudeV * _parabola(u));
  Offset _bottom(double u) => Offset.lerp(ll, lr, u)!.translate(
    0,
    -(pincushionLower / 100 * _pincushionAmplitudeV * _parabola(u)),
  );
  Offset _left(double v) => Offset.lerp(
    ul,
    ll,
    v,
  )!.translate(pincushionLeft / 100 * _pincushionAmplitudeH * _parabola(v), 0);
  Offset _right(double v) => Offset.lerp(ur, lr, v)!.translate(
    -(pincushionRight / 100 * _pincushionAmplitudeH * _parabola(v)),
    0,
  );

  // Bilinear Coons patch: blends the 4 (possibly bowed) boundary curves into
  // a smooth interior. Reduces to a plain bilinear lerp of the 4 corners when
  // all Pincushion values are 0, matching the mesh's old un-bowed behavior.
  Offset _coons(double u, double v) {
    final ruled = Offset(
      (1 - v) * _top(u).dx +
          v * _bottom(u).dx +
          (1 - u) * _left(v).dx +
          u * _right(v).dx,
      (1 - v) * _top(u).dy +
          v * _bottom(u).dy +
          (1 - u) * _left(v).dy +
          u * _right(v).dy,
    );
    final bilinear = Offset(
      (1 - u) * (1 - v) * ul.dx +
          u * (1 - v) * ur.dx +
          (1 - u) * v * ll.dx +
          u * v * lr.dx,
      (1 - u) * (1 - v) * ul.dy +
          u * (1 - v) * ur.dy +
          (1 - u) * v * ll.dy +
          u * v * lr.dy,
    );
    return ruled - bilinear;
  }

  static const int _edgeSegments = 24;

  Path _sampledPath(Offset Function(double t) point, int segments) {
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    _appendCurve(path, point, segments);
    return path;
  }

  // Appends lineTo segments only — no moveTo — so multiple curves chain into
  // a single continuous subpath. addPath() would insert each curve as its
  // own subpath instead (each with its own moveTo), which made close() draw
  // a stray straight line back to the last subpath's start instead of
  // closing the whole boundary.
  void _appendCurve(Path path, Offset Function(double t) point, int segments) {
    for (int i = 1; i <= segments; i++) {
      final p = point(i / segments);
      path.lineTo(p.dx, p.dy);
    }
  }

  // Dashed stroke around a rect — CustomPainter has no built-in dashed
  // stroke, and this frame needs to read as a hard limit, distinct from the
  // solid faint default-size reference rectangle.
  static void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    double dashWidth = 6,
    double dashSpace = 4,
  }) {
    void dashedLine(Offset start, Offset end) {
      final total = (end - start).distance;
      final direction = (end - start) / total;
      var drawn = 0.0;
      while (drawn < total) {
        final segEnd = (drawn + dashWidth).clamp(0.0, total);
        canvas.drawLine(
          start + direction * drawn,
          start + direction * segEnd,
          paint,
        );
        drawn += dashWidth + dashSpace;
      }
    }

    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Outer limit frame — the absolute ceiling any corner can be dragged to,
    // drawn first so the warped quad below is always visually in front of it.
    _drawDashedRect(
      canvas,
      outerLimit,
      Paint()
        ..color = defaultColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Default frame outline (faint reference rectangle).
    final defaultPaint = Paint()
      ..color = defaultColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTRB(80, 50, 400, 250), defaultPaint);

    // Warped boundary: 4 bowed edges (straight when their Pincushion value is
    // 0), fill + outline. Each edge curve passes exactly through its two
    // corners, so this still pins to ul/ur/ll/lr like the old straight quad.
    final boundary = Path()..moveTo(ul.dx, ul.dy);
    _appendCurve(boundary, _top, _edgeSegments);
    _appendCurve(boundary, _right, _edgeSegments);
    _appendCurve(boundary, (t) => _bottom(1 - t), _edgeSegments);
    _appendCurve(boundary, (t) => _left(1 - t), _edgeSegments);
    boundary.close();

    canvas.drawPath(boundary, Paint()..color = fill);
    canvas.drawPath(
      boundary,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Single cross through the middle (matches VSS's 2x2 grid), shifted off
    // center by Linearity and bowed by Pincushion via the Coons blend.
    final gridPaint = Paint()
      ..color = outline.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final tCross = (0.5 + linearityH / 127 * _crossAmplitude).clamp(0.0, 1.0);
    final sCross = (0.5 + linearityV / 127 * _crossAmplitude).clamp(0.0, 1.0);
    canvas.drawPath(
      _sampledPath((v) => _coons(tCross, v), _edgeSegments),
      gridPaint,
    );
    canvas.drawPath(
      _sampledPath((u) => _coons(u, sCross), _edgeSegments),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerCorrectionPainter old) =>
      old.ul != ul ||
      old.ur != ur ||
      old.ll != ll ||
      old.lr != lr ||
      old.outerLimit != outerLimit ||
      old.linearityV != linearityV ||
      old.linearityH != linearityH ||
      old.pincushionUpper != pincushionUpper ||
      old.pincushionLower != pincushionLower ||
      old.pincushionLeft != pincushionLeft ||
      old.pincushionRight != pincushionRight ||
      old.outline != outline ||
      old.fill != fill ||
      old.defaultColor != defaultColor;
}
