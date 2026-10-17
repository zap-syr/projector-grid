import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'monitoring_panel_provider.g.dart';

/// The projector whose panel is open over the Monitoring view, or null.
/// Session only. Kept apart from `selectionProvider`: opening a panel here
/// mustn't change what the Controls view has selected.
@Riverpod(keepAlive: true)
class MonitoringPanelNotifier extends _$MonitoringPanelNotifier {
  @override
  String? build() => null;

  void open(String nodeId) => state = nodeId;

  void close() => state = null;
}
