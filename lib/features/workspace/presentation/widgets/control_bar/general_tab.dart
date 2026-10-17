import 'package:flutter/material.dart';

import 'control_bar_scroll.dart';
import 'input_card.dart';
import 'lens_card.dart';
import 'power_card.dart';
import 'test_pattern_card.dart';

class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ControlBarScroll(
      children: [PowerCard(), InputCard(), LensCard(), TestPatternCard()],
    );
  }
}
