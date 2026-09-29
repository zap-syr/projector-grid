import 'package:flutter/material.dart';

/// Canvas left (5 parts) + scrollable controls right (4 parts). Both panels
/// grow proportionally so the canvas stays large at any dialog width.
class DialogSplitLayout extends StatelessWidget {
  final Widget left;
  final Widget right;

  const DialogSplitLayout({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: left),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: right,
          ),
        ),
      ],
    );
  }
}
