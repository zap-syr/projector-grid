import 'package:freezed_annotation/freezed_annotation.dart';

part 'projector_node.freezed.dart';

enum PowerStatus { standby, turningOn, on, cooling }

enum ShutterStatus { open, closed }

enum ConnectionStatus { connected, offline, unauthorized, unprotected }

/// The worst of [statuses], for a badge that speaks for several projectors:
/// Offline, then Wrong login, then No login, then Online.
ConnectionStatus worstConnection(Iterable<ConnectionStatus> statuses) {
  int rank(ConnectionStatus s) => switch (s) {
    ConnectionStatus.connected => 0,
    ConnectionStatus.unprotected => 1,
    ConnectionStatus.unauthorized => 2,
    ConnectionStatus.offline => 3,
  };
  return statuses.reduce((a, b) => rank(b) > rank(a) ? b : a);
}

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

    /// A poll has tried this projector since it was loaded, added or
    /// re-addressed. Until then `offline` only means "not asked yet", which
    /// must not raise the Offline alert.
    @Default(false) bool polled,
    @Default('-') String serialNumber,
    @Default('-') String runtime,
    @Default('-') String lightRuntime,
    @Default('-') String intakeTemp,
    @Default('-') String exhaustTemp,
    @Default('-') String acVoltage,
    @Default('-') String errors,
    @Default('-') String input,
    @Default('-') String signal,

    /// Active test pattern as its `OTS:xx` command (`OTS:00` = off); null
    /// until first polled.
    String? testPattern,

    /// While offline: when the projector last answered a poll this session
    /// (Monitoring's "last seen 16:41"); null while it answers, and when it
    /// hasn't answered since the app started or it was re-addressed.
    /// Telemetry, so an undo never rolls it back.
    DateTime? lastSeen,
    String? groupId,
  }) = _ProjectorNode;
}
