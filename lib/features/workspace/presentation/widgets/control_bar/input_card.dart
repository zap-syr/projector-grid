import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/control_options.dart';
import 'control_bar_parts.dart';

class InputCard extends ConsumerStatefulWidget {
  const InputCard({super.key});

  @override
  ConsumerState<InputCard> createState() => _InputCardState();
}

class _InputCardState extends ConsumerState<InputCard> {
  static final _items = dropdownItems(kInputOptions);
  String _input = 'IIS:HD1';

  @override
  Widget build(BuildContext context) {
    return ControlBarCard(
      icon: Icons.input,
      title: 'Input',
      child: DropdownSendRow<String>(
        items: _items,
        value: _input,
        onChanged: (v) => setState(() => _input = v),
        onSend: () => sendToSelected(ref, _input),
      ),
    );
  }
}
