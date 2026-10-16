import 'package:flutter/material.dart';

import '../common/dialog_parts.dart';
import 'geometry_parts.dart';

/// *Throw ratio* with its range and the 40 px field.
class ThrowRatioRow extends StatelessWidget {
  const ThrowRatioRow({super.key, required this.value, required this.onCommit});

  final double value;
  final ValueChanged<double> onCommit;

  @override
  Widget build(BuildContext context) => GeometrySettingRow(
    title: 'Throw ratio',
    description: '0.7 to 16.5, match the lens in use',
    control: ThrowRatioField(value: value, onCommit: onCommit),
  );
}

/// The lens throw ratio: a standalone 40 px field (visual rules §4), not
/// the slider stepper. Commits on Enter or focus loss, held to 0.7 to 16.5
/// in tenths; an unreadable entry goes back to the current value.
class ThrowRatioField extends StatefulWidget {
  const ThrowRatioField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final double value;
  final ValueChanged<double> onCommit;

  static const double min = 0.7;
  static const double max = 16.5;

  @override
  State<ThrowRatioField> createState() => _ThrowRatioFieldState();
}

class _ThrowRatioFieldState extends State<ThrowRatioField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();

  static String _format(double v) => v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(ThrowRatioField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = _format(widget.value);
      return;
    }
    final v = ((parsed * 10).round() / 10).clamp(
      ThrowRatioField.min,
      ThrowRatioField.max,
    );
    _controller.text = _format(v);
    if (v != widget.value) widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        style: monoFieldStyle,
        textAlign: TextAlign.end,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: dialogFieldDecoration(context),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
