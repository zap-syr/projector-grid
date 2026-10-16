import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';
import 'card_heading.dart';

/// Color Matching's second card while the method is Off: what 3 and 7
/// colors adjust, and what turning it on does to Color Temperature. Fills
/// the rest of the body.
class MatchingOffCard extends StatelessWidget {
  const MatchingOffCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return ColorCard(
      child: Center(
        // Padding, not a max width: the body measures this card's
        // intrinsic height at the card's width to fill the space under it,
        // and a ConstrainedBox would let the text wrap less there than here.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const DialogIconTile(Icons.compare_outlined),
              Text(
                'Color matching is off',
                textAlign: TextAlign.center,
                style: t.cardTitle,
              ),
              Text(
                'Choose 3 colors to adjust red, green and blue, or 7 colors '
                'to also adjust cyan, magenta, yellow and white.',
                textAlign: TextAlign.center,
                style: t.description,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DialogSurfaces.of(context).soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: t.secondary),
                    Expanded(
                      child: Text(
                        'While it is on, Color Temperature is fixed and only '
                        'white balance can be changed.',
                        style: t.description,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
