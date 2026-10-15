import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// The − / + buttons either side of a value slider (Brightness, Kelvin):
/// − in a muted red, + in a muted green, so they don't read as the card's
/// primary-coloured icon tile.
class StepButton extends StatelessWidget {
  const StepButton.minus({super.key, required this.onPressed, this.tooltip})
    : plus = false;

  const StepButton.plus({super.key, required this.onPressed, this.tooltip})
    : plus = true;

  final bool plus;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final sc = AppStatusColors.of(context);
    final color = plus ? sc.mutedPlus : sc.mutedMinus;
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          disabledBackgroundColor: Theme.of(context).colorScheme.onSurface
              .withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        icon: Icon(plus ? Icons.add : Icons.remove, size: 18),
      ),
    );
  }
}
