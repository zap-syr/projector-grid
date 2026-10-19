import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/schedule_labels.dart';
import '../common/dialog_parts.dart';

/// The time of day as one `08:00` field. Digits only, the colon goes in by
/// itself; a whole time is reported as it is typed, and on leaving the
/// field a short entry is completed (`8` → `08:00`) or, if it can't be read,
/// the last time comes back.
class TaskTimeField extends StatefulWidget {
  const TaskTimeField({
    super.key,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  State<TaskTimeField> createState() => _TaskTimeFieldState();
}

class _TaskTimeFieldState extends State<TaskTimeField> {
  late final _ctrl = TextEditingController(
    text: formatHm(widget.hour, widget.minute),
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(TaskTimeField old) {
    super.didUpdateWidget(old);
    if ((old.hour != widget.hour || old.minute != widget.minute) &&
        !_focusNode.hasFocus) {
      _ctrl.text = formatHm(widget.hour, widget.minute);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = parseTypedTime(_ctrl.text);
    final (h, m) = parsed ?? (widget.hour, widget.minute);
    _ctrl.text = formatHm(h, m);
    if (parsed != null) widget.onChanged(h, m);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      style: monoFieldStyle,
      inputFormatters: [_TimeInputFormatter()],
      decoration: dialogFieldDecoration(context, prefixIcon: Icons.schedule),
      onChanged: (text) {
        // Only a whole time while typing: `1` on its way to `13:00` must
        // not jump the schedule to 01:00.
        if (text.length == 5) {
          final parsed = parseTypedTime(text);
          if (parsed != null) widget.onChanged(parsed.$1, parsed.$2);
        }
      },
      onSubmitted: (_) => _commit(),
    );
  }
}

/// `8`, `08`, `830`, `0830` or `08:30` as (hour, minute); null when it isn't
/// a time of day.
(int, int)? parseTypedTime(String text) {
  final digits = text.replaceAll(':', '');
  if (digits.isEmpty || digits.length > 4) return null;
  final int hour;
  final int minute;
  if (digits.length <= 2) {
    hour = int.parse(digits);
    minute = 0;
  } else {
    hour = int.parse(digits.substring(0, digits.length - 2));
    minute = int.parse(digits.substring(digits.length - 2));
  }
  if (hour > 23 || minute > 59) return null;
  return (hour, minute);
}

/// Digits only, at most four, with the colon after the hour.
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final digits = value.text.replaceAll(RegExp(r'[^0-9]'), '');
    final kept = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = kept.length > 2
        ? '${kept.substring(0, 2)}:${kept.substring(2)}'
        : kept;
    return value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
