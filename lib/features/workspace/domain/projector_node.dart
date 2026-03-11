import 'package:freezed_annotation/freezed_annotation.dart';

part 'projector_node.freezed.dart';

enum PowerStatus { on, standby }
enum ShutterStatus { open, closed }
enum ConnectionStatus { connected, offline }

@freezed
abstract class ProjectorNode with _$ProjectorNode {
  const factory ProjectorNode({
    required String id,
    required String name,
    required String ipAddress,
    required double x,
    required double y,
    @Default(false) bool isSelected,
    @Default(PowerStatus.standby) PowerStatus powerStatus,
    @Default(ShutterStatus.closed) ShutterStatus shutterStatus,
    @Default(ConnectionStatus.offline) ConnectionStatus connectionStatus,
  }) = _ProjectorNode;
}
