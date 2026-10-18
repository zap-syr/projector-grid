import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/monitoring_filter.dart';

part 'monitoring_filter_provider.g.dart';

/// The Monitoring bar's search and quick filter ([MonitoringFilter]); kept
/// for the session, not saved.
@Riverpod(keepAlive: true)
class MonitoringFilterNotifier extends _$MonitoringFilterNotifier {
  @override
  MonitoringFilter build() => const MonitoringFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setQuick(MonitoringQuickFilter quick) =>
      state = state.copyWith(quick: quick);

  /// Show all: no search, All.
  void clear() => state = const MonitoringFilter();
}

/// Ctrl+F's request to focus the Monitoring search field. A counter, so a
/// second request while the first is pending still notifies.
@Riverpod(keepAlive: true)
class MonitoringSearchFocusNotifier extends _$MonitoringSearchFocusNotifier {
  @override
  int build() => 0;

  void request() => state++;
}
