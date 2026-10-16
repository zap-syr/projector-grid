import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// The − / + buttons either side of a value slider (Brightness, Kelvin):
/// − in a muted red, + in a muted green, so they don't read as the card's
/// primary-coloured icon tile.
///
/// A click is one step. Held, the button repeats: [StepButton.slowSteps]
/// single steps first for fine control, then [StepButton.fastStride] steps
/// per tick to cross the range.
class StepButton extends StatefulWidget {
  const StepButton.minus({super.key, required this.onStep, this.tooltip})
    : plus = false;

  const StepButton.plus({super.key, required this.onStep, this.tooltip})
    : plus = true;

  /// Same delay as arrow-key stepping (KeyHoldRepeater).
  static const holdDelay = Duration(milliseconds: 400);
  static const repeatInterval = Duration(milliseconds: 50);

  /// Repeats at one step each before switching to [fastStride].
  static const slowSteps = 20;
  static const fastStride = 10;

  final bool plus;

  /// Called with how many steps to move; null disables the button.
  final ValueChanged<int>? onStep;
  final String? tooltip;

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  Timer? _holdTimer;
  Timer? _repeatTimer;
  int _repeats = 0;

  // The pointer already stepped on press; IconButton's own onPressed on
  // release must not step again. Keyboard activation still goes through it.
  bool _pointerDown = false;

  @override
  void didUpdateWidget(covariant StepButton old) {
    super.didUpdateWidget(old);
    // Reached the end of the range mid-hold.
    if (widget.onStep == null) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _press() {
    final onStep = widget.onStep;
    if (onStep == null) return;
    _pointerDown = true;
    onStep(1);
    _holdTimer = Timer(StepButton.holdDelay, () {
      _repeatTimer = Timer.periodic(StepButton.repeatInterval, (_) {
        _repeats++;
        widget.onStep?.call(
          _repeats > StepButton.slowSteps ? StepButton.fastStride : 1,
        );
      });
    });
  }

  void _stop() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeats = 0;
  }

  @override
  Widget build(BuildContext context) {
    final sc = AppStatusColors.of(context);
    final color = widget.plus ? sc.mutedPlus : sc.mutedMinus;
    final onStep = widget.onStep;
    return Listener(
      onPointerDown: (e) {
        if (e.buttons == kPrimaryButton) _press();
      },
      onPointerUp: (_) {
        _stop();
        // The Listener sees the up before IconButton's tap fires; clear the
        // flag after it, also when the release lands off the button and
        // onPressed never comes.
        scheduleMicrotask(() => _pointerDown = false);
      },
      onPointerCancel: (_) {
        _stop();
        _pointerDown = false;
      },
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: widget.tooltip,
          onPressed: onStep == null
              ? null
              : () {
                  if (!_pointerDown) onStep(1);
                },
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            disabledBackgroundColor: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
          icon: Icon(widget.plus ? Icons.add : Icons.remove, size: 18),
        ),
      ),
    );
  }
}
