import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../custom_tooltip.dart';
import '../common/labeled_slider_row.dart';
import '../common/section_card.dart';
import '../sleek_stepper_input.dart';
import 'black_level_state.dart';
import 'edge_blend_panel.dart';
import 'edge_blend_state.dart';

/// Right-hand controls of the Black Level tab: mode, the non-overlapped
/// level, the overlapped levels per edge and the black border.
class BlackLevelPanel extends StatelessWidget {
  const BlackLevelPanel({
    super.key,
    required this.black,
    required this.blend,
    required this.raster,
    required this.selectedEdge,
    required this.onModeChanged,
    required this.onLevelChanged,
    required this.onLevelCommitted,
    required this.onInterlockedChanged,
    required this.onBorderWidthChanged,
    required this.onBorderWidthCommitted,
  });

  final BlackLevelState black;

  /// For the overlapped rows (dimmed while their edge is off) and the
  /// border width limits (raster minus the edge's blend width).
  final EdgeBlendState blend;
  final EdgeBlendRaster raster;
  final BlendEdge? selectedEdge;
  final ValueChanged<BlackLevelMode> onModeChanged;

  /// Every slider move (not sent yet).
  final void Function(LevelSlot slot, RgbwChannel channel, int v)
  onLevelChanged;

  /// Slider released or stepper value entered: send it.
  final void Function(LevelSlot slot) onLevelCommitted;
  final void Function(LevelSlot slot, bool on) onInterlockedChanged;
  final void Function(BlendEdge edge, int v) onBorderWidthChanged;
  final void Function(BlendEdge edge) onBorderWidthCommitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<BlackLevelMode>(
          segments: [
            for (final m in BlackLevelMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {black.mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        const SizedBox(height: 10),
        _levelCard(LevelSlot.nonOverlapped, 'Non-overlapped black level'),
        const SizedBox(height: 10),
        _OverlappedCard(
          black: black,
          blend: blend,
          selectedEdge: selectedEdge,
          onLevelChanged: onLevelChanged,
          onLevelCommitted: onLevelCommitted,
          onInterlockedChanged: onInterlockedChanged,
        ),
        const SizedBox(height: 10),
        _levelCard(
          LevelSlot.border,
          'Black border',
          footer: [
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            for (final edge in BlendEdge.values) _borderWidthRow(context, edge),
          ],
        ),
      ],
    );
  }

  Widget _levelCard(
    LevelSlot slot,
    String title, {
    List<Widget> footer = const [],
  }) => RgbwLevelCard(
    title: title,
    level: black[slot],
    onChanged: (c, v) => onLevelChanged(slot, c, v),
    onCommitted: () => onLevelCommitted(slot),
    onInterlockedChanged: (on) => onInterlockedChanged(slot, on),
    footer: footer,
  );

  Widget _borderWidthRow(BuildContext context, BlendEdge edge) {
    final limit = blend.maxFor(edge, EdgePart.border, raster);
    // Full-span range with the limit as a stop, as on the blend sliders.
    return LabeledSliderRow(
      label: edge.label,
      value: black.borderWidth(edge).toDouble(),
      min: 0,
      max: edgeBlendSpan(raster, edge).toDouble(),
      layout: SliderLabelLayout.inline,
      inlineLabelWidth: 44,
      color: Theme.of(context).colorScheme.primary,
      onChanged: (v) => onBorderWidthChanged(edge, min(v.round(), limit)),
      onChangeEnd: (_) => onBorderWidthCommitted(edge),
    );
  }
}

Color _channelColor(BuildContext context, RgbwChannel c) => switch (c) {
  RgbwChannel.w => Theme.of(context).colorScheme.onSurfaceVariant,
  RgbwChannel.r => Colors.red,
  RgbwChannel.g => Colors.green,
  RgbwChannel.b => Colors.blue,
};

String _channelLabel(RgbwChannel c) => c.name.toUpperCase();

/// A W,R,G,B black level with its Interlocked checkbox: one W slider while
/// interlocked, four otherwise. [footer] goes under the sliders.
class RgbwLevelCard extends StatelessWidget {
  const RgbwLevelCard({
    super.key,
    required this.title,
    required this.level,
    required this.onChanged,
    required this.onCommitted,
    required this.onInterlockedChanged,
    this.footer = const [],
  });

