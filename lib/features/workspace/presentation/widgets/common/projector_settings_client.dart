import '../../../../../core/services/panasonic_protocol_service.dart';
import '../../../domain/geometry_values.dart';
import '../../../domain/projector_node.dart';

/// Read/write helper for the per-projector settings dialogs. They talk to the
/// projector directly rather than through workspace_provider's dispatch
/// (which logs to the Event Log), so every failed write goes to [onFailure]
/// to keep it from being silent.
class ProjectorSettingsClient {
  final PanasonicProtocolService service;
  final ProjectorNode node;
  final void Function(String cmd) onFailure;

  const ProjectorSettingsClient({
    required this.service,
    required this.node,
    required this.onFailure,
  });

  Future<String?> query(String cmd) => service.sendRawCommand(
    node.ipAddress,
    node.port,
    node.login,
    node.password,
    cmd,
  );

  /// Runs [cmds] in batches of [maxConcurrent], results in the same order.
  /// A wide burst stalls some queries on flagships and hits ERR3 outright
  /// on weaker models (see tool/projector_stress_test.dart).
  Future<List<String?>> queryAll(
    List<String> cmds, {
    int maxConcurrent = 8,
  }) async {
    final results = <String?>[];
    for (var i = 0; i < cmds.length; i += maxConcurrent) {
      final batch = cmds.sublist(i, (i + maxConcurrent).clamp(0, cmds.length));
      results.addAll(await Future.wait(batch.map(query)));
    }
    return results;
  }

  Future<String?> readValue(String key) async =>
      parseKeyedValue(await query('QVX:$key'), key);

  Future<int?> readInt(String key) async =>
      parseKeyedInt(await query('QVX:$key'), key);

  Future<double?> readDouble(String key) async =>
      parseKeyedDouble(await query('QVX:$key'), key);

  /// Sends [cmd]; reports and returns false when no reply came back.
  Future<bool> writeRaw(String cmd) async {
    final response = await query(cmd);
    if (response == null) {
      onFailure(cmd);
      return false;
    }
    return true;
  }

  Future<bool> writeInt(String key, int v) =>
      writeRaw('VXX:$key=${formatNtInt(v)}');

  Future<bool> writeDeg(String key, double v) =>
      writeRaw('VXX:$key=${formatNtDeg(v)}');

  Future<bool> writeThrow(String key, double v) =>
      writeRaw('VXX:$key=${formatNtThrow(v)}');

  Future<bool> writeBool(String key, bool on) => writeInt(key, on ? 1 : 0);
}
