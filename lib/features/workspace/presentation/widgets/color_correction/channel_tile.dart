import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// The square with a channel's letter (R, G, B) at the start of a row.
class ChannelTile extends StatelessWidget {
  const ChannelTile({super.key, required this.letter, required this.color});

  static const double size = 22;

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Text(
      letter,
      style: AppText.of(context).caption
          .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}
