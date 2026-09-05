import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/poll_status_provider.dart';
import '../providers/status_summary_provider.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(statusSummaryProvider);
    final pollStatus = ref.watch(pollStatusProvider);
    final total = summary.total;
    final online = summary.online;
    final offline = summary.offline;
    final warnings = summary.warnings;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _StatusItem(
            label: 'Projectors',
            count: total,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 16),
          _StatusItem(label: 'Online', count: online, color: Colors.green),
          const SizedBox(width: 16),
          _StatusItem(label: 'Offline', count: offline, color: Colors.red),
          const SizedBox(width: 16),
          _StatusItem(label: 'Warning', count: warnings, color: Colors.orange),
          const Spacer(),
          _RefreshStatusItem(pollStatus: pollStatus),
        ],
      ),
    );
  }
}

class _RefreshStatusItem extends StatelessWidget {
  final PollStatus pollStatus;

  const _RefreshStatusItem({required this.pollStatus});

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final label = pollStatus.isPolling
        ? 'Refreshing…'
        : pollStatus.lastCompletedAt != null
        ? 'Last refresh: ${_formatTime(pollStatus.lastCompletedAt!)}'
        : 'Last refresh: —';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pollStatus.isPolling)
          // The indeterminate spinner drives an AnimationController that marks
          // needs-paint every frame while a poll cycle is in flight. Without
          // this boundary that repaint bubbles up to the route layer and
          // re-rasterizes the whole page (toolbar, canvas grid, every card).
          const RepaintBoundary(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Icon(
            Icons.schedule,
            size: 14,
            color: textStyle?.color?.withValues(alpha: 0.7),
          ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $count', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
