import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_node.dart';

/// A small rounded pill: optional icon or dot, then a short label, tinted
/// with [color] on a faint fill of the same colour.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dot = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// A coloured dot before the label instead of an icon.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ] else if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.of(context).caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A group name with its colour dot, read-only.
class GroupPill extends StatelessWidget {
  const GroupPill({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: AppText.of(context).caption
                  .copyWith(color: cs.onSurface, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// The connection badge every dialog shares: Online, No login, Wrong login,
/// Offline.
class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    return switch (status) {
      ConnectionStatus.connected => StatusPill(
        label: 'Online',
        color: sc.success,
        dot: true,
      ),
      ConnectionStatus.unprotected => StatusPill(
        label: 'No login',
        color: cs.primary,
        icon: Icons.lock_open,
      ),
      ConnectionStatus.unauthorized => StatusPill(
        label: 'Wrong login',
        color: sc.warning,
        icon: Icons.lock_outline,
      ),
      ConnectionStatus.offline => StatusPill(
        label: 'Offline',
        color: cs.error,
        dot: true,
      ),
    };
  }
}
