import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_limits.dart';
import '../common/labeled_slider_row.dart';
import '../common/section_card.dart';
import '../custom_tooltip.dart';
import 'edge_blend_state.dart';

/// Pair mode's Link toggle, on the facing edge's card. [onChanged] is null
/// when Link isn't possible ([tooltip] says why).
typedef EdgeLinkControl = ({
  BlendEdge edge,
  bool on,
  String tooltip,
  ValueChanged<bool>? onChanged,
});

/// Right-hand controls of the Edge Blending tab: Markers, Auto test pattern
/// and one card per edge.
class EdgeBlendPanel extends StatelessWidget {
  const EdgeBlendPanel({
    super.key,
    required this.state,
    required this.raster,
    required this.selectedEdge,
    this.maxFor,
    this.link,
    required this.onMarkersChanged,
    required this.onAutoPatternChanged,
    this.autoPatternRefused = false,
    required this.onEnabledChanged,
    required this.onValueChanged,
    required this.onValueCommitted,
  });

  final EdgeBlendState state;
  final EdgeBlendRaster raster;
  final BlendEdge? selectedEdge;

  /// The limit of each value; defaults to this projector's own §8 limit
  /// (a linked Width also has to fit the other projector).
  final int Function(BlendEdge edge, EdgePart part)? maxFor;
  final EdgeLinkControl? link;
  final ValueChanged<bool> onMarkersChanged;
  final ValueChanged<bool> onAutoPatternChanged;

  /// The projector refused the last Auto test pattern change (ER401, a test
  /// pattern is on).
  final bool autoPatternRefused;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          children: [
            _LabeledSwitch(
              label: 'Markers',
              value: state.markers,
              onChanged: onMarkersChanged,
            ),
            _LabeledSwitch(
              label: 'Auto test pattern',
              value: state.autoPattern,
              onChanged: onAutoPatternChanged,
              warning: autoPatternRefused
                  ? 'Not available while a test pattern is on'
                  : null,
            ),
          ],
        ),
        for (final edge in BlendEdge.values) ...[
          const SizedBox(height: 10),
          _EdgeCard(
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
        ],
      ],
    );
  }
}

class _LabeledSwitch extends StatelessWidget {
  const _LabeledSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.warning,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Shown as an icon with a tooltip after the label, so nothing below
  /// moves when it comes and goes.
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (warning != null) ...[
          const SizedBox(width: 4),
          CustomTooltip(
            message: warning,
            warning: true,
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _EdgeCard extends StatelessWidget {
  const _EdgeCard({
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

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      highlighted: selected && settings.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EdgeSideIcon(edge: edge, enabled: settings.enabled),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  edge.label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (link case final link?) _LinkToggle(link: link),
              Switch(value: settings.enabled, onChanged: onEnabledChanged),
            ],
          ),
          const SizedBox(height: 4),
          _row(context, EdgePart.start, 'Start', maxStart),
          _row(context, EdgePart.width, 'Width', maxWidth),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, EdgePart part, String label, int limit) {
    final enabled = settings.enabled;
    // The range is the whole raster, not the §8 limit: that limit moves with
    // the other values (Width's with Start), and a moving range would slide
    // the thumb while its value stays put. The limit is a stop instead.
    return LabeledSliderRow(
      label: label,
      value: settings.valueOf(part).toDouble(),
      min: 0,
      max: span.toDouble(),
      limit: limit.toDouble(),
      labelWidth: 44,
      onChanged: enabled
          ? (v) => onValueChanged(part, min(v.round(), limit))
          : null,
      onChangeEnd: enabled ? (_) => onValueCommitted(part) : null,
    );
  }
}

class _LinkToggle extends StatelessWidget {
  const _LinkToggle({required this.link});

  final EdgeLinkControl link;

  @override
  Widget build(BuildContext context) {
    final onChanged = link.onChanged;
    return CustomTooltip(
      message: link.tooltip,
      child: IconButton(
        isSelected: link.on,
        icon: const Icon(Icons.link_off),
        selectedIcon: const Icon(Icons.link),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        onPressed: onChanged == null ? null : () => onChanged(!link.on),
      ),
    );
  }
}

/// A small frame with the edge's side drawn thick, so the four cards read
/// at a glance.
class EdgeSideIcon extends StatelessWidget {
  const EdgeSideIcon({super.key, required this.edge, required this.enabled});

  final BlendEdge edge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thin = BorderSide(color: scheme.onSurfaceVariant, width: 1.5);
    final thick = BorderSide(
      color: enabled ? scheme.primary : scheme.onSurfaceVariant,
      width: 4,
    );
    return Container(
      width: 18,
      height: 13,
      decoration: BoxDecoration(
        border: Border(
          top: edge == BlendEdge.upper ? thick : thin,
          bottom: edge == BlendEdge.lower ? thick : thin,
          left: edge == BlendEdge.left ? thick : thin,
          right: edge == BlendEdge.right ? thick : thin,
        ),
      ),
    );
  }
}
