import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';
import '../common/skeleton.dart';

/// The cards of this dialog share one padding (as Brightness Control).
class ColorCard extends StatelessWidget {
  const ColorCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DialogCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: child,
  );
}

/// Optional icon tile, title over subtitle, optional trailing widget (a
/// value, a lock pill, a segmented control). The heading row keeps the
/// tile's height with or without a tile, so cards line up.
class ColorCardHeading extends StatelessWidget {
  const ColorCardHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
  });

  final String title;

  /// Null while loading: a skeleton line in its place. Empty keeps the line.
  final String? subtitle;
  final IconData? icon;

  /// In place of the icon tile (the colour preview of the editor).
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final lead = leading ?? (icon == null ? null : DialogIconTile(icon!));
    return Row(
      spacing: 14,
      children: [
        ?lead,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.cardTitle,
              ),
              if (subtitle == null)
                // On a blank line of the same style, so the card keeps its
                // height between loading and loaded.
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Text(' ', style: t.description),
                    const SkeletonPulse(
                      child: Skeleton(width: 160, height: 12),
                    ),
                  ],
                )
              else
                Text(
                  // A space holds the line when there is nothing to say.
                  subtitle!.isEmpty ? ' ' : subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.description,
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
