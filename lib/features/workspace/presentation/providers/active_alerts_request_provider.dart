import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_alerts_request_provider.g.dart';

/// Asks the status bar to open Active alerts (a click on a desktop
/// notification). Counts up, so every request is a change the button sees.
@Riverpod(keepAlive: true)
class ActiveAlertsRequestNotifier extends _$ActiveAlertsRequestNotifier {
  @override
  int build() => 0;

  void open() => state++;
}
