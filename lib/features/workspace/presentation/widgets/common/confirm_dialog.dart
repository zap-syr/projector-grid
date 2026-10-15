import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// One consequence in a [ConfirmDialog]'s "What changes" box: [lead] in
/// bold (or monospace for an address), then the rest of the sentence.
class ConfirmChange {
  const ConfirmChange({
    required this.icon,
    required this.lead,
    this.rest = '',
    this.monoLead = false,
  });

  final IconData icon;
  final String lead;
  final String rest;
  final bool monoLead;
}

enum ConfirmActionKind { text, filled, destructive }

class ConfirmAction<T> {
  const ConfirmAction({
    required this.label,
    required this.value,
    this.kind = ConfirmActionKind.text,
  });

  final String label;
  final T value;
  final ConfirmActionKind kind;
}

/// The one confirmation layout of the app: round icon, title, a short line,
/// an optional "What changes" box and the buttons. No title bar and no ✕:
/// it is answered with the buttons or Esc (which returns null).
class ConfirmDialog<T> extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.actions,
    this.subtitle,
    this.changes = const [],
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<ConfirmChange> changes;
  final List<ConfirmAction<T>> actions;

  /// Error-coloured icon; the neutral variant uses the primary colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: destructive
                          ? cs.errorContainer
                          : cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: destructive ? cs.error : cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ).copyWith(color: cs.onSurface),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (changes.isNotEmpty) ...[
                const SizedBox(height: 18),
                _ChangesBox(changes: changes),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (i, a) in actions.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _button(context, a),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(BuildContext context, ConfirmAction<T> a) {
    void pop() => Navigator.of(context).pop(a.value);
    final cs = Theme.of(context).colorScheme;
    return switch (a.kind) {
      ConfirmActionKind.text => TextButton(
        onPressed: pop,
        child: Text(a.label),
      ),
      ConfirmActionKind.filled => FilledButton(
        autofocus: true,
        onPressed: pop,
        child: Text(a.label),
      ),
      ConfirmActionKind.destructive => FilledButton(
        autofocus: true,
        style: FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
        ),
        onPressed: pop,
        child: Text(a.label),
      ),
    };
  }
}

class _ChangesBox extends StatelessWidget {
  const _ChangesBox({required this.changes});

  final List<ConfirmChange> changes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What changes',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          for (final c in changes) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(c.icon, size: 16, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        TextSpan(
                          text: c.lead,
                          style: c.monoLead
                              ? AppTheme.mono(body)
                              : const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (c.rest.isNotEmpty) TextSpan(text: ' ${c.rest}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A two-button destructive confirmation; true only when confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? subtitle,
  IconData icon = Icons.delete_outline,
  List<ConfirmChange> changes = const [],
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog<bool>(
      icon: icon,
      title: title,
      subtitle: subtitle,
      changes: changes,
      destructive: true,
      actions: [
        ConfirmAction(label: cancelLabel, value: false),
        ConfirmAction(
          label: confirmLabel,
          value: true,
          kind: ConfirmActionKind.destructive,
        ),
      ],
    ),
  );
  return result ?? false;
}
