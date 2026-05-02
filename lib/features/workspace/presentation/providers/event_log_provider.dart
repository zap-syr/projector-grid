import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/log_event.dart';

part 'event_log_provider.g.dart';

@Riverpod(keepAlive: true)
class EventLogNotifier extends _$EventLogNotifier {
  static const _maxEvents = 500;

  @override
  List<LogEvent> build() => [];

  void log(LogEvent event) {
    final next = [event, ...state];
    state = next.length > _maxEvents ? next.sublist(0, _maxEvents) : next;
  }

  void clear() {
    state = [];
  }
}
