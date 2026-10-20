import 'log_event.dart';
import 'projector_group.dart';
import 'projector_node.dart';

/// Why a command didn't get through to a projector it was sent to.
/// `sendCommand` only says whether it worked: a timeout, a refused login
/// and an `ERxxx` reply all come back as one failure.
const String commandFailedReason = 'no answer or refused';

/// Why a projector wasn't sent the command at all.
String commandSkipReason(ConnectionStatus status) => switch (status) {
  ConnectionStatus.unauthorized => 'wrong login',
  _ => 'offline',
};

/// The Projector column of a batch: the group when every projector is in
/// the same one (`Stage, 6 projectors`), otherwise `8 projectors`.
String batchTargetLabel(
  List<ProjectorNode> nodes,
  List<ProjectorGroup> groups,
) {
  final count = '${nodes.length} projectors';
  final groupIds = nodes.map((n) => n.groupId).toSet();
  if (groupIds.length != 1 || groupIds.first == null) return count;
  final group = groups.where((g) => g.id == groupIds.first).firstOrNull;
  return group == null ? count : '${group.name}, $count';
}

/// The Event text of a batch's projector line: `Sent`, `Failed: no answer
/// or refused`, `Skipped: offline`.
String batchLineMessage(CommandOutcome outcome, {String? reason}) =>
    switch (outcome) {
      CommandOutcome.sent => 'Sent',
      CommandOutcome.failed => 'Failed: $reason',
      CommandOutcome.skipped => 'Skipped: $reason',
    };

/// A command to a single projector: the command's name, with the reason
/// when it failed.
String singleCommandMessage(String cmd, {required bool success}) => success
    ? commandLabel(cmd)
    : '${commandLabel(cmd)} failed: $commandFailedReason';
