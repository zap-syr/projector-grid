/// Where a command came from (plan §7k.2).
enum CommandSourceKind { controlBar, shortcut, osc, schedule, web, retry }

/// Where a command came from, kept structured so the log's *Web* chip can
/// tell the Web page's commands apart without reading the text, and lens
/// steps fold only when they came from the same place.
class CommandSource {
  final CommandSourceKind kind;

  /// The scheduled task's name for [CommandSourceKind.schedule].
  final String? taskName;

  /// The page's address and role for [CommandSourceKind.web].
  final String? webIp;
  final String? webRole;

  /// The OSC sender's address for [CommandSourceKind.osc].
  final String? oscSender;

  const CommandSource._(
    this.kind, {
    this.taskName,
    this.webIp,
    this.webRole,
    this.oscSender,
  });

  static const controlBar = CommandSource._(CommandSourceKind.controlBar);
  static const shortcut = CommandSource._(CommandSourceKind.shortcut);
  static const osc = CommandSource._(CommandSourceKind.osc);
  static const retry = CommandSource._(CommandSourceKind.retry);

  const CommandSource.oscFrom(String sender)
    : this._(CommandSourceKind.osc, oscSender: sender);

  const CommandSource.schedule(String name)
    : this._(CommandSourceKind.schedule, taskName: name);

  const CommandSource.web({required String ip, required String role})
    : this._(CommandSourceKind.web, webIp: ip, webRole: role);

  /// The line in the Event column after the command: *from the control
  /// bar*, *from OSC, 10.0.0.20*, *from scheduled task "Evening shutdown"*,
  /// *from Web, 10.0.0.5 (operator)*.
  String get label => switch (kind) {
    CommandSourceKind.controlBar => 'from the control bar',
    CommandSourceKind.shortcut => 'from a keyboard shortcut',
    CommandSourceKind.osc =>
      oscSender == null ? 'from OSC' : 'from OSC, $oscSender',
    CommandSourceKind.schedule => 'from scheduled task "$taskName"',
    CommandSourceKind.web => 'from $webText',
    CommandSourceKind.retry => 'from retry',
  };

  /// `Web, 10.0.0.5 (operator)`: also how other Web lines name the page.
  String get webText => 'Web, $webIp ($webRole)';

  @override
  bool operator ==(Object other) =>
      other is CommandSource &&
      other.kind == kind &&
      other.taskName == taskName &&
      other.webIp == webIp &&
      other.webRole == webRole &&
      other.oscSender == oscSender;

  @override
  int get hashCode => Object.hash(kind, taskName, webIp, webRole, oscSender);
}
