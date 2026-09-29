import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_node.dart';
import '../providers/protocol_service_provider.dart';
import 'command_failure_notice.dart';
import 'common/projector_settings_client.dart';
import 'dialog_title_bar.dart';

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

class BrightnessControlDialog extends ConsumerStatefulWidget {
  final ProjectorNode node;

  const BrightnessControlDialog({super.key, required this.node});

  @override
  ConsumerState<BrightnessControlDialog> createState() =>
      _BrightnessControlDialogState();
}

class _BrightnessControlDialogState
    extends ConsumerState<BrightnessControlDialog> {
  late final _client = ProjectorSettingsClient(
    service: ref.read(protocolServiceProvider),
    node: widget.node,
    onFailure: (cmd) {
      if (mounted) notifyCommandFailure(context, cmd);
    },
  );

  bool _loading = true;
  _OperatingMode _mode = _OperatingMode.normal;
  double _lightOutput = 100.0; // percentage 8–100
  double _maxLightOutput = 100.0; // percentage 8–100

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  // Protocol ↔ percentage conversion.
  // 80 = 8%, 1000 = 100% (linear).
  static double _toPercent(int v) => 8.0 + (v - 80) / 920 * 92;
  static int _toProtocol(double pct) => (80 + (pct - 8) / 92 * 920).round();

  Future<void> _loadValues() async {
    final (modeRaw, lopi2, lopi3) = await (
      _client.readValue('OPEI1'),
      _client.readInt('LOPI2'),
      _client.readInt('LOPI3'),
    ).wait;

    if (!mounted) return;

    if (modeRaw != null) _mode = _OperatingMode.fromProtocol(modeRaw);
    if (lopi2 != null) _lightOutput = _toPercent(lopi2).clamp(8.0, 100.0);
    if (lopi3 != null) _maxLightOutput = _toPercent(lopi3).clamp(8.0, 100.0);

    setState(() => _loading = false);
  }

  Future<void> _sendMode(_OperatingMode mode) =>
      _client.writeRaw('VXX:OPEI1=${mode.protocolValue}');

  Future<void> _sendLightOutput(double pct) =>
      _client.writeInt('LOPI2', _toProtocol(pct));

  Future<void> _sendMaxLightOutput(double pct) =>
      _client.writeInt('LOPI3', _toProtocol(pct));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUserMode = _mode.isUserMode;
    // In user modes the light output ceiling is the max light output value.
    final lightMax = isUserMode ? _maxLightOutput : 100.0;

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      title: DialogTitleBar(
        title: 'Brightness Control - ${widget.node.ipAddress}',
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
                  // A self-contained widget: it tracks its own value while the
                  // thumb is being dragged, so a drag only rebuilds this small
                  // subtree instead of the whole dialog (dropdown, other
                  // slider) on every pointer-move frame.
                  _PercentSlider(
                    title: 'Light Output',
                    value: _lightOutput,
                    min: 8,
                    max: lightMax,
                    onCommit: (v) {
                      setState(() => _lightOutput = v);
                      _sendLightOutput(v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Max Light Output ────────────────────────────────────────
                  _PercentSlider(
                    title: 'Max Light Output',
                    value: _maxLightOutput,
                    min: 8,
                    max: 100,
                    enabled: isUserMode,
                    disabledColor: theme.disabledColor,
                    onCommit: (v) {
                      setState(() {
                        _maxLightOutput = v;
                        // Keep light output within new ceiling.
                        if (_lightOutput > v) _lightOutput = v;
                      });
                      _sendMaxLightOutput(v);
                    },
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
    );
  }
}

// ── Percent slider ───────────────────────────────────────────────────────
// Tracks its own value locally while being dragged so a drag rebuilds only
// this row (label + slider) instead of the whole dialog. The authoritative
// value still lives in the parent and is committed back via [onCommit] once
// the drag ends; [didUpdateWidget] re-syncs the local value whenever the
// parent's changes externally (e.g. mode switch, or the other slider
// clamping this one) — but only while not actively being dragged, so it
// never fights an in-progress gesture.
class _PercentSlider extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final Color? disabledColor;
  final ValueChanged<double> onCommit;

  const _PercentSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.enabled = true,
    this.disabledColor,
  });

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {
  late double _value = widget.value.clamp(widget.min, widget.max);
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _PercentSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging) {
      _value = widget.value.clamp(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = _value.clamp(widget.min, widget.max);
    final color = widget.enabled ? null : widget.disabledColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${clamped.round()}%',
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context)
              .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
          child: Slider(
            min: widget.min,
            max: widget.max,
            divisions: (widget.max - widget.min).round().clamp(1, 999),
            value: clamped,
            label: '${clamped.round()}%',
            onChanged: widget.enabled
                ? (v) {
                    _dragging = true;
                    setState(() => _value = v);
                  }
                : null,
            onChangeEnd: widget.enabled
                ? (v) {
                    _dragging = false;
                    widget.onCommit(v);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
