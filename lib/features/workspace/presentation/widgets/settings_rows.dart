import 'package:flutter/material.dart';

/// Building blocks of the Preferences dialog: titled groups of label/control
/// rows, the same layout Windows Settings and macOS System Settings use, so
/// labels line up down the left and controls down the right.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.dimmed = false,
  });

  final String title;
  final List<Widget> children;

  /// Fades the rows while their service is off. They stay editable so the
  /// service can be configured before it's switched on.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SettingsPanel(
          child: Opacity(
            opacity: dimmed ? 0.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in children.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  row,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The bordered, slightly lifted surface behind a [SettingsGroup] and the
/// service header card.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.control,
    this.hint,
    this.error,
    this.controlWidth = 240,
    this.indented = false,
    this.enabled = true,
  });

  final String label;
  final Widget control;

  /// Short note under the label; replaced by [error] when that is set.
  final String? hint;
  final String? error;

  /// Fill-width controls (fields, dropdowns) take this width; intrinsic ones
  /// (switches, segmented buttons) sit right-aligned inside it.
  final double controlWidth;

  /// Marks a row that depends on the one above it.
  final bool indented;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = error ?? hint;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 40 : 16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium),
                    if (note != null)
                      Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: error != null
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: controlWidth,
              child: Align(alignment: Alignment.centerRight, child: control),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
