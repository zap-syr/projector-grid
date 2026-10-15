import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_node.dart';
import '../providers/protocol_service_provider.dart';
import 'command_failure_notice.dart';
import 'common/debouncer.dart';
import 'common/dialog_parts.dart';
import 'common/mode_tile.dart';
import 'common/projector_settings_client.dart';
import 'common/scroll_fade.dart';
import 'common/skeleton.dart';
import 'common/slider_tracks.dart';
import 'common/step_buttons.dart';
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

  IconData get icon => switch (this) {
    normal => Icons.wb_sunny_outlined,
    eco => Icons.eco_outlined,
    quiet => Icons.bedtime_outlined,
    user1 || user2 || user3 => Icons.person_outline,
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

const double _minPercent = 8;
const double _maxPercent = 100;

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

  // One per value, so a burst of − / + presses becomes one write each.
  final _lightDebounce = Debouncer();
  final _maxDebounce = Debouncer();

  bool _loading = true;
  _OperatingMode _mode = _OperatingMode.normal;
  double _lightOutput = 100.0; // percentage 8 to 100
  double _maxLightOutput = 100.0; // percentage 8 to 100

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  @override
  void dispose() {
    // Flush, not cancel: the last press before ✕ still reaches the projector.
    _lightDebounce.flush();
    _maxDebounce.flush();
    super.dispose();
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
    if (lopi2 != null) {
      _lightOutput = _toPercent(lopi2).clamp(_minPercent, _maxPercent);
    }
    if (lopi3 != null) {
      _maxLightOutput = _toPercent(lopi3).clamp(_minPercent, _maxPercent);
    }

    setState(() => _loading = false);
  }

  Future<void> _sendMode(_OperatingMode mode) =>
      _client.writeRaw('VXX:OPEI1=${mode.protocolValue}');

  Future<void> _sendLightOutput(double pct) =>
      _client.writeInt('LOPI2', _toProtocol(pct));

  Future<void> _sendMaxLightOutput(double pct) =>
      _client.writeInt('LOPI3', _toProtocol(pct));

  void _selectMode(_OperatingMode m) {
    setState(() {
      _mode = m;
      // When switching to user mode clamp light output to max.
      if (m.isUserMode && _lightOutput > _maxLightOutput) {
        _lightOutput = _maxLightOutput;
        _lightDebounce.cancel();
      }
    });
    _sendMode(m);
  }

  void _setLightOutput(double v) => setState(() => _lightOutput = v);

  void _setMaxLightOutput(double v) => setState(() {
    _maxLightOutput = v;
    // Keep light output within new ceiling. A Light output press still
    // waiting in the debounce holds the old, higher value: drop it rather
    // than send it after the lower ceiling.
    if (_lightOutput > v) {
      _lightOutput = v;
      _lightDebounce.cancel();
    }
  });

  @override
  Widget build(BuildContext context) {
    final isUserMode = _mode.isUserMode;
    // In user modes the light output ceiling is the max light output value.
    final lightCap = isUserMode ? _maxLightOutput : null;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      // Maximum size, not a fixed one: the smallest window (800×600) leaves
      // about 720×550 inside the Dialog insets, so the body scrolls there.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 594),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogTitleBar(
              icon: Icons.brightness_6_outlined,
              title: 'Brightness Control',
              projectorId: widget.node.id,
            ),
            Flexible(
              child: ScrollFade(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        _ModeCard(
                          mode: _loading ? null : _mode,
                          onSelected: _selectMode,
                        ),
                        // A self-contained widget: it tracks its own value
                        // while the thumb is being dragged, so a drag only
                        // rebuilds this card instead of the whole dialog.
                        _PercentSlider(
                          icon: Icons.wb_sunny_outlined,
                          title: 'Light output',
                          subtitle: lightCap == null
                              ? 'Sent when you release the slider'
                              : 'Limited to ${lightCap.round()}% by Max light '
                                    'output',
                          value: _lightOutput,
                          cap: lightCap,
                          loading: _loading,
                          onCommit: (v) {
                            _lightDebounce.cancel();
                            _setLightOutput(v);
                            _sendLightOutput(v);
                          },
                          onStep: (v) {
                            _setLightOutput(v);
                            _lightDebounce.run(() => _sendLightOutput(v));
                          },
                        ),
                        _PercentSlider(
                          icon: Icons.vertical_align_top,
                          title: 'Max light output',
                          subtitle: isUserMode
                              ? 'Ceiling for Light output in this User mode'
                              : 'Only in User 1, 2 or 3 mode',
                          value: _maxLightOutput,
                          locked: !isUserMode,
                          loading: _loading,
                          onCommit: (v) {
                            _maxDebounce.cancel();
                            _setMaxLightOutput(v);
                            _sendMaxLightOutput(v);
                          },
                          onStep: (v) {
                            _setMaxLightOutput(v);
                            _maxDebounce.run(() => _sendMaxLightOutput(v));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            DialogFooter(message: SentRightAwayNote(loading: _loading)),
          ],
        ),
      ),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.muted = false});

  final Widget child;
  final bool muted;

  @override
  Widget build(BuildContext context) => DialogCard(
    muted: muted,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: child,
  );
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.title,
    required this.subtitle,
    this.muted = false,
  });

  final String title;

  /// Null while loading: a skeleton line in its place.
  final String? subtitle;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: muted ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        if (subtitle == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SkeletonPulse(child: Skeleton(width: 160, height: 12)),
          )
        else
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onSelected});

  /// Null while loading.
  final _OperatingMode? mode;
  final ValueChanged<_OperatingMode> onSelected;

  static const double _tileHeight = 60;

  @override
  Widget build(BuildContext context) {
    final current = mode;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const _CardHeading(
            title: 'Operating mode',
            subtitle: 'User modes unlock Max light output',
          ),
          if (current == null)
            SkeletonPulse(
              child: Row(
                children: [
                  for (final m in _OperatingMode.values) ...[
                    if (m != _OperatingMode.normal)
                      SizedBox(width: m == _OperatingMode.user1 ? 14 : 8),
                    const Expanded(
                      child: Skeleton(height: _tileHeight, radius: 10),
                    ),
                  ],
                ],
              ),
            )
          else
            ModeTileRow<_OperatingMode>(
              height: _tileHeight,
              selected: current,
              onSelected: onSelected,
              tiles: [
                for (final m in _OperatingMode.values)
                  ModeTileData(
                    value: m,
                    icon: m.icon,
                    label: m.label,
                    gapBefore: m == _OperatingMode.user1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Percent slider card ──────────────────────────────────────────────────
// Tracks its own value locally while being dragged so a drag rebuilds only
// this card (big value + slider) instead of the whole dialog. The
// authoritative value still lives in the parent and is committed back via
// [onCommit] once the drag ends; [didUpdateWidget] re-syncs the local value
// whenever the parent's changes externally (e.g. mode switch, − / +, or the
// other slider clamping this one) — but only while not actively being
// dragged, so it never fights an in-progress gesture.
class _PercentSlider extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;

  /// A stop below 100% the thumb can't pass (Light output in a User mode):
  /// the track above it is hatched.
  final double? cap;

  /// Outside User modes Max light output stays in place but can't be used.
  final bool locked;
  final bool loading;

  /// Slider released: send now.
  final ValueChanged<double> onCommit;

  /// − / + pressed: the new value, for the parent to debounce.
  final ValueChanged<double> onStep;

  const _PercentSlider({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onCommit,
    required this.onStep,
    this.cap,
    this.locked = false,
    this.loading = false,
  });

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {
  late double _value = _clamp(widget.value);
  bool _dragging = false;

  double get _upper => widget.cap ?? _maxPercent;

  double _clamp(double v) => v.clamp(_minPercent, widget.cap ?? _maxPercent);

  @override
  void didUpdateWidget(covariant _PercentSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging) _value = _clamp(widget.value);
  }

  void _step(int delta) =>
      widget.onStep(_clamp((_value.round() + delta).toDouble()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loading = widget.loading;
    final locked = widget.locked && !loading;
    final enabled = !loading && !locked;
    final value = _clamp(_value);
    final rounded = value.round();
    final cap = widget.cap;
    final capFraction = cap == null || cap >= _maxPercent
        ? null
        : (cap - _minPercent) / (_maxPercent - _minPercent);

    final iconTile = DialogIconTile(
      widget.icon,
      primary: !locked,
      muted: locked,
    );

    final Widget trailing = loading
        ? const SkeletonPulse(child: Skeleton(width: 56, height: 26, radius: 8))
        : locked
        ? const _LockPill()
        : Text.rich(
            TextSpan(
              text: '$rounded',
              children: [
                TextSpan(
                  text: '%',
                  style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              height: 32 / 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final sliderRow = SizedBox(
      height: 32,
      child: loading
          ? const SkeletonPulse(
              child: Row(
                spacing: 12,
                children: [
                  Skeleton(width: 32, height: 32, radius: 16),
                  Expanded(child: Skeleton(height: 6, radius: 3)),
                  Skeleton(width: 32, height: 32, radius: 16),
                ],
              ),
            )
          : Row(
              spacing: 12,
              children: [
                StepButton.minus(
                  tooltip: 'Decrease by 1%',
                  onPressed: enabled && rounded > _minPercent
                      ? () => _step(-1)
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      padding: EdgeInsets.zero,
                      trackShape: AppSliderTrackShape(
                        limitFraction: capFraction,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                        disabledThumbRadius: 9,
                        elevation: 1,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      tickMarkShape: SliderTickMarkShape.noTickMark,
                    ),
                    // Full 8 to 100 range even under a cap, so the hatched
                    // part shows where the ceiling sits; onChanged holds the
                    // thumb at the cap.
                    child: Slider(
                      min: _minPercent,
                      max: _maxPercent,
                      divisions: (_maxPercent - _minPercent).round(),
                      value: value,
                      onChanged: enabled
                          ? (v) {
                              _dragging = true;
                              setState(() => _value = _clamp(v));
                            }
                          : null,
                      onChangeEnd: enabled
                          ? (v) {
                              _dragging = false;
                              widget.onCommit(_clamp(v));
                            }
                          : null,
                    ),
                  ),
                ),
                StepButton.plus(
                  tooltip: 'Increase by 1%',
                  onPressed: enabled && rounded < _upper
                      ? () => _step(1)
                      : null,
                ),
              ],
            ),
    );

    return _Card(
      muted: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 14,
            children: [
              iconTile,
              Expanded(
                child: _CardHeading(
                  title: widget.title,
                  subtitle: loading ? null : widget.subtitle,
                  muted: locked,
                ),
              ),
              trailing,
            ],
          ),
          Opacity(
            opacity: locked ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                sliderRow,
                _Scale(capFraction: capFraction, cap: cap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `8%` … `100%` under the track, or `Max 80%` under the cap's tick.
class _Scale extends StatelessWidget {
  const _Scale({required this.capFraction, required this.cap});

  final double? capFraction;
  final double? cap;

  // Step button (32) + gap (12): the scale lines up with the track.
  static const double _inset = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11.5,
      color: cs.outline,
      fontWeight: FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final fraction = capFraction;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      child: SizedBox(
        height: 16,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.none,
            children: [
              // A cap near 8% would sit on top of it.
              if (fraction == null || fraction > 0.18)
                Positioned(left: 0, child: Text('8%', style: style)),
              if (fraction == null)
                Positioned(right: 0, child: Text('100%', style: style))
              else
                Positioned(
                  left: constraints.maxWidth * fraction,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text(
                      'Max ${cap!.round()}%',
                      style: style?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockPill extends StatelessWidget {
  const _LockPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(Icons.lock_outline, size: 13, color: cs.onSurfaceVariant),
          Text(
            'User modes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
