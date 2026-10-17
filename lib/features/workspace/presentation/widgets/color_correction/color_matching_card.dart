import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/color_correction.dart';
import 'card_heading.dart';
import '../common/labeled_slider_row.dart';
import 'channel_tile.dart';
import 'color_swatches.dart';
import 'color_tile.dart';

/// Color Matching with 3 or 7 colors: a row of colour tiles and, under a
/// divider, the editor of the selected colour only.
class ColorMatchingCard extends StatelessWidget {
  const ColorMatchingCard({
    super.key,
    required this.method,
    required this.values,
    required this.selected,
    required this.onSelect,
    required this.onChannelChanged,
    required this.onChannelCommit,
    required this.onChannelTyped,
    required this.onReset,
  });

  final MatchMethod method;
  final Map<MatchColor, List<int>> values;
  final MatchColor selected;
  final ValueChanged<MatchColor> onSelect;

  /// A drag of the selected colour's [channel] (0 R, 1 G, 2 B).
  final void Function(int channel, int value) onChannelChanged;

  /// The drag ended: send now.
  final void Function(int channel, int value) onChannelCommit;

  /// Typed or stepped in the value field.
  final void Function(int channel, int value) onChannelTyped;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = method == MatchMethod.three;
    final rgb = values[selected]!;
    final changed = !selected.isDefault(rgb);
    return ColorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: wide ? 8 : 6,
            children: [
              for (final c in method.colors)
                Expanded(
                  child: ColorTile(
                    key: ValueKey('color-tile-${c.name}'),
                    color: c,
                    rgb: values[c]!,
                    selected: c == selected,
                    wide: wide,
                    onTap: () => onSelect(c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          _EditorHeading(
            preview: previewOf(rgb),
            title: selected.label,
            changed: changed,
            onReset: onReset,
          ),
          const SizedBox(height: 16),
          for (final (i, (letter, color)) in rgbChannels.indexed) ...[
            // 2 + the slider row's own 2 px above and below.
            if (i > 0) const SizedBox(height: 2),
            Row(
              spacing: 12,
              children: [
                ChannelTile(letter: letter, color: color),
                Expanded(
                  child: LabeledSliderRow(
                    key: ValueKey('color-channel-$i'),
                    value: rgb[i].toDouble(),
                    min: 0,
                    max: matchChannelMax.toDouble(),
                    color: color,
                    onChanged: (v) => onChannelChanged(i, v.round()),
                    onChangeEnd: (v) => onChannelCommit(i, v.round()),
                    onTyped: (v) => onChannelTyped(i, v.round()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The editor's heading: colour preview, the colour's name centred on it,
/// and *Changed* in small type under the name. The note hangs into the gap
/// below the row instead of taking a line, so the name never moves and the
/// card keeps its height whether the colour is changed or not.
class _EditorHeading extends StatelessWidget {
  const _EditorHeading({
    required this.preview,
    required this.title,
    required this.changed,
    required this.onReset,
  });

  static const double _previewSize = 34;

  final Color preview;
  final String title;
  final bool changed;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Row(
      spacing: 14,
      children: [
        Container(
          width: _previewSize,
          height: _previewSize,
          decoration: BoxDecoration(
            color: preview,
            borderRadius: BorderRadius.circular(_previewSize * 0.3),
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.cardTitle,
              ),
              SizedBox(
                height: 0,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: changed
                      ? Text(
                          'Changed',
                          maxLines: 1,
                          style: t.caption.copyWith(color: t.secondary),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          key: const ValueKey('color-reset'),
          onPressed: changed ? onReset : null,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}
