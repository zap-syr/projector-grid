enum LogSeverity { error, warning, info, success }

enum LogEventType { connectivity, command, osc, hardware }

class LogEvent {
  final DateTime timestamp;
  final LogSeverity severity;
  final LogEventType type;
  final String message;
  final String? projectorIp;
  final String? projectorName;

  LogEvent({
    required this.severity,
    required this.type,
    required this.message,
    this.projectorIp,
    this.projectorName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

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
    'OTS:00': 'Test Pattern Off',
    'OTS:01': 'Test Pattern White',
    'OTS:02': 'Test Pattern Black',
    'VXX:QPDI1=+00001': 'Quad Pixel On',
    'VXX:QPDI1=+00000': 'Quad Pixel Off',
    'VXX:LNSI1=+00001': 'Lens Home',
    'VXX:LNSI0=+00001': 'Lens Calibration',
  };
  if (labels.containsKey(cmd)) return labels[cmd]!;
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
