import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'dialog_parts.dart';

/// A setting fixed by another one (Brightness' Max light output by the
/// operating mode, Color Temperature by Color Matching): a neutral pill with
/// a lock, never amber (visual rules §5).
class LockPill extends StatelessWidget {
  const LockPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(Icons.lock_outline, size: 14, color: t.secondary),
          Text(
            label,
            style: t.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: t.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
