import 'command_source.dart';

export 'command_source.dart';

enum LogSeverity { error, warning, info, success }

enum LogEventType { connectivity, command, osc, web, alert }

/// What happened to a command at one projector.
enum CommandOutcome { sent, failed, skipped }

/// One command sent to several projectors (plan §7k.3). Every event of the
/// batch holds the same instance, so the log can build the batch's row
/// from whichever of its events arrives first.
class CommandBatch {
  final String id;

  /// The NTCONTROL command, kept for *Retry failed*.
  final String command;
  final CommandSource source;

  /// The Projector column: `Stage, 6 projectors` or `8 projectors`.
  final String target;

  /// Every projector of the batch: the ones sent to, then the skipped ones,
  /// each in workspace order. Orders the projector lines.
  final List<String> nodeIds;

  const CommandBatch({
    required this.id,
    required this.command,
    required this.source,
    required this.target,
    required this.nodeIds,
  });
}

/// The kind of event that folds across projectors into one row (plan
/// §7k.2): the same kind, not the same text, so *Back after 3 s* and *Back
/// after 4 s* fold together.
class LogGroupKind {
  /// What makes two events the same kind: `online`, `offline`, `auth`,
  /// `signal-lost raised`, …
  final String key;

  /// The folded row's Event text: *Came online*, *Signal lost*.
  final String title;

  const LogGroupKind(this.key, this.title);

  static const online = LogGroupKind('online', 'Came online');
  static const offline = LogGroupKind('offline', 'Went offline');
  static const auth = LogGroupKind('auth', 'Authentication failed');
}

class LogEvent {
  final DateTime timestamp;
  final LogSeverity severity;
  final LogEventType type;
  final String message;
  final String? projectorIp;
  final String? projectorName;

  /// Where a command came from, on command rows.
  final CommandSource? source;

  /// Set on a batch's projector lines and its summary.
  final CommandBatch? batch;

  /// A command's result at one projector: on a batch's projector lines and
  /// on a command to a single projector. Null on a batch's summary.
  final CommandOutcome? outcome;

  /// The projector the event is about, where it is known: the row looks
  /// at it to tell one projector's events from another's.
  final String? nodeId;

  /// The NTCONTROL command of a command to one projector and of an OSC
  /// address line, so the log can fold lens steps.
  final String? command;

  /// Set where events of several projectors at once fold into one row.
  final LogGroupKind? groupKind;

  /// The projector's own text in an opened group (*Back after 3 s*); the
  /// message when null.
  final String? groupDetail;

  /// The project group the projector was in, for a folded row's
  /// Projector column (*Stage, 6 projectors*).
  final String? projectorGroup;

  /// Who sent an OSC address line.
  final String? oscSender;

  LogEvent({
    required this.severity,
    required this.type,
    required this.message,
    this.projectorIp,
    this.projectorName,
    this.source,
    this.batch,
    this.outcome,
    this.nodeId,
    this.command,
    this.groupKind,
    this.groupDetail,
    this.projectorGroup,
    this.oscSender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// A batch's closing event, written after the last reply.
  bool get isBatchSummary => batch != null && outcome == null;
}

/// A *Lens Shift* step, H or V, either direction: the nudges the log folds
/// into one row.
bool isLensShiftCommand(String? cmd) =>
    cmd != null &&
    (cmd.startsWith('VXX:LNSI2=') || cmd.startsWith('VXX:LNSI3='));

String commandLabel(String cmd) {
  const labels = <String, String>{
    'PON': 'Power On',
    'POF': 'Power Standby',
    'OSH:0': 'Shutter Open',
    'OSH:1': 'Shutter Close',
    'OOS:1': 'OSD On',
    'OOS:0': 'OSD Off',
    'IIS:HD1': 'Input HDMI 1',
    'IIS:HD2': 'Input HDMI 2',
    'IIS:SD1': 'Input SDI 1',
    'IIS:SD2': 'Input SDI 2',
    'IIS:DL1': 'Input Digital Link',
    'IIS:DVI': 'Input DVI-D',
    'IIS:DP1': 'Input DisplayPort',
    'IIS:RG1': 'Input Computer 1',
    'IIS:RG2': 'Input Computer 2',
    'IIS:VID': 'Input Video',
    'IIS:SVD': 'Input Y/C',
    'OTS:00': 'Test Pattern Off',
    'OTS:01': 'Test Pattern White',
    'OTS:02': 'Test Pattern Black',
    'VXX:QPDI1=+00001': 'Quad Pixel On',
    'VXX:QPDI1=+00000': 'Quad Pixel Off',
    'VXX:LNSI1=+00001': 'Lens Home',
    'VXX:LNSI0=+00001': 'Lens Calibration',
  };
  if (labels.containsKey(cmd)) return labels[cmd]!;
  if (cmd.startsWith('VXX:LNSI0')) return 'Lens Calibration';
  if (cmd.startsWith('VXX:LNSI3')) return 'Lens Shift V';
  if (cmd.startsWith('VXX:LNSI2')) return 'Lens Shift H';
  if (cmd.startsWith('VXX:LNSI4')) return 'Focus Adjust';
  if (cmd.startsWith('VXX:LNSI5')) return 'Zoom Adjust';
  if (cmd.startsWith('IIS:')) return 'Input: ${cmd.substring(4)}';
  if (cmd.startsWith('OTS:')) return 'Test Pattern';
  if (cmd.startsWith('VPM:')) return 'Picture Mode';
  if (cmd.startsWith('VXX:SEFS1')) return 'Shutter Fade In';
  if (cmd.startsWith('VXX:SEFS2')) return 'Shutter Fade Out';
  if (cmd.startsWith('VXX:PMDI')) return 'Picture Mode';
  if (cmd.startsWith('OBC:')) return 'Back Color';
  if (cmd.startsWith('MLO:')) return 'Startup Logo';
  if (cmd.startsWith('OIL:')) return 'Projection Method';
  if (cmd.startsWith('VXX:LNEI')) return 'Lens Type';
  return cmd;
}
