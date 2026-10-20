import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/event_log_rows.dart';
import '../../domain/log_event.dart';

part 'event_log_provider.g.dart';

@Riverpod(keepAlive: true)
class EventLogNotifier extends _$EventLogNotifier {
  /// Rows, not events: a batch with its projector lines is one row. The log
  /// lives in memory only; 5000 rows are a few MB and a long show day, and
  /// the list builds only the rows on screen.
  static const maxRows = 5000;

  @override
  List<LogEvent> build() => [];

  void log(LogEvent event) {
    state = capLogRows([event, ...state], maxRows);
  }

  void clear() {
    state = [];
  }
}
