import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/projector_node.dart';
import 'workspace_provider.dart';

part 'status_summary_provider.g.dart';

/// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
/// structural equality, so this only triggers a `StatusBar` rebuild when one
/// of the counts actually changes — not on every single-node telemetry tick
/// that leaves them all the same. Alert counts are `alertCountsProvider`'s.
/// [wrongLogin] is only for the health meter's amber part.
@riverpod
({int total, int online, int offline, int wrongLogin}) statusSummary(Ref ref) {
  final nodes = ref.watch(workspaceProvider);
  var online = 0;
  var offline = 0;
  var wrongLogin = 0;
  for (final n in nodes) {
    switch (n.connectionStatus) {
      case ConnectionStatus.connected || ConnectionStatus.unprotected:
        online++;
      case ConnectionStatus.offline:
        offline++;
      case ConnectionStatus.unauthorized:
        wrongLogin++;
    }
  }
  return (
    total: nodes.length,
    online: online,
    offline: offline,
    wrongLogin: wrongLogin,
  );
}
