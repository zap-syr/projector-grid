import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import 'alert_row.dart';
import 'hover_panel.dart';
import 'projector_alert_panel.dart';

/// The alert icon in a card's status row, and the panel it opens on hover.
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
    final color = AlertPalette.icon(badge.severity);

    return HoverPanel(
      width: ProjectorAlertPanel.width,
      panel: (_) => ProjectorAlertPanel(node: node),
      builder: (_, active) => Semantics(
        label: '${badge.count} ${badge.count == 1 ? 'alert' : 'alerts'}',
        child: Opacity(
          opacity: badge.acknowledged ? 0.8 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 1,
              children: [
                Icon(
                  AlertPalette.iconData(
                    badge.severity,
                    filled: !badge.acknowledged,
                  ),
                  size: 14,
                  color: color,
                ),
                if (badge.count > 1)
                  Text(
                    '${badge.count}',
                    style: TextStyle(
                      fontSize: 10,
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
