import 'package:flutter/material.dart';

import '../common/dialog_parts.dart';
import 'control_bar_parts.dart';

/// The scrolling body of one tab: its cards [ControlBarMetrics.cardGap]
/// apart, scrollbar and fade when the window is too short for them.
class ControlBarScroll extends StatelessWidget {
  const ControlBarScroll({super.key, required this.children});

  final List<Widget> children;

  static const padding = EdgeInsets.fromLTRB(
    ControlBarMetrics.gutter,
    10,
    ControlBarMetrics.gutter,
    ControlBarMetrics.gutter,
  );

  @override
  Widget build(BuildContext context) {
    return DialogScrollBody(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ControlBarMetrics.cardGap,
        children: children,
      ),
    );
  }
}
