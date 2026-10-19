import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'monitoring_reveal_provider.g.dart';

/// A projector the Monitoring table or cards should scroll into view (the
/// quick status popover's *Show in Monitoring*), or null. Whichever view is
/// showing takes it and clears it, so switching Table / Cards afterwards
/// doesn't scroll again.
@Riverpod(keepAlive: true)
class MonitoringRevealNotifier extends _$MonitoringRevealNotifier {
  @override
  String? build() => null;

  void reveal(String nodeId) => state = nodeId;

  void consume() => state = null;
}
