import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../common/canvas_card.dart';
import '../common/controls_card.dart';
import '../common/dialog_parts.dart';
import '../common/labeled_slider_row.dart';
import 'edge_blend_parts.dart';
import 'edge_blend_state.dart';

/// The Edge Blending tab's controls card (§7a.2): one card per edge with
/// its switch, and Start and Width for an enabled edge, then a note. [top]
/// is the pair's A / B switch, which Off doesn't dim.
class EdgeBlendControls extends StatelessWidget {
  const EdgeBlendControls({
    super.key,
    required this.state,
    required this.raster,
    required this.selectedEdge,
    required this.title,
    required this.note,
    this.top,
    this.maxFor,
    this.link,
    required this.onEnabledChanged,
    required this.onValueChanged,
    required this.onValueCommitted,
  });

  final EdgeBlendState state;
  final EdgeBlendRaster raster;
  final BlendEdge? selectedEdge;

  /// `Edges`, or `Edges of A` in a pair.
  final String title;
  final String note;
  final Widget? top;

  /// The limit of each value; defaults to this projector's own §8 limit
  /// (a linked Width also has to fit the other projector).
  final int Function(BlendEdge edge, EdgePart part)? maxFor;
  final EdgeLinkControl? link;
  final void Function(BlendEdge edge, bool on) onEnabledChanged;

  /// Every slider move (not sent yet).
  final void Function(BlendEdge edge, EdgePart part, int v) onValueChanged;

  /// Slider released or stepper value entered: send it.
  final void Function(BlendEdge edge, EdgePart part) onValueCommitted;

  @override
  Widget build(BuildContext context) {
    final maxFor =
        this.maxFor ?? (edge, part) => state.maxFor(edge, part, raster);
    final link = this.link;
    final off = state.mode == EdgeBlendMode.off;
    return ControlsCard(
      key: edgeBlendControlsCardKey,
      groups: [
        ?top,
        OffDim(
          off: off,
          child: ControlsGroup(
            header: ControlsGroupHeader(title: title, unit: 'panel pixels'),
            rows: [
              for (final edge in BlendEdge.values)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: EdgeCard(
                    edge: edge,
                    settings: state[edge],
                    span: edgeBlendSpan(raster, edge),
                    maxStart: maxFor(edge, EdgePart.start),
                    maxWidth: maxFor(edge, EdgePart.width),
                    selected: edge == selectedEdge,
                    link: link?.edge == edge ? link : null,
                    onEnabledChanged: (on) => onEnabledChanged(edge, on),
                    onValueChanged: (part, v) => onValueChanged(edge, part, v),
                    onValueCommitted: (part) => onValueCommitted(edge, part),
                  ),
                ),
              const SizedBox(height: 6),
              CanvasNote(child: Text(note)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One edge: side icon, name, the Link chip on a pair's facing edge and
/// the switch. A disabled edge collapses to that one row (§7a.6).
class EdgeCard extends StatelessWidget {
  const EdgeCard({
    super.key,
    required this.edge,
    required this.settings,
    required this.span,
    required this.maxStart,
    required this.maxWidth,
    required this.selected,
    required this.link,
    required this.onEnabledChanged,
    required this.onValueChanged,
    required this.onValueCommitted,
  });

  final BlendEdge edge;
  final EdgeSettings settings;
  final EdgeLinkControl? link;

  /// The raster length along this edge: every slider's fixed range.
  final int span;
  final int maxStart;
  final int maxWidth;
  final bool selected;
  final ValueChanged<bool> onEnabledChanged;
  final void Function(EdgePart part, int v) onValueChanged;
  final void Function(EdgePart part) onValueCommitted;

  static const double headerHeight = 34;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final enabled = settings.enabled;
    final link = this.link;
    return DialogCard(
      highlighted: selected && enabled,
      padding: EdgeInsets.fromLTRB(12, 2, 8, enabled ? 6 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                EdgeSideIcon(edge: edge, enabled: enabled),
                const SizedBox(width: 10),
                Text(
                  edge.label,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (!enabled) ...[
                  const SizedBox(width: 8),
                  Text('Off', style: t.description.copyWith(color: t.tertiary)),
                ],
                // The chip takes what the name leaves, right-aligned.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: link == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(left: 8, right: 6),
                            child: LinkChip(link: link),
                          ),
                  ),
                ),
                Switch(
                  value: enabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
          ),
          if (enabled) ...[
            _row(context, EdgePart.start, 'Start', maxStart),
            _row(context, EdgePart.width, 'Width', maxWidth),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, EdgePart part, String label, int limit) {
    final t = AppText.of(context);
    final color = edgePartColor(context, part);
    // The range is the whole raster, not the §8 limit: that limit moves with
    // the other values (Width's with Start), and a moving range would slide
    // the thumb while its value stays put. The limit is a stop instead.
    return LabeledSliderRow(
      key: ValueKey('edge-${edge.name}-${part.name}'),
      label: label,
      labelMark: PartMark(color: color),
      labelStyle: t.body.copyWith(color: t.secondary),
      labelWidth: 64,
      color: color,
      value: settings.valueOf(part).toDouble(),
      min: 0,
      max: span.toDouble(),
      limit: limit.toDouble(),
      onChanged: (v) => onValueChanged(part, min(v.round(), limit)),
      onChangeEnd: (_) => onValueCommitted(part),
    );
  }
}
