import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'common/dialog_parts.dart';

// The value field next to a slider (72×32, visual rules §4: the one field
// below 40 px, so a row of sliders stays compact), with integrated up/down
// stepper buttons.
// Commits via Enter or focus loss; auto-selects text on focus so the user can
// overwrite immediately. Pass autofocus: true to request focus on first build.
class SleekStepperInput extends StatefulWidget {
  final String initialValue;
  final double min;
  final double max;
  final double step;
  final void Function(String) onValueChanged;
  final bool autofocus;

  const SleekStepperInput({
    super.key,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.onValueChanged,
    this.step = 1.0,
    this.autofocus = false,
  });

  @override
  State<SleekStepperInput> createState() => _SleekStepperInputState();
}

class _SleekStepperInputState extends State<SleekStepperInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  /// The text last reported, so the focus loss that follows Enter doesn't
  /// report the same value a second time.
  String? _committed;
  Timer? _stepDelayTimer;
  Timer? _stepRepeatTimer;

  @override
  void didUpdateWidget(SleekStepperInput old) {
    super.didUpdateWidget(old);
    // Sync controller when parent pushes a new value (e.g. slider drag),
    // but only while the field is not focused so we don't clobber user input.
    if (old.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _stepDelayTimer?.cancel();
    _stepRepeatTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      // Select all text after the frame so the field has fully processed focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      });
    } else if (_controller.text != _committed) {
      _commit();
    }
  }

  void _commit() {
    final raw = _controller.text.trim().replaceAll('+', '');
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      _controller.text = _committed = widget.initialValue;
      widget.onValueChanged(widget.initialValue);
      return;
    }
    final snapped = double.parse(
      ((parsed / widget.step).round() * widget.step).toStringAsFixed(1),
    ).clamp(widget.min, widget.max);
    final formatted = _format(snapped);
    _controller.text = _committed = formatted;
    widget.onValueChanged(formatted);
  }

  void _step(int delta) {
    // Unfocus first so any partially typed text is committed before stepping.
    if (_focusNode.hasFocus) _focusNode.unfocus();
    final raw = _controller.text.trim().replaceAll('+', '');
    final current = double.tryParse(raw) ?? widget.min;
    final stepped = double.parse(
      (current + delta * widget.step).toStringAsFixed(1),
    ).clamp(widget.min, widget.max);
    final formatted = _format(stepped);
    _controller.text = formatted;
    widget.onValueChanged(formatted);
  }

  void _startStepping(int delta) {
    _step(delta);
    _stepDelayTimer = Timer(const Duration(milliseconds: 400), () {
      _stepRepeatTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _step(delta);
      });
    });
  }

  void _stopStepping() {
    _stepDelayTimer?.cancel();
    _stepRepeatTimer?.cancel();
    _stepDelayTimer = null;
    _stepRepeatTimer = null;
  }

  String _format(double v) {
    final rounded = v.roundToDouble();
    if (v == rounded) return rounded.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final dividerColor = colorScheme.outlineVariant;
    final borderColor = _hasFocus ? colorScheme.primary : dividerColor;
    final arrowColor = t.secondary;

    return Container(
      width: 72,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: t.mono,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
          // Vertical divider between text field and stepper buttons.
          Container(width: 1, color: dividerColor),
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => _startStepping(1),
                    onTapUp: (_) => _stopStepping(),
                    onTapCancel: _stopStepping,
                    child: Center(
                      child: Icon(
                        Icons.arrow_drop_up,
                        size: 16,
                        color: arrowColor,
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: dividerColor),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => _startStepping(-1),
                    onTapUp: (_) => _stopStepping(),
                    onTapCancel: _stopStepping,
                    child: Center(
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: arrowColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
