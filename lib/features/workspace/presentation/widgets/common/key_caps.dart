import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// One keyboard key drawn as a solid cap in monospace (`Ctrl`, `S`, `⇧`).
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key, this.small = false});

  final String label;

  /// The tooltip's size; the Keyboard Shortcuts list uses the regular one.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    return Container(
      constraints: BoxConstraints(minWidth: small ? 18 : 22),
      height: small ? 18 : 22,
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7),
      // As the mockup: a solid cap, 1 px border and a dark lip under it.
      decoration: BoxDecoration(
        color: sc.keyCap,
        borderRadius: BorderRadius.circular(small ? 4 : 6),
        border: Border.all(color: sc.keyCapBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), offset: Offset(0, 1)),
        ],
      ),
      // Not `alignment:` on the Container: that makes it take the full
      // width it is given, so in a fixed-width column every cap stretched
      // to the column and they stacked one per line.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppTheme.mono(
            TextStyle(
              fontSize: small ? 10.5 : 11.5,
              height: 1,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// A key combination: one cap per key, no "+" between them.
class KeyCaps extends StatelessWidget {
  const KeyCaps(this.keys, {super.key, this.small = false});

  final List<String> keys;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: small ? 3 : 4,
      children: [for (final k in keys) KeyCap(k, small: small)],
    );
  }
}
