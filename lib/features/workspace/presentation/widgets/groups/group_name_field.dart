import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/group_naming.dart';
import '../common/dialog_parts.dart';

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
    final t = AppText.of(context);
    final preview = previewColor;
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      // A formatter, not maxLength: maxLength draws its own counter under
      // the field, and the counter here sits in the label row instead.
      inputFormatters: [LengthLimitingTextInputFormatter(maxGroupNameLength)],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: plainFieldStyle,
      decoration: dialogFieldDecoration(
        context,
        error: errorText != null,
      ).copyWith(errorText: errorText),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.label)),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => Text(
                '${value.text.length} / $maxGroupNameLength',
                style: t.caption,
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
