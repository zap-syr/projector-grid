import 'package:flutter/material.dart';

/// Surfaces of the Groups dialogs. The dialog body is surfaceContainerLow;
/// cards sit one step lighter in both themes (white in light, the next
/// container tone in dark), an open editor one step darker than the card.
abstract final class GroupSurfaces {
  static Color card(ColorScheme cs) => cs.brightness == Brightness.light
      ? cs.surfaceContainerLowest
      : cs.surfaceContainer;

  static Color editor(ColorScheme cs) => cs.brightness == Brightness.light
      ? cs.surfaceContainerLow
      : cs.surfaceContainerHigh;
}

/// The rounded card holding the group rows, or the New group form
/// ([highlighted]: primary border and ring).
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GroupSurfaces.card(cs),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlighted ? cs.primary : cs.outlineVariant),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.16),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
