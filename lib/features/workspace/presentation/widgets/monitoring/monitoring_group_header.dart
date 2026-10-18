import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/monitoring_layout.dart';
import '../../../domain/monitoring_status.dart';
import '../../providers/monitoring_status_provider.dart';
import '../../providers/monitoring_view_provider.dart';
import 'monitoring_parts.dart';

/// A group's row above its projectors, a filled band in the table and the
/// cards alike: the collapse chevron, the group's colour, its name and a
/// summary (`8 projectors, 7 online, 1 needs attention`). Click to
/// collapse.
class MonitoringGroupHeader extends ConsumerWidget {
  const MonitoringGroupHeader({
    super.key,
    required this.section,
    required this.collapsed,
  });

  final MonitoringSection section;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    // A string, so only a change in what it says rebuilds the row.
    final summary = ref.watch(
      monitoringStatusProvider.select(
        (all) => monitoringGroupSummary([
          for (final id in section.nodeIds) ?all[id],
        ]),
      ),
    );
    return Material(
      color: cs.surfaceContainer,
      child: InkWell(
        onTap: () => ref
            .read(monitoringViewProvider.notifier)
            .toggleCollapsed(section.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: t.secondary,
              ),
              const SizedBox(width: 6),
              GroupSwatch(group: section.group),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  section.group?.name ?? 'Ungrouped',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.description,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
