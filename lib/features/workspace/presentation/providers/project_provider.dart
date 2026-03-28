import 'dart:convert';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import 'workspace_provider.dart';

part 'project_provider.g.dart';

class ProjectState {
  final String? currentFilePath;
  final bool isDirty;
  final List<String> recentProjects;

  const ProjectState({
    this.currentFilePath,
    this.isDirty = false,
    this.recentProjects = const [],
  });

  ProjectState copyWith({
    String? currentFilePath,
    bool clearCurrentFilePath = false,
    bool? isDirty,
    List<String>? recentProjects,
  }) {
    return ProjectState(
      currentFilePath: clearCurrentFilePath ? null : (currentFilePath ?? this.currentFilePath),
      isDirty: isDirty ?? this.isDirty,
      recentProjects: recentProjects ?? this.recentProjects,
    );
  }
}

@riverpod
class ProjectStateNotifier extends _$ProjectStateNotifier {
  bool _suppressDirty = false;

  static String get _recentProjectsPath {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\ProjectorsManager\\recent.json';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/ProjectorsManager/recent.json';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/.config/ProjectorsManager/recent.json';
    }
  }

  @override
  ProjectState build() {
    final recentProjects = _loadRecentProjects();

    ref.listen(workspaceProvider, (previous, next) {
      if (_suppressDirty || previous == null) return;
      if (_configurableStateChanged(previous, next)) {
        state = state.copyWith(isDirty: true);
      }
    });

    return ProjectState(recentProjects: recentProjects);
  }

  // ── Dirty tracking ────────────────────────────────────────────────────────

  bool _configurableStateChanged(
    List<ProjectorNode> prev,
    List<ProjectorNode> next,
  ) {
    if (prev.length != next.length) return true;
    final prevMap = {for (final n in prev) n.id: n};
    for (final node in next) {
      final p = prevMap[node.id];
      if (p == null) return true;
      if (p.name != node.name ||
          p.ipAddress != node.ipAddress ||
          p.port != node.port ||
          p.login != node.login ||
          p.password != node.password ||
          p.x != node.x ||
          p.y != node.y ||
          p.groupId != node.groupId) {
        return true;
      }
    }
    return false;
  }

  // ── Project operations ────────────────────────────────────────────────────

  void newProject() {
    _suppressDirty = true;
    final wsNotifier = ref.read(workspaceProvider.notifier);
    wsNotifier.setNodes([]);
    wsNotifier.setGroups([]);
    _suppressDirty = false;
    state = state.copyWith(clearCurrentFilePath: true, isDirty: false);
  }

  Future<void> openProject(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        state = state.copyWith(
          recentProjects: _removeFromRecent(path, state.recentProjects),
        );
        _saveRecentProjects(state.recentProjects);
        return;
      }

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final nodes = _deserializeNodes(json);
      final groups = _deserializeGroups(json);

      _suppressDirty = true;
      final wsNotifier = ref.read(workspaceProvider.notifier);
      wsNotifier.setNodes(nodes);
      wsNotifier.setGroups(groups);
      wsNotifier.refreshAll();
      _suppressDirty = false;

      final updated = _addToRecent(path, state.recentProjects);
      state = state.copyWith(
        currentFilePath: path,
        isDirty: false,
        recentProjects: updated,
      );
      _saveRecentProjects(updated);
    } catch (_) {
      // File corrupt or unreadable — leave state unchanged
    }
  }

  Future<bool> pickAndOpenProject() async {
    final path = await _showOpenDialog();
    if (path == null) return false;
    await openProject(path);
    return true;
  }

  /// Saves to current file if it exists, otherwise triggers saveProjectAs.
  Future<bool> saveProject() async {
    if (state.currentFilePath != null) {
      return _writeToFile(state.currentFilePath!);
    }
    return saveProjectAs();
  }

  /// Always shows the save dialog regardless of current file path.
  Future<bool> saveProjectAs() async {
    final defaultName = state.currentFilePath != null
        ? _fileName(state.currentFilePath!)
        : 'project.prjmgr';

    final path = await _showSaveDialog(defaultName);
    if (path == null) return false;
    final filePath = path.endsWith('.prjmgr') ? path : '$path.prjmgr';
    return _writeToFile(filePath);
  }

  // ── Native file dialogs (no plugin — uses OS shell) ───────────────────────

  static Future<String?> _showOpenDialog() async {
    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'''
Add-Type -AssemblyName System.Windows.Forms
$owner = New-Object System.Windows.Forms.Form
$owner.TopMost = $true
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = 'Projector Project (*.prjmgr)|*.prjmgr'
$dialog.Title = 'Open Project'
$r = $dialog.ShowDialog($owner)
$owner.Dispose()
if ($r -eq 'OK') { Write-Output $dialog.FileName }
''',
      ]);
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    } else if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose file with prompt "Open Project" of type {"prjmgr"})',
      ]);
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    }
    return null;
  }

  static Future<String?> _showSaveDialog(String defaultName) async {
    final safeName =
        defaultName.endsWith('.prjmgr') ? defaultName : '$defaultName.prjmgr';

    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        '''
Add-Type -AssemblyName System.Windows.Forms
\$owner = New-Object System.Windows.Forms.Form
\$owner.TopMost = \$true
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Filter = 'Projector Project (*.prjmgr)|*.prjmgr'
\$dialog.DefaultExt = 'prjmgr'
\$dialog.FileName = '$safeName'
\$dialog.Title = 'Save Project'
\$r = \$dialog.ShowDialog(\$owner)
\$owner.Dispose()
if (\$r -eq 'OK') { Write-Output \$dialog.FileName }
''',
      ]);
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    } else if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose file name with prompt "Save Project" default name "$safeName")',
      ]);
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    }
    return null;
  }

  Future<bool> _writeToFile(String path) async {
    try {
      final wsNotifier = ref.read(workspaceProvider.notifier);
      final nodes = ref.read(workspaceProvider);
      final groups = wsNotifier.groups;
      final json = jsonEncode({
        'version': 2,
        'groups': groups.map(_serializeGroup).toList(),
        'nodes': nodes.map(_serializeNode).toList(),
      });

      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(json);

      final updated = _addToRecent(path, state.recentProjects);
      state = state.copyWith(
        currentFilePath: path,
        isDirty: false,
        recentProjects: updated,
      );
      _saveRecentProjects(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> _serializeNode(ProjectorNode node) => {
    'id': node.id,
    'name': node.name,
    'ipAddress': node.ipAddress,
    'port': node.port,
    'login': node.login,
    'password': node.password,
    'x': node.x,
    'y': node.y,
    if (node.groupId != null) 'groupId': node.groupId,
  };

  static Map<String, dynamic> _serializeGroup(ProjectorGroup group) => {
    'id': group.id,
    'name': group.name,
    'color': group.color,
    'oscAddress': group.oscAddress,
  };

  List<ProjectorNode> _deserializeNodes(Map<String, dynamic> json) {
    final nodes = json['nodes'] as List<dynamic>;
    return nodes.map((n) => ProjectorNode(
      id: n['id'] as String,
      name: n['name'] as String,
      ipAddress: n['ipAddress'] as String,
      port: n['port'] as int,
      login: n['login'] as String,
      password: n['password'] as String,
      x: (n['x'] as num).toDouble(),
      y: (n['y'] as num).toDouble(),
      groupId: n['groupId'] as String?,
    )).toList();
  }

  static List<ProjectorGroup> _deserializeGroups(Map<String, dynamic> json) {
    final groups = json['groups'] as List<dynamic>?;
    if (groups == null) return [];
    return groups.map((g) => ProjectorGroup(
      id: g['id'] as String,
      name: g['name'] as String,
      color: g['color'] as int,
      oscAddress: (g['oscAddress'] as String?) ?? '',
    )).toList();
  }

  // ── Recent projects ───────────────────────────────────────────────────────

  List<String> _loadRecentProjects() {
    try {
      final file = File(_recentProjectsPath);
      if (!file.existsSync()) return [];
      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return list.cast<String>().where((p) => File(p).existsSync()).toList();
    } catch (_) {
      return [];
    }
  }

  void _saveRecentProjects(List<String> recent) {
    try {
      final file = File(_recentProjectsPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(recent));
    } catch (_) {}
  }

  List<String> _addToRecent(String path, List<String> current) {
    final updated = [path, ...current.where((p) => p != path)];
    return updated.take(10).toList();
  }

  List<String> _removeFromRecent(String path, List<String> current) {
    return current.where((p) => p != path).toList();
  }

  void clearRecentProjects() {
    state = state.copyWith(recentProjects: []);
    _saveRecentProjects([]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fileName(String path) =>
      path.split(RegExp(r'[/\\]')).last;
}

/// Returns just the file name from a full path.
String projectFileName(String path) =>
    path.split(RegExp(r'[/\\]')).last;
