import 'package:flutter/material.dart';

/// Flat, always-visible card grouping related controls in a settings dialog —
/// no collapse/expand, so nothing gets added to or removed from the
/// accessibility tree when switching modes.
class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        // surfaceContainerHighest, not surfaceContainerHigh: the Dialog's own
        // Material background already uses surfaceContainerHigh by default,
        // so matching it here would make the cards blend into the dialog body.
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
