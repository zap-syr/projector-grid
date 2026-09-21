import 'package:freezed_annotation/freezed_annotation.dart';

part 'projector_node.freezed.dart';

enum PowerStatus { standby, turningOn, on, cooling }

enum ShutterStatus { open, closed }

enum ConnectionStatus { connected, offline, unauthorized, unprotected }

/// True when [raw] — either NTCONTROL's raw signal register or one of the
/// app's own formatted display fields — represents "no usable signal" rather
/// than a real reading. Shared by the poll cycle (deciding whether to fall
/// back to the web status page) and the preview overlay (deciding whether to
/// show a live-signal tag) so the two can't silently diverge on what counts
/// as unusable.
bool isUnusableSignalValue(String? raw) {
  if (raw == null || raw.isEmpty) return true;
  if (raw == '-' || raw == 'Timeout' || raw == 'ER401') return true;
  return raw.toUpperCase() == 'NO SIGNAL';
}

@freezed
abstract class ProjectorNode with _$ProjectorNode {
  const factory ProjectorNode({
    required String id,
    required String name,
    required String ipAddress,
    @Default(1024) int port,
    @Default('admin1') String login,
    @Default('panasonic') String password,
    required double x,
    required double y,
    @Default(PowerStatus.standby) PowerStatus powerStatus,
    @Default(ShutterStatus.closed) ShutterStatus shutterStatus,
    @Default(ConnectionStatus.offline) ConnectionStatus connectionStatus,
    @Default('-') String serialNumber,
    @Default('-') String runtime,
    @Default('-') String lightRuntime,
    @Default('-') String intakeTemp,
    @Default('-') String exhaustTemp,
    @Default('-') String acVoltage,
    @Default('-') String errors,
    @Default('-') String input,
    @Default('-') String signal,
    String? groupId,
  }) = _ProjectorNode;
}
