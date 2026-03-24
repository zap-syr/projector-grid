import 'dart:convert';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/custom_command.dart';

part 'custom_commands_provider.g.dart';

@riverpod
class CustomCommandsNotifier extends _$CustomCommandsNotifier {
  static String get _filePath {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\ProjectorsManager\\custom_commands.json';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/ProjectorsManager/custom_commands.json';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/.config/ProjectorsManager/custom_commands.json';
    }
  }

  @override
  List<CustomCommand> build() => _load();

  List<CustomCommand> _load() {
    try {
      final file = File(_filePath);
      if (!file.existsSync()) return [];
      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return list
          .map((e) => CustomCommand.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<CustomCommand> commands) {
    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(commands.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
  }

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
    if (newIndex > oldIndex) newIndex--;
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
