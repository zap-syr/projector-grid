import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/group_naming.dart';

/// Group name input: label with a `9 / 24` counter on the right, and an
/// optional colour preview square left of the field (the New group forms).
class GroupNameField extends StatelessWidget {
  const GroupNameField({
    super.key,
    required this.controller,
    required this.label,
    this.previewColor,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final Color? previewColor;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final preview = previewColor;
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      // A formatter, not maxLength: maxLength draws its own counter under
      // the field, and the counter here sits in the label row instead.
      inputFormatters: [LengthLimitingTextInputFormatter(maxGroupNameLength)],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isDense: true,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => Text(
                '${value.text.length} / $maxGroupNameLength',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (preview == null)
          field
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preview,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: field),
            ],
          ),
      ],
    );
  }
}
