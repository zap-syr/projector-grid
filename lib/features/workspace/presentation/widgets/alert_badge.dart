import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import 'alert_row.dart';
import 'hover_panel.dart';
import 'projector_alert_panel.dart';

/// The alert badge on the right of a card's header, and the panel it opens
/// on hover: amber for a warning, red for an error, the count from two up.
///
/// A click on the badge is a click on the card: it selects, it doesn't pin
/// the panel (decided 2026-10-02 after an unseen pinned panel read as
/// stuck).
class AlertBadge extends ConsumerWidget {
  const AlertBadge({super.key, required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(
      alertsProvider.select(
        (alerts) => alertBadge(alerts.values.where((a) => a.nodeId == node.id)),
      ),
    );
    if (badge == null) return const SizedBox.shrink();
    final sc = AppStatusColors.of(context);
    final color = badge.recovered
        ? sc.success
        : badge.severity == AlertSeverity.critical
        ? Theme.of(context).colorScheme.error
        : sc.warning;

    return HoverPanel(
      width: ProjectorAlertPanel.width,
      panel: (_) => ProjectorAlertPanel(node: node),
      builder: (_, active) => Semantics(
        label: '${badge.count} ${badge.count == 1 ? 'alert' : 'alerts'}',
        child: Opacity(
          opacity: badge.acknowledged ? 0.8 : 1,
          child: Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.3 : 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Icon(
                  badge.recovered
                      ? Icons.check_circle
                      : AlertPalette.iconData(
                          badge.severity,
                          filled: !badge.acknowledged,
                        ),
                  size: 14,
                  color: color,
                ),
                if (badge.count > 1)
                  Text(
                    '${badge.count}',
                    style: AppText.of(context).caption.copyWith(
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
