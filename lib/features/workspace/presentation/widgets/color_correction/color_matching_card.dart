import 'package:flutter/material.dart';

import '../../../domain/color_correction.dart';
import 'card_heading.dart';
import 'channel_slider.dart';
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
          ColorCardHeading(
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: previewOf(rgb),
                borderRadius: BorderRadius.circular(34 * 0.3),
                border: Border.all(color: cs.outlineVariant),
              ),
            ),
            title: selected.label,
            subtitle: changed ? 'Changed' : '',
            trailing: TextButton.icon(
              key: const ValueKey('color-reset'),
              onPressed: changed ? onReset : null,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, (letter, color)) in rgbChannels.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              spacing: 12,
              children: [
                ChannelTile(letter: letter, color: color),
                Expanded(
                  child: ChannelSlider(
                    key: ValueKey('color-channel-$i'),
                    value: rgb[i],
                    min: 0,
                    max: matchChannelMax,
                    color: color,
                    onChanged: (v) => onChannelChanged(i, v),
                    onCommit: (v) => onChannelCommit(i, v),
                    onTyped: (v) => onChannelTyped(i, v),
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
