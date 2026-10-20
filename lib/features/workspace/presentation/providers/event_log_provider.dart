import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/event_log_rows.dart';
import '../../domain/log_event.dart';

part 'event_log_provider.g.dart';

@Riverpod(keepAlive: true)
class EventLogNotifier extends _$EventLogNotifier {
  /// Rows, not events: a batch with its projector lines is one row.
  static const maxRows = 500;

  @override
  List<LogEvent> build() => [];

  void log(LogEvent event) {
    state = capLogRows([event, ...state], maxRows);
  }

  void clear() {
    state = [];
  }
}
