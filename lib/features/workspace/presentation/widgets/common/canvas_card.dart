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
    this.title,
    this.resetLabel,
    this.onReset,
    required this.body,
    required this.legend,
    this.pill,
    this.help,
    this.note,
    this.leading,
    this.actions,
  });

  /// Null leaves the header's left side to [leading] (Edge Blending).
  final String? title;
  final Widget? pill;

  /// Controls at the left of the header in place of [title] (Edge
  /// Blending's arrangement and swap in a pair); it gets what the right
  /// side leaves.
  final Widget? leading;

  /// A help icon before Reset (the corner hint in a small window).
  final Widget? help;

  /// The Reset text button's label; no Reset button when null.
  final String? resetLabel;

  /// Null disables Reset (while loading).
  final VoidCallback? onReset;

  /// Buttons at the right of the header, after [help] and in place of the
  /// Reset text button (Edge Blending's icon toggles and icon Reset).
  final List<Widget>? actions;
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
                        if (title != null)
                          Flexible(
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.cardTitle,
                            ),
                          ),
                        if (leading != null) Flexible(child: leading!),
                        if (pill != null) ...[
                          const SizedBox(width: 10),
                          Flexible(child: pill!),
                        ],
                      ],
                    ),
                  ),
                  ?help,
                  ...?actions,
                  if (actions == null && resetLabel != null)
                    TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(resetLabel!),
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
    // planned shrinks them rather than wrapping or cutting them off. The
    // line keeps its full height when they shrink, so a longer legend (Edge
    // Blending's Black Level tab) doesn't make the footer shorter and move
    // the drawing above it.
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: t.caption),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    final entries = SizedBox(
      height: lineHeight,
      child: FittedBox(
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
