import 'custom_command.dart';

/// The command picker's categories, in rail order.
enum CommandCategory {
  power('Power'),
  shutter('Shutter'),
  input('Input'),
  custom('Custom');

  const CommandCategory(this.label);

  final String label;
}

/// One command a scheduled task can send: the name the user sees and the
/// NTCONTROL string, which the picker never shows.
class ScheduledCommand {
  const ScheduledCommand(this.label, this.command, this.category);

  final String label;
  final String command;
  final CommandCategory category;

  @override
  bool operator ==(Object other) =>
      other is ScheduledCommand &&
      other.command == command &&
      other.label == label &&
      other.category == category;

  @override
  int get hashCode => Object.hash(label, command, category);
}

const builtInScheduledCommands = <ScheduledCommand>[
  ScheduledCommand('Power on', 'PON', CommandCategory.power),
  ScheduledCommand('Power standby', 'POF', CommandCategory.power),
  ScheduledCommand('Shutter open', 'OSH:0', CommandCategory.shutter),
  ScheduledCommand('Shutter close', 'OSH:1', CommandCategory.shutter),
  ScheduledCommand('HDMI 1', 'IIS:HD1', CommandCategory.input),
  ScheduledCommand('HDMI 2', 'IIS:HD2', CommandCategory.input),
  ScheduledCommand('SDI 1', 'IIS:SD1', CommandCategory.input),
  ScheduledCommand('SDI 2', 'IIS:SD2', CommandCategory.input),
  ScheduledCommand('Digital Link', 'IIS:DL1', CommandCategory.input),
  ScheduledCommand('DVI-D', 'IIS:DVI', CommandCategory.input),
  ScheduledCommand('DisplayPort', 'IIS:DP1', CommandCategory.input),
  ScheduledCommand('Computer 1', 'IIS:RG1', CommandCategory.input),
  ScheduledCommand('Computer 2', 'IIS:RG2', CommandCategory.input),
  ScheduledCommand('Video', 'IIS:VID', CommandCategory.input),
  ScheduledCommand('Y/C', 'IIS:SVD', CommandCategory.input),
];

/// Everything the picker offers: the built-in table, then the project's
/// custom commands.
List<ScheduledCommand> scheduledCommandCatalog(List<CustomCommand> customs) => [
  ...builtInScheduledCommands,
  for (final c in customs)
    ScheduledCommand(c.name, c.command, CommandCategory.custom),
];

/// The commands of [catalog] that match [query] within [category] (all
/// categories when null), in catalog order. Every word of the query has to
/// appear in the command's name or its category's, ignoring case, so
/// `shutter` finds both shutter commands and `hdmi 2` finds one.
List<ScheduledCommand> searchScheduledCommands(
  List<ScheduledCommand> catalog,
  String query, {
  CommandCategory? category,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return [
    for (final c in catalog)
      if (category == null || c.category == category)
        if (_matches(c, words)) c,
  ];
}

bool _matches(ScheduledCommand c, List<String> words) {
  final haystack = '${c.label} ${c.category.label}'.toLowerCase();
  return words.every(haystack.contains);
}

/// The catalog entry a saved task's [command] stands for, or null for a
/// command string typed into the task. A built-in command wins over a
/// custom one with the same string, and a custom one with the saved
/// [label] over another with the same string (a renamed custom command
/// still matches by its string).
ScheduledCommand? scheduledCommandFor(
  List<ScheduledCommand> catalog,
  String command,
  String label,
) {
  final same = catalog.where((c) => c.command == command);
  return same.where((c) => c.category != CommandCategory.custom).firstOrNull ??
      same.where((c) => c.label == label).firstOrNull ??
      same.firstOrNull;
}

/// The name a task's command is shown under: the built-in table's wording
/// for a built-in command (older files saved `Power On`), else what the
/// task saved.
String scheduledCommandLabel(String command, String savedLabel) {
  for (final c in builtInScheduledCommands) {
    if (c.command == command) return c.label;
  }
  return savedLabel;
}
