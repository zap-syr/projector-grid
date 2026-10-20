/// What the OSC server is doing: off, listening on a port, or its last
/// start failed to bind that port. The failure is kept for the session
/// only: the setting is written off so the next launch doesn't retry a
/// doomed port, but the status bar and Preferences still say why.
sealed class OscStatus {
  const OscStatus();
}

/// Not listening, and the last start didn't fail (never started, stopped,
/// or starting right now).
final class OscOff extends OscStatus {
  const OscOff();

  @override
  bool operator ==(Object other) => other is OscOff;

  @override
  int get hashCode => 0;
}

final class OscListening extends OscStatus {
  const OscListening(this.port);

  final int port;

  @override
  bool operator ==(Object other) => other is OscListening && other.port == port;

  @override
  int get hashCode => Object.hash(OscListening, port);
}

final class OscBindFailed extends OscStatus {
  const OscBindFailed(this.port);

  final int port;

  @override
  bool operator ==(Object other) =>
      other is OscBindFailed && other.port == port;

  @override
  int get hashCode => Object.hash(OscBindFailed, port);
}
