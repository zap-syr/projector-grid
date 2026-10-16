import 'package:flutter/material.dart';

import '../../../domain/color_correction.dart';
import '../common/segmented_tabs.dart';
import '../common/skeleton.dart';
import 'card_heading.dart';

/// Color Matching's first card: Off / 3 colors / 7 colors.
class MethodCard extends StatelessWidget {
  const MethodCard({super.key, required this.method, required this.onChanged});

  /// Null while loading.
  final MatchMethod? method;
  final ValueChanged<MatchMethod> onChanged;

  // Three segments wide enough for `3 colors` in the selected weight.
  static const double _width = 256;

  @override
  Widget build(BuildContext context) {
    final current = method;
    return ColorCard(
      child: ColorCardHeading(
        title: 'Method',
        // Shorter than the plan's "that sit side by side": that doesn't fit
        // beside the segments in one line.
        subtitle: 'Match projectors side by side',
        trailing: current == null
            ? const SkeletonPulse(
                child: Skeleton(width: _width, height: 40, radius: 12),
              )
            // Equal segments in a fixed width, so the heading beside it
            // never reflows when the selection moves.
            : SizedBox(
                width: _width,
                child: SegmentedTabs<MatchMethod>(
                  selected: current,
                  onChanged: onChanged,
                  tabs: [
                    for (final m in MatchMethod.values)
                      SegmentedTab(value: m, label: m.label),
                  ],
                ),
              ),
      ),
    );
  }
}
