import 'package:freezed_annotation/freezed_annotation.dart';

part 'projector_node.freezed.dart';

enum PowerStatus { on, standby }
enum ShutterStatus { open, closed }
enum ConnectionStatus { connected, offline, unauthorized }

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
    @Default(false) bool isSelected,
    @Default(PowerStatus.standby) PowerStatus powerStatus,
    @Default(ShutterStatus.closed) ShutterStatus shutterStatus,
    @Default(ConnectionStatus.offline) ConnectionStatus connectionStatus,
    @Default('-') String serialNumber,
    @Default('-') String runtime,
    @Default('-') String intakeTemp,
    @Default('-') String exhaustTemp,
    @Default('-') String acVoltage,
    @Default('-') String errors,
    @Default('-') String input,
    @Default('-') String signal,
    String? groupId,
  }) = _ProjectorNode;
}
