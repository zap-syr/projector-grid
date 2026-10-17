import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../color_correction/channel_tile.dart';
import '../color_correction/color_swatches.dart';
import '../common/controls_card.dart';
import '../common/labeled_slider_row.dart';
import '../common/segmented_tabs.dart';
import '../custom_tooltip.dart';
import '../sleek_stepper_input.dart';
import 'black_level_state.dart';
import 'edge_blend_parts.dart';
import 'edge_blend_state.dart';

/// The Black Level tab's controls card (§7a.4), top to bottom: Mode, the
/// Edges table (overlapped level and border width per edge), the
/// non-overlapped area and the black border level. [top] is the pair's
/// A / B switch, which Off doesn't dim.
class BlackLevelControls extends StatelessWidget {
  const BlackLevelControls({
    super.key,
    required this.black,
    required this.blend,
    required this.raster,
    required this.selectedEdge,
    required this.title,
    this.top,
    this.linked,
    required this.onModeChanged,
    required this.onLevelChanged,
    required this.onLevelCommitted,
    required this.onInterlockedChanged,
    required this.onBorderWidthChanged,
    required this.onBorderWidthCommitted,
  });

  final BlackLevelState black;

  /// For the edge rows (dimmed while their edge is off), the border widths
  /// and their limits (§8).
  final EdgeBlendState blend;
  final EdgeBlendRaster raster;
  final BlendEdge? selectedEdge;

  /// `Edges`, or `Edges of A` in a pair.
  final String title;
  final Widget? top;

  /// Pair mode's linked facing edge, whose overlapped level mirrors to the
  /// other projector, and the tooltip naming where it goes.
  final ({BlendEdge edge, String tooltip})? linked;
  final ValueChanged<BlackLevelMode> onModeChanged;

  /// Every slider move (not sent yet).
  final void Function(LevelSlot slot, RgbChannel channel, int v) onLevelChanged;

  /// Slider released or stepper value entered: send it.
  final void Function(LevelSlot slot) onLevelCommitted;
  final void Function(LevelSlot slot, bool on) onInterlockedChanged;
  final void Function(BlendEdge edge, int v) onBorderWidthChanged;
  final void Function(BlendEdge edge) onBorderWidthCommitted;

  @override
  Widget build(BuildContext context) {
    final off = blend.mode == EdgeBlendMode.off;
    Widget dim(Widget child) => OffDim(off: off, child: child);
    return ControlsCard(
      key: edgeBlendControlsCardKey,
      groups: [
        ?top,
        dim(
          ControlsGroup(
            header: const ControlsGroupHeader(title: 'Mode'),
            rows: [
              SegmentedTabs<BlackLevelMode>(
                tabs: [
                  for (final m in BlackLevelMode.values)
                    SegmentedTab(value: m, label: m.label),
                ],
                selected: black.mode,
                onChanged: onModeChanged,
              ),
            ],
          ),
        ),
        dim(
          ControlsGroup(
            header: ControlsGroupHeader(
              title: title,
              unit: 'overlapped level, border width',
            ),
            rows: [
              EdgeLevelTable(
                black: black,
                blend: blend,
                raster: raster,
                selectedEdge: selectedEdge,
                linked: linked,
                onLevelChanged: onLevelChanged,
                onLevelCommitted: onLevelCommitted,
                onInterlockedChanged: onInterlockedChanged,
                onBorderWidthChanged: onBorderWidthChanged,
                onBorderWidthCommitted: onBorderWidthCommitted,
              ),
            ],
          ),
        ),
        dim(_levelGroup(LevelSlot.nonOverlapped, 'Non-overlapped area')),
        dim(_levelGroup(LevelSlot.border, 'Black border level')),
      ],
    );
  }

  Widget _levelGroup(LevelSlot slot, String title) => RgbLevelGroup(
    title: title,
    level: black[slot],
    onChanged: (c, v) => onLevelChanged(slot, c, v),
    onCommitted: () => onLevelCommitted(slot),
    onInterlockedChanged: (on) => onInterlockedChanged(slot, on),
  );
}

