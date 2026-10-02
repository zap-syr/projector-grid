import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings_provider.dart';

part 'event_log_request_provider.g.dart';

/// A request from elsewhere in the app (an alert panel's *Event log* button)
/// for the event log to show, search for [query] and, with [alertsOnly],
/// switch to its Alerts tab. [id] grows with every request, so asking for
/// the same thing twice still reaches the panel.
typedef EventLogRequest = ({String query, bool alertsOnly, int id});

@Riverpod(keepAlive: true)
class EventLogRequestNotifier extends _$EventLogRequestNotifier {
  @override
  EventLogRequest? build() => null;

  /// Opens the log panel searching for [query] (a projector's IP).
  void show({String query = '', bool alertsOnly = false}) {
    ref.read(appSettingsProvider.notifier).setShowLogs(true);
    state = (query: query, alertsOnly: alertsOnly, id: (state?.id ?? 0) + 1);
  }

  /// Called by the panel once applied, so reopening the log later doesn't
  /// bring back an old search.
  void handled() => state = null;
}
