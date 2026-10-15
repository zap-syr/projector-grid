import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/ip_input.dart';
import '../common/dialog_parts.dart';

/// The NTCONTROL port field of Add Projectors and Edit Projector.
class PortField extends StatelessWidget {
  const PortField({
    super.key,
    required this.controller,
    this.showDefault = true,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// "Default 1024" under the field; an out-of-range port shows its error
  /// either way.
  final bool showDefault;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final valid = parsePort(controller.text) != null;
    return LabeledField(
      label: 'Port',
      help: !valid
          ? const FieldHelp('1 to 65535', tone: FieldHelpTone.error)
          : showDefault
          ? const FieldHelp('Default $defaultNtcontrolPort')
          : null,
      child: TextField(
        key: const ValueKey('port'),
        controller: controller,
        style: monoFieldStyle,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        decoration: dialogFieldDecoration(context, error: !valid),
        onSubmitted: (_) => onSubmitted?.call(),
      ),
    );
  }
}
