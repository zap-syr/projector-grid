import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

class SegmentedTab<T> {
  const SegmentedTab({
    required this.value,
    required this.label,
    this.icon,
    this.pill,
    this.content,
  });

  final T value;

  /// Shown, or with [content] read out by a screen reader.
  final String label;
  final IconData? icon;

  /// A short state shown in a pill after the label (`3 colors`, `Off`), so
  /// each tab's state is visible without switching to it.
  final String? pill;

  /// What the tab shows in place of icon, label and pill, given whether it
  /// is the selected one (Edge Blending's A / B tabs: letter, IP in mono,
  /// status dot). The track, raised tab and its animation stay the strip's.
  final Widget Function(BuildContext context, bool selected)? content;
}

/// The pill tab strip shared by the dialogs and the control bar: a rounded
/// track with the selected tab raised on it.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.expand = true,
  });

  final List<SegmentedTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Tabs share the full width; otherwise each takes its own width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final t in tabs)
            if (expand) Expanded(child: _tab(context, t)) else _tab(context, t),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, SegmentedTab<T> t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = AppText.of(context);
    final isSelected = t.value == selected;
    final fg = isSelected ? cs.onSurface : cs.onSurfaceVariant;
    // Raised above the track: white in light, a lighter step in dark (the
    // lowest container is the darkest there).
    final raised = theme.brightness == Brightness.light
        ? cs.surfaceContainerLowest
        : Color.alphaBlend(
            cs.onSurface.withValues(alpha: 0.10),
            cs.surfaceContainerHighest,
          );
    final content = t.content;
    return Semantics(
      selected: isSelected,
      button: true,
      label: content == null ? null : t.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: isSelected ? null : () => onChanged(t.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            // No shadow: a BoxShadow paints a blurred filled box under the
            // whole tab, which showed through as a dark flash while the fill
            // of the tab being left faded out. A border lifts the selected
            // tab instead; every tab has one (transparent when not selected)
            // so the width never changes, and both fade to the same colour at
            // zero alpha rather than to null.
            decoration: BoxDecoration(
              color: isSelected ? raised : raised.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected
                    ? cs.outlineVariant
                    : cs.outlineVariant.withValues(alpha: 0),
              ),
            ),
            child: content != null
                ? ExcludeSemantics(child: content(context, isSelected))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (t.icon != null) ...[
                        Icon(t.icon, size: 16, color: fg),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.body.copyWith(
                            color: fg,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (t.pill != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.pill!,
                            style: text.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
