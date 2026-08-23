import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'poll_status_provider.g.dart';

/// When the workspace last completed a full telemetry poll cycle, and
/// whether one is currently in flight.
class PollStatus {
  final DateTime? lastCompletedAt;
  final bool isPolling;

  const PollStatus({this.lastCompletedAt, this.isPolling = false});

  PollStatus copyWith({DateTime? lastCompletedAt, bool? isPolling}) {
    return PollStatus(
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

/// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
/// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
/// undo/redo snapshots or project-file serialization.
@riverpod
class PollStatusNotifier extends _$PollStatusNotifier {
  @override
  PollStatus build() => const PollStatus();

  void started() => state = state.copyWith(isPolling: true);

  void completed() =>
      state = PollStatus(lastCompletedAt: DateTime.now(), isPolling: false);
}
