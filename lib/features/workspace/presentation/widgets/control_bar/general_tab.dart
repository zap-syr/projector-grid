import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'control_bar_parts.dart';
import 'control_bar_scroll.dart';
import 'input_card.dart';
import 'lens_card.dart';
import 'power_card.dart';
import 'test_pattern_card.dart';

class GeneralTab extends ConsumerWidget {
  const GeneralTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = watchHasSelection(ref);
    return ControlBarScroll(
      children: [
        PowerCard(enabled: enabled),
        InputCard(enabled: enabled),
        LensCard(enabled: enabled),
        TestPatternCard(enabled: enabled),
      ],
    );
  }
}
