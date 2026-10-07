import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/isolate_protocol_service.dart';
import '../../../../core/services/panasonic_protocol_service.dart';

part 'protocol_service_provider.g.dart';

/// The NTCONTROL client shared by the workspace. A provider rather than a
/// field so tests can override it with a fake that never opens a socket.
/// The real one runs on a worker isolate so polling doesn't stall the UI.
@Riverpod(keepAlive: true)
PanasonicProtocolService protocolService(Ref ref) {
  final service = IsolateProtocolService();
  ref.onDispose(service.dispose);
  return service;
}
