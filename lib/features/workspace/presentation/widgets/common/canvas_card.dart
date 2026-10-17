import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'dialog_parts.dart';

/// The left-hand card of the canvas dialogs (Geometry Correction, Edge
/// Blending): a header (title, pill, optional help icon, a Reset text
/// button), the drawing, and a footer with the legend and a note. One
/// shell, so the card is the same in every mode and while a mode loads.
class CanvasCard extends StatelessWidget {
  const CanvasCard({
    super.key,
    required this.title,
    required this.resetLabel,
    required this.onReset,
    required this.body,
    required this.legend,
    this.pill,
    this.help,
    this.note,
  });

  final String title;
  final Widget? pill;

  /// A help icon before Reset (the corner hint in a small window).
  final Widget? help;
  final String resetLabel;

  /// Null disables Reset (while loading).
  final VoidCallback? onReset;
  final Widget body;
  final Widget legend;
  final Widget? note;

  static const double headerHeight = 46;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.6),
    );
    return DialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  // Title and pill share what Reset leaves, half each at
                  // most, so neither is cut in a small window.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.cardTitle,
                          ),
                        ),
                        if (pill != null) ...[
                          const SizedBox(width: 10),
                          Flexible(child: pill!),
                        ],
                      ],
                    ),
                  ),
                  ?help,
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(resetLabel),
                  ),
                ],
              ),
            ),
          ),
          divider,
          Expanded(child: body),
          divider,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [legend, ?note],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of legend entries, each a 16×10 swatch and a label. [trailing]
/// sits at the right end (the `Approximate` note in a small window).
class CanvasLegend extends StatelessWidget {
  const CanvasLegend({super.key, required this.items, this.trailing});

  final List<(Widget swatch, String label)> items;
  final Widget? trailing;

  static const Size swatchSize = Size(16, 10);

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    // One line always: the entries fit at their size, and a font wider than
    // planned shrinks them rather than wrapping or cutting them off.
    final entries = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (swatch, label)) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            SizedBox.fromSize(size: swatchSize, child: swatch),
            const SizedBox(width: 6),
            Text(label, maxLines: 1, style: t.caption),
          ],
        ],
      ),
    );
    return Row(
      children: [
        Expanded(child: entries),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// An info icon and a line of text under the legend.
class CanvasNote extends StatelessWidget {
  const CanvasNote({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 16, color: t.secondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DefaultTextStyle.merge(style: t.description, child: child),
        ),
      ],
    );
  }
}
