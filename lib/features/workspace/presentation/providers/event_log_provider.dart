import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_log_file.dart';
import '../../domain/event_log_line.dart';
import '../../domain/event_log_rows.dart';
import '../../domain/log_event.dart';

part 'event_log_provider.g.dart';

@Riverpod(keepAlive: true)
class EventLogNotifier extends _$EventLogNotifier {
  /// Rows, not events: a batch with its projector lines is one row. The log
  /// lives in memory only; 5000 rows are a few MB and a long show day, and
  /// the list builds only the rows on screen.
  static const maxRows = 5000;

  final _fileLines = EventLogFileLines();

  @override
  List<LogEvent> build() => [];

  void log(LogEvent event) {
    state = capLogRows([event, ...state], maxRows);
    // Clear and the row cap leave the file alone: it keeps the whole day.
    if (_fileLines.lineFor(event) case final line?) {
      AppLog.event(event.timestamp, line);
    }
  }

  void clear() {
    state = [];
  }
}
