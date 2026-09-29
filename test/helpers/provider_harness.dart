import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/poll_status_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import 'fake_protocol_service.dart';

/// A container wired to [fake]. The auto-dispose providers the workspace
/// depends on are kept alive for the whole test, as the UI watching them does
/// in the app — otherwise they'd reset between reads.
ProviderContainer makeContainer(FakeProtocolService fake) {
  final container = ProviderContainer(
    overrides: [protocolServiceProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  container.listen(workspaceProvider, (_, _) {});
  container.listen(selectionProvider, (_, _) {});
  container.listen(pollStatusProvider, (_, _) {});
  return container;
}

ProjectorNode node(
  String id, {
  String? ip,
  double x = 40,
  double y = 40,
  ConnectionStatus status = ConnectionStatus.connected,
  String? groupId,
}) => ProjectorNode(
  id: id,
  name: 'Proj $id',
  ipAddress: ip ?? '10.0.0.$id',
  x: x,
  y: y,
  connectionStatus: status,
  groupId: groupId,
);

/// Drags [id] by [delta] the same way the workspace canvas does.
void drag(ProviderContainer c, String id, Offset delta) {
  final notifier = c.read(workspaceProvider.notifier);
  final start = {
    for (final n in c.read(workspaceProvider)) n.id: Offset(n.x, n.y),
  };
  notifier.saveBeforeMove();
  notifier.setNodePositionsFromDrag(id, delta, start);
  notifier.endMove();
}