/// A level's R, G, B sliders under a header with its Interlocked
/// checkbox. The three sliders stay put either way; while interlocked,
/// moving one moves the others (as in VSS), so nothing appears or
/// disappears.
class RgbLevelGroup extends StatelessWidget {
  const RgbLevelGroup({
    super.key,
    required this.title,
    required this.level,
    required this.onChanged,
    required this.onCommitted,
    required this.onInterlockedChanged,
  });

  final String title;
  final RgbwLevel level;
  final void Function(RgbChannel channel, int v) onChanged;
  final VoidCallback onCommitted;
  final ValueChanged<bool> onInterlockedChanged;

  @override
  Widget build(BuildContext context) {
    return ControlsGroup(
      header: ControlsGroupHeader(
        title: title,
        unit: '0 to 255',
        trailing: InterlockedCheck(
          value: level.interlocked,
          onChanged: onInterlockedChanged,
        ),
      ),
      rows: [
        for (final (i, c) in RgbChannel.values.indexed)
          Row(
            spacing: 12,
            children: [
              ChannelTile(letter: rgbChannels[i].$1, color: rgbChannels[i].$2),
              Expanded(
                child: LabeledSliderRow(
                  value: level.channel(c).toDouble(),
                  min: 0,
                  max: 255,
                  color: rgbChannels[i].$2,
                  onChanged: (v) => onChanged(c, v.round()),
                  onChangeEnd: (_) => onCommitted(),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The Edges table of the Black Level tab: per edge its name, the Link
/// icon (pair), Interlocked, the R, G, B steppers of its overlapped level
/// and, after a divider, its border width in a primary tint, so levels and
/// widths don't read as one group (owner, 2026-10-14). Narrower than
/// [wideWidth] each edge takes two lines: name and checkbox, then the
/// fields.
class EdgeLevelTable extends StatelessWidget {
  const EdgeLevelTable({
    super.key,
    required this.black,
    required this.blend,
    required this.raster,
    required this.selectedEdge,
    required this.linked,
    required this.onLevelChanged,
    required this.onLevelCommitted,
    required this.onInterlockedChanged,
    required this.onBorderWidthChanged,
    required this.onBorderWidthCommitted,
  });

  final BlackLevelState black;
  final EdgeBlendState blend;
  final EdgeBlendRaster raster;
  final BlendEdge? selectedEdge;
  final ({BlendEdge edge, String tooltip})? linked;
  final void Function(LevelSlot slot, RgbChannel channel, int v) onLevelChanged;
  final void Function(LevelSlot slot) onLevelCommitted;
  final void Function(LevelSlot slot, bool on) onInterlockedChanged;
  final void Function(BlendEdge edge, int v) onBorderWidthChanged;
  final void Function(BlendEdge edge) onBorderWidthCommitted;

  static const double _name = 64;
  static const double _link = 18;
  static const double _check = 26;
  static const double _field = 56;
  static const double _divider = 13;
  static const double _gap = 4;

  /// Name, link, checkbox, three levels, divider and width, with a gap
  /// between each.
  static const double wideWidth =
      _name + _link + _check + 4 * _field + _divider + 7 * _gap;

  static const double _rowHeight = 36;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, wide),
            for (final edge in BlendEdge.values) _row(context, edge, wide),
          ],
        );
      },
    );
  }

  /// R, G, B, divider, Width: the field columns of a row.
  List<Widget> _fieldColumns(List<Widget> levels, Widget width) => [
    for (final (i, l) in levels.indexed) ...[
      if (i > 0) const SizedBox(width: _gap),
      SizedBox(width: _field, child: l),
    ],
    const SizedBox(width: _gap),
    const SizedBox(width: _divider),
    const SizedBox(width: _gap),
    SizedBox(width: _field, child: width),
  ];

  Widget _header(BuildContext context, bool wide) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final fields = _fieldColumns(
      [
        for (final (letter, color) in rgbChannels)
          Center(
            child: ChannelTile(letter: letter, color: color),
          ),
      ],
      CustomTooltip(
        message: 'Black border width',
        detail: 'Panel pixels from the zone end',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 14, color: cs.primary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'Width',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      height: 26,
      child: Row(
        children: wide
            ? [
                const SizedBox(width: _name + _gap + _link + _gap),
                SizedBox(
                  width: _check,
                  // Not a link icon: pair mode's Link uses that on the rows.
                  child: CustomTooltip(
                    message: 'Interlocked',
                    detail: 'R, G and B move together',
                    child: Icon(Icons.join_inner, size: 16, color: t.secondary),
                  ),
                ),
                const SizedBox(width: _gap),
                const Spacer(),
                ...fields,
              ]
            : [const Spacer(), ...fields],
      ),
    );
  }

  Widget _row(BuildContext context, BlendEdge edge, bool wide) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final slot = LevelSlot.overlap(edge);
    final level = black[slot];
    final enabled = blend[edge].enabled;
    final link = linked;
    // Dimmed only as a cue: the projector keeps the level of a disabled
    // edge, so it stays editable; its border width still counts for the
    // limits, so it stays shown but can't be changed.
    Widget dimmed(Widget child) =>
        Opacity(opacity: enabled ? 1 : 0.45, child: child);
    final name = SizedBox(
      width: _name,
      child: dimmed(
        Row(
          children: [
            EdgeSideIcon(edge: edge, enabled: enabled),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                edge.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.description.copyWith(color: t.primary),
              ),
            ),
          ],
        ),
      ),
    );
    final linkIcon = SizedBox(
      width: _link,
      child: link != null && link.edge == edge
          ? CustomTooltip(
              message: link.tooltip,
              child: Icon(Icons.link, size: 16, color: cs.primary),
            )
          : null,
    );
    final check = SizedBox(
      width: _check,
      child: Checkbox(
        value: level.interlocked,
        visualDensity: const VisualDensity(
          horizontal: VisualDensity.minimumDensity,
          vertical: VisualDensity.minimumDensity,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (v) => onInterlockedChanged(slot, v!),
      ),
    );
    final limit = blend.maxFor(edge, EdgePart.border, raster);
    final fields = _fieldColumns(
      [
        for (final c in RgbChannel.values)
          dimmed(
            SleekStepperInput(
              key: ValueKey('level-${edge.name}-${c.name}'),
              initialValue: level.channel(c).toString(),
              min: 0,
              max: 255,
              onValueChanged: (s) {
                onLevelChanged(slot, c, double.parse(s).round());
                onLevelCommitted(slot);
              },
            ),
          ),
      ],
      IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Container(
            foregroundDecoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SleekStepperInput(
              key: ValueKey('border-width-${edge.name}'),
              initialValue: '${blend[edge].border}',
              min: 0,
              max: limit.toDouble(),
              onValueChanged: (s) {
                onBorderWidthChanged(edge, min(double.parse(s).round(), limit));
                onBorderWidthCommitted(edge);
              },
            ),
          ),
        ),
      ),
    );
    final divider = Positioned(
      top: 4,
      bottom: 4,
      right: _field + _gap + (_divider - 1) / 2,
      child: Container(
        width: 1,
        color: cs.outlineVariant.withValues(alpha: 0.6),
      ),
    );
    final Widget content = wide
        ? SizedBox(
            height: _rowHeight,
            child: Stack(
              children: [
                Row(
                  children: [
                    name,
                    const SizedBox(width: _gap),
                    linkIcon,
                    const SizedBox(width: _gap),
                    check,
                    const SizedBox(width: _gap),
                    const Spacer(),
                    ...fields,
                  ],
                ),
                divider,
              ],
            ),
          )
        : Column(
            children: [
              SizedBox(
                height: 28,
                child: Row(children: [name, linkIcon, const Spacer(), check]),
              ),
              SizedBox(
                height: _rowHeight,
                child: Stack(
                  children: [
                    Row(children: [const Spacer(), ...fields]),
                    divider,
                  ],
                ),
              ),
            ],
          );
    return Container(
      key: ValueKey('level-row-${edge.name}'),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: edge == selectedEdge ? cs.primary.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}
