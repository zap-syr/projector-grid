import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/projector_node.dart';
import '../providers/protocol_service_provider.dart';
import 'command_failure_notice.dart';
import 'common/debouncer.dart';
import 'common/dialog_parts.dart';
import 'common/mode_tile.dart';
import 'common/projector_settings_client.dart';
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

  /// Max light output the projector fixes for this mode, so there's no
  /// LOPI3 to read (it answers ER401 to a write); null in a User mode,
  /// where it's adjustable.
  double? get fixedMaxLightOutput => switch (this) {
    normal => _maxPercent,
    eco || quiet => 80,
    user1 || user2 || user3 => null,
  };
}

const double _minPercent = 8;
const double _maxPercent = 100;

/// LOPI2 / LOPI3 are in tenths of a percent, so 0.1% is the finest step.
const double _stepPercent = 0.1;

/// Shared by the slider and the scale under it, which places `Max` by it.
const double _trackHeight = 6;

/// On the 0.1% grid: slider positions and repeated `+ 0.1` drift otherwise
/// (55.100000000000001).
double _snap(double pct) => (pct * 10).round() / 10;

/// `80` for a whole percent, `55.1` otherwise: for the cap label and the
/// subtitles, where `80.0%` would read oddly.
String _formatPercent(double pct) =>
    pct == pct.roundToDouble() ? '${pct.round()}' : pct.toStringAsFixed(1);

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

  // Every write goes through one queue. Each command is its own TCP
  // connection, so without it a press made in the mode being left could
  // land after the switch, or two quick switches could swap on the wire.
  Future<void> _queue = Future.value();

  // Bumped on every mode switch, so a read for a mode the user has already
  // left doesn't overwrite the values of the current one.
  int _readSeq = 0;

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

  // Protocol ↔ percentage: tenths of a percent, 80 = 8%, 1000 = 100%.
  static double _toPercent(int v) => v / 10;
  static int _toProtocol(double pct) => (pct * 10).round();

  Future<void> _loadValues() async {
    final modeRaw = await _client.readValue('OPEI1');
    if (!mounted) return;
    if (modeRaw != null) _mode = _OperatingMode.fromProtocol(modeRaw);
    await _readLevels(_mode, _readSeq);
    if (mounted) setState(() => _loading = false);
  }

  /// Reads the values [mode] holds: each mode keeps its own Light output,
  /// and a User mode its own Max light output too. [seq] is [_readSeq] when
  /// the read was asked for.
  Future<void> _readLevels(_OperatingMode mode, int seq) async {
    final fixedMax = mode.fixedMaxLightOutput;
    final (lopi2, lopi3) = await (
      _client.readInt('LOPI2'),
      fixedMax == null ? _client.readInt('LOPI3') : Future<int?>.value(),
    ).wait;
    if (!mounted || seq != _readSeq) return;
    setState(() {
      if (lopi2 != null) {
        _lightOutput = _toPercent(lopi2).clamp(_minPercent, _maxPercent);
      }
      if (fixedMax != null) {
        _maxLightOutput = fixedMax;
      } else if (lopi3 != null) {
        _maxLightOutput = _toPercent(lopi3).clamp(_minPercent, _maxPercent);
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() op) =>
      _queue = _queue.then((_) => op());

  Future<void> _sendLightOutput(double pct) =>
      _enqueue(() => _client.writeInt('LOPI2', _toProtocol(pct)));

  Future<void> _sendMaxLightOutput(double pct) =>
      _enqueue(() => _client.writeInt('LOPI3', _toProtocol(pct)));

  void _selectMode(_OperatingMode m) {
    final seq = ++_readSeq;
    // A press still waiting belongs to the mode being left: it goes out
    // ahead of the switch and is saved there.
    _lightDebounce.flush();
    _maxDebounce.flush();
    setState(() {
      _mode = m;
      final fixedMax = m.fixedMaxLightOutput;
      if (fixedMax != null) _maxLightOutput = fixedMax;
    });
    _enqueue(() => _client.writeRaw('VXX:OPEI1=${m.protocolValue}'));
    // The projector reports the new mode's values as soon as it has
    // acknowledged OPEI1 (checked on hardware), so no delay before reading.
    _enqueue(() => _readLevels(m, seq));
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
    // Light output can't go past Max light output: the projector refuses it
    // (ER402), also where the mode fixes Max (80% in Eco and Quiet).
    final lightCap = _maxLightOutput < _maxPercent ? _maxLightOutput : null;
    final lightSubtitle = lightCap == null
        ? 'Sent when you release the slider'
        : isUserMode
        ? 'Limited to ${_formatPercent(lightCap)}% by Max light output'
        : 'Limited to ${_formatPercent(lightCap)}% in ${_mode.label} mode';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      // Maximum size, not a fixed one: the smallest window (800×600) leaves
      // about 720×550 inside the Dialog insets, so the body scrolls there.
      child: ConstrainedBox(
        // A cap, not a size: the column takes only what its cards need, so
        // the body scrolls only in a window too short for them.
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
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
              child: DialogScrollBody(
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
                      subtitle: lightSubtitle,
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
                          : lightCap != null
                          ? 'Fixed at ${_formatPercent(lightCap)}% in '
                                '${_mode.label} mode'
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
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted ? t.cardTitle.copyWith(color: t.secondary) : t.cardTitle,
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
            style: t.description,
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

  double _clamp(double v) =>
      _snap(v).clamp(_minPercent, widget.cap ?? _maxPercent);

  @override
  void didUpdateWidget(covariant _PercentSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging) _value = _clamp(widget.value);
  }

  // Kept locally too: a held button's ticks can come faster than the parent
  // rebuilds, and each must step from the last one, not the last frame.
  void _step(int steps) =>
      widget.onStep(_value = _clamp(_value + steps * _stepPercent));

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final loading = widget.loading;
    final locked = widget.locked && !loading;
    final enabled = !loading && !locked;
    final value = _clamp(_value);
    final cap = widget.cap;
    final capFraction = cap == null || cap >= _maxPercent
        ? null
        : (cap - _minPercent) / (_maxPercent - _minPercent);

    final iconTile = DialogIconTile(widget.icon, muted: locked);

    Widget valueText(String digits) => Text.rich(
      TextSpan(
        text: digits,
        children: [
          TextSpan(
            text: '%',
            style: t.cardTitle.copyWith(
              fontWeight: FontWeight.w400,
              color: t.secondary,
            ),
          ),
        ],
      ),
      style: t.value.copyWith(height: 32 / 26),
    );

    final Widget trailing = loading
        ? const SkeletonPulse(child: Skeleton(width: 56, height: 26, radius: 8))
        : locked
        ? const _LockPill()
        // Sized by an invisible widest value, so the heading beside it
        // doesn't reflow as the value goes from 9.9% to 10.0% or 100.0%.
        : Stack(
            alignment: Alignment.centerRight,
            children: [
              Opacity(opacity: 0, child: valueText('100.0')),
              valueText(value.toStringAsFixed(1)),
            ],
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
                  tooltip: 'Decrease by 0.1%',
                  onStep: enabled && value > _minPercent
                      ? (steps) => _step(-steps)
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: _trackHeight,
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
                      divisions: ((_maxPercent - _minPercent) / _stepPercent)
                          .round(),
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
                  tooltip: 'Increase by 0.1%',
                  onStep: enabled && value < _upper ? _step : null,
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
    final t = AppText.of(context);
    final style = t.caption.copyWith(
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
                  // Under the cap's tick, which sits where the thumb stops.
                  left: AppSliderTrackShape.positionOf(
                    fraction,
                    left: 0,
                    width: constraints.maxWidth,
                    trackHeight: _trackHeight,
                    isDiscrete: true,
                  ),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text(
                      'Max ${_formatPercent(cap!)}%',
                      style: style.copyWith(
                        color: t.secondary,
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
    final t = AppText.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(Icons.lock_outline, size: 14, color: t.secondary),
          Text(
            'User modes',
            style: t.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: t.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
