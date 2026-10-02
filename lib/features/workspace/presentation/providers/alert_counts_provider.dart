import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/alerts.dart';
import 'alerts_provider.dart';

part 'alert_counts_provider.g.dart';

/// Alert counts for the status bar (and the OSC status counts). A record, so
/// Riverpod dedupes it and acknowledging one of many doesn't rebuild what
/// only shows totals that stayed the same.
@riverpod
AlertCounts alertCounts(Ref ref) =>
    countAlerts(ref.watch(alertsProvider).values);
