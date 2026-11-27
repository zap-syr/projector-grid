import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_config_dir.dart';
import '../../../../core/services/app_log_file.dart';
import '../../../../core/services/atomic_file.dart';
import '../../domain/custom_command.dart';

part 'custom_commands_provider.g.dart';

@Riverpod(keepAlive: true)
class CustomCommandsNotifier extends _$CustomCommandsNotifier {
  static const _maxRawLogChars = 300;

  static String get _filePath => appConfigFilePath('custom_commands.json');

  @override
  List<CustomCommand> build() => _load();

  List<CustomCommand> _load() =>
      readJsonConfigOrQuarantine(_filePath, 'Custom commands', (json) {
        // Parse each entry independently so one malformed command (e.g. from
        // a partial write during a crash) doesn't discard every other
        // previously-saved command, only that one entry is dropped.
        final entries = json as List<dynamic>;
        final commands = <CustomCommand>[];
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];
          try {
            commands.add(CustomCommand.fromJson(e as Map<String, dynamic>));
          } catch (cause) {
            // The entry vanishes from the file on the next save, so the log
            // keeps what the owner needs to restore it. The position is in
            // the first line because the log collapses repeats by that line,
            // and two entries can fail with the same text. No stack: the
            // message says everything.
            var raw = jsonEncode(e);
            if (raw.length > _maxRawLogChars) {
              raw = '${raw.substring(0, _maxRawLogChars)}...';
            }
            AppLog.error(
              'Custom commands load',
              'entry ${i + 1} of ${entries.length} in $_filePath dropped '
                  '($cause), raw JSON: $raw',
              null,
            );
          }
        }
        return commands;
      }) ??
      [];

  void _save(List<CustomCommand> commands) => saveConfigFileSync(
    _filePath,
    'Custom commands',
    jsonEncode(commands.map((c) => c.toJson()).toList()),
  );

  bool _slugExists(String slug, {String? excludeId}) => state.any(
    (c) => c.oscSlug == slug && (excludeId == null || c.id != excludeId),
  );

  /// Returns true on success, false if the slug already exists.
  bool add(String name, String command) {
    final candidate = CustomCommand(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      command: command.trim(),
    );
    if (_slugExists(candidate.oscSlug)) return false;
    final updated = [...state, candidate];
    state = updated;
    _save(updated);
    return true;
  }

  /// Returns true on success, false if the slug already exists on another command.
  bool update(String id, String name, String command) {
    final candidate = CustomCommand(
      id: id,
      name: name.trim(),
      command: command.trim(),
    );
    if (_slugExists(candidate.oscSlug, excludeId: id)) return false;
    final updated = state.map((c) => c.id == id ? candidate : c).toList();
    state = updated;
    _save(updated);
    return true;
  }

  void remove(String id) {
    final updated = state.where((c) => c.id != id).toList();
    state = updated;
    _save(updated);
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
    _save(updated);
  }

  /// Looks up a command by its OSC slug. Used by OscService.
  String? resolveBySlug(String slug) {
    try {
      return state.firstWhere((c) => c.oscSlug == slug).command;
    } catch (_) {
      return null;
    }
  }
}
