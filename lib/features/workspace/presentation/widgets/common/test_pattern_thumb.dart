import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/test_patterns.dart';

/// A 20×12 preview of a test pattern in a hairline frame, for wherever the
/// active pattern is named: the canvas card, the Monitoring table and the
/// projector panel. A pattern without an icon shows a grid.
class TestPatternThumb extends StatelessWidget {
  const TestPatternThumb({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = kTestPatternIcons[code];
    return Container(
      width: 20,
      height: 12,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: icon != null
          ? SvgPicture.asset(icon, fit: BoxFit.cover)
          : Icon(Icons.grid_on, size: 10, color: cs.onSurfaceVariant),
    );
  }
}