  final String title;
  final RgbwLevel level;
  final void Function(RgbwChannel channel, int v) onChanged;
  final VoidCallback onCommitted;
  final ValueChanged<bool> onInterlockedChanged;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final channels = level.interlocked
        ? const [RgbwChannel.w]
        : RgbwChannel.values;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _InterlockedToggle(
                value: level.interlocked,
                onChanged: onInterlockedChanged,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final c in channels)
            LabeledSliderRow(
              // Keyed so W keeps its stepper State when R/G/B come and go.
              key: ValueKey(c),
              label: _channelLabel(c),
              value: level.shown(c).toDouble(),
              min: 0,
              max: 255,
              layout: SliderLabelLayout.inline,
              color: _channelColor(context, c),
              onChanged: (v) => onChanged(c, v.round()),
              onChangeEnd: (_) => onCommitted(),
            ),
          ...footer,
        ],
      ),
    );
  }
}

class _InterlockedToggle extends StatelessWidget {
  const _InterlockedToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => onChanged(v!),
          ),
          Text('Interlocked', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// One row per edge: Interlocked, then W/R/G/B steppers (no sliders, to
/// keep the card short). Interlocked leaves only W editable.
class _OverlappedCard extends StatelessWidget {
  const _OverlappedCard({
    required this.black,
    required this.blend,
    required this.selectedEdge,
    required this.onLevelChanged,
    required this.onLevelCommitted,
    required this.onInterlockedChanged,
  });

  static const double _edgeColumn = 64;
  static const double _checkColumn = 40;
  static const double _valueColumn = 64;

  final BlackLevelState black;
  final EdgeBlendState blend;
  final BlendEdge? selectedEdge;
  final void Function(LevelSlot slot, RgbwChannel channel, int v)
  onLevelChanged;
  final void Function(LevelSlot slot) onLevelCommitted;
  final void Function(LevelSlot slot, bool on) onInterlockedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Overlapped black level',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Scales down rather than overflowing in a narrow dialog.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                for (final edge in BlendEdge.values) _row(context, edge),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        const SizedBox(width: _edgeColumn),
        SizedBox(
          width: _checkColumn,
          child: CustomTooltip(
            message: 'Interlocked',
            child: Icon(Icons.link, size: 16, color: muted),
          ),
        ),
        for (final c in RgbwChannel.values)
          SizedBox(
            width: _valueColumn,
            child: Text(
              _channelLabel(c),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _channelColor(context, c),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, BlendEdge edge) {
    final slot = LevelSlot.overlap(edge);
    final level = black[slot];
    final enabled = blend[edge].enabled;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: edge == selectedEdge
            ? scheme.primary.withValues(alpha: 0.1)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      // Dimmed only as a cue: the projector keeps the level of a disabled
      // edge, so it stays editable.
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          children: [
            SizedBox(
              width: _edgeColumn,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  EdgeSideIcon(edge: edge, enabled: enabled),
                  const SizedBox(width: 6),
                  Text(edge.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: _checkColumn,
              child: Checkbox(
                value: level.interlocked,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onInterlockedChanged(slot, v!),
              ),
            ),
            for (final c in RgbwChannel.values)
              _stepper(
                slot,
                level,
                c,
                editable: !level.interlocked || c == RgbwChannel.w,
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(
    LevelSlot slot,
    RgbwLevel level,
    RgbwChannel c, {
    required bool editable,
  }) {
    // Same wrapper either way, so the stepper keeps its State when
    // Interlocked flips.
    return SizedBox(
      width: _valueColumn,
      child: Center(
        child: IgnorePointer(
          ignoring: !editable,
          child: Opacity(
            opacity: editable ? 1 : 0.38,
            child: SleekStepperInput(
              initialValue: level.shown(c).toString(),
              min: 0,
              max: 255,
              onValueChanged: (s) {
                onLevelChanged(slot, c, double.parse(s).round());
                onLevelCommitted(slot);
              },
            ),
          ),
        ),
      ),
    );
  }
}
