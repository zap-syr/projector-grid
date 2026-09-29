import 'package:flutter/material.dart';

/// Leading slot of a dropdown menu row. Every row — plain action, checkable
/// toggle, or submenu — reserves the width a checkmark would take, so labels
/// line up on one edge whether or not that row ever shows a check.
class MenuCheckGutter extends StatelessWidget {
  const MenuCheckGutter({super.key, this.checked = false});

  final bool checked;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    child: checked ? const Icon(Icons.check, size: 14) : null,
  );
}
