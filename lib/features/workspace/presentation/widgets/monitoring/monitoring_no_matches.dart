import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../providers/monitoring_filter_provider.dart';

/// In place of the table's rows or the cards when the search and the quick
/// filter leave nothing, including a filter whose last projector just left
/// it: the filter is never reset on its own, so the view doesn't change
/// under the operator.
class MonitoringNoMatches extends ConsumerWidget {
  const MonitoringNoMatches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppText.of(context);
    return Center(
      child: Column(
        key: const ValueKey('monitoring-no-matches'),
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(
            'No projectors match',
            style: t.body.copyWith(color: t.secondary),
          ),
          OutlinedButton(
            onPressed: ref.read(monitoringFilterProvider.notifier).clear,
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}
