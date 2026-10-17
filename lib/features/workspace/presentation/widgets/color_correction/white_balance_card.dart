import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/color_correction.dart';
import 'card_heading.dart';
import '../common/labeled_slider_row.dart';
import 'channel_tile.dart';
import 'color_swatches.dart';

/// White balance of User 1 / User 2 (and while Color Matching is on): rows
/// R / G / B, columns High (0 to 255) and Low (-127 to 127, filled from a
/// centre zero).
class WhiteBalanceCard extends StatelessWidget {
  const WhiteBalanceCard({
    super.key,
    required this.high,
    required this.low,
    required this.underColorMatching,
    required this.onChanged,
    required this.onCommit,
    required this.onTyped,
  });

  final List<int> high;
  final List<int> low;

  /// Color Matching edits these same registers, so the card stays usable
  /// there; only its subtitle changes.
  final bool underColorMatching;

  /// A drag; [isHigh] picks the column, [channel] the row (0 R, 1 G, 2 B).
  final void Function(bool isHigh, int channel, int value) onChanged;

  /// The drag ended: send now.
  final void Function(bool isHigh, int channel, int value) onCommit;

  /// Typed or stepped in a value field.
  final void Function(bool isHigh, int channel, int value) onTyped;

  static const double _columnGap = 16;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    Widget header(String name, String range) => Expanded(
      child: Text.rich(
        TextSpan(
          text: name,
          children: [TextSpan(text: '  $range', style: t.caption)],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.label,
      ),
    );

    return ColorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColorCardHeading(
            icon: Icons.tune,
            title: 'White balance',
            subtitle: underColorMatching
                ? 'Still adjustable while Color Matching is on'
                : 'High adjusts bright areas, Low adjusts dark areas',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: ChannelTile.size + 12),
              header('High', '0 to $whiteBalanceHighMax'),
              const SizedBox(width: _columnGap),
              header('Low', '-$whiteBalanceLowMax to $whiteBalanceLowMax'),
            ],
          ),
          for (final (i, (letter, color)) in rgbChannels.indexed) ...[
            // 4 + the slider row's own 2 px above and below.
            const SizedBox(height: 4),
            Row(
              children: [
                ChannelTile(letter: letter, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledSliderRow(
                    key: ValueKey('wb-high-$i'),
                    value: high[i].toDouble(),
                    min: 0,
                    max: whiteBalanceHighMax.toDouble(),
                    color: color,
                    onChanged: (v) => onChanged(true, i, v.round()),
                    onChangeEnd: (v) => onCommit(true, i, v.round()),
                    onTyped: (v) => onTyped(true, i, v.round()),
                  ),
                ),
                const SizedBox(width: _columnGap),
                Expanded(
                  child: LabeledSliderRow(
                    key: ValueKey('wb-low-$i'),
                    value: low[i].toDouble(),
                    min: -whiteBalanceLowMax.toDouble(),
                    max: whiteBalanceLowMax.toDouble(),
                    zeroFraction: 0.5,
                    color: color,
                    onChanged: (v) => onChanged(false, i, v.round()),
                    onChangeEnd: (v) => onCommit(false, i, v.round()),
                    onTyped: (v) => onTyped(false, i, v.round()),
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
