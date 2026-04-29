import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/project_provider.dart';
import '../providers/workspace_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/mac_menu_bar.dart';
import '../widgets/projector_workspace.dart';
import '../widgets/monitoring_table.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar.dart';
import '../widgets/top_menu_bar.dart';

class _NewProjectIntent extends Intent {
  const _NewProjectIntent();
}

class _OpenProjectIntent extends Intent {
  const _OpenProjectIntent();
}

class _SaveProjectIntent extends Intent {
  const _SaveProjectIntent();
}

class _SaveAsProjectIntent extends Intent {
  const _SaveAsProjectIntent();
}

class _ExitIntent extends Intent {
  const _ExitIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class MainWorkspaceScreen extends ConsumerStatefulWidget {
  const MainWorkspaceScreen({super.key});

  @override
  ConsumerState<MainWorkspaceScreen> createState() =>
      _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends ConsumerState<MainWorkspaceScreen>
    with WindowListener {
  bool _isMonitoringView = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  static const _appName = 'Projector Grid';

  void _updateWindowTitle(ProjectState projectState) {
    final String title;
    if (projectState.currentFilePath == null && !projectState.isDirty) {
      title = _appName;
    } else {
      final fileName = projectState.currentFilePath != null
          ? projectFileName(projectState.currentFilePath!)
          : 'New Project';
      final dirtyMark = projectState.isDirty ? '● ' : '';
      title = '$_appName - $fileName $dirtyMark';
    }
    windowManager.setTitle(title);
  }

  @override
  void onWindowClose() async {
    if (!mounted) {
      windowManager.destroy();
      return;
    }
    final canProceed = await TopMenuBar.confirmUnsavedChanges(context, ref);
    if (canProceed) {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(projectStateProvider, (_, next) => _updateWindowTitle(next));

    final projectNotifier = ref.read(projectStateProvider.notifier);
    final workspaceNotifier = ref.read(workspaceProvider.notifier);

    return MacMenuBar(
      child: Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _NewProjectIntent(),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            const _OpenProjectIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _SaveProjectIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            const _SaveAsProjectIntent(),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
            const _ExitIntent(),
        const SingleActivator(LogicalKeyboardKey.f5): const _RefreshIntent(),
        if (Platform.isMacOS) ...<ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              const _NewProjectIntent(),
          const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
              const _OpenProjectIntent(),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              const _SaveProjectIntent(),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
              const _SaveAsProjectIntent(),
          const SingleActivator(LogicalKeyboardKey.keyQ, meta: true):
              const _ExitIntent(),
        },
      },
      child: Actions(
        actions: {
          _NewProjectIntent: CallbackAction<_NewProjectIntent>(
            onInvoke: (_) async {
              if (!await TopMenuBar.confirmUnsavedChanges(context, ref)) {
                return null;
              }
              projectNotifier.newProject();
              return null;
            },
          ),
          _OpenProjectIntent: CallbackAction<_OpenProjectIntent>(
            onInvoke: (_) async {
              if (!await TopMenuBar.confirmUnsavedChanges(context, ref)) {
                return null;
              }
              await projectNotifier.pickAndOpenProject();
              return null;
            },
          ),
          _SaveProjectIntent: CallbackAction<_SaveProjectIntent>(
            onInvoke: (_) async {
              await projectNotifier.saveProject();
              return null;
            },
          ),
          _SaveAsProjectIntent: CallbackAction<_SaveAsProjectIntent>(
            onInvoke: (_) async {
              await projectNotifier.saveProjectAs();
              return null;
            },
          ),
          _ExitIntent: CallbackAction<_ExitIntent>(
            onInvoke: (_) async {
              if (!await TopMenuBar.confirmUnsavedChanges(context, ref)) {
                return null;
              }
              await windowManager.destroy();
              return null;
            },
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              workspaceNotifier.refreshAll();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              if (!Platform.isMacOS) const TopMenuBar(),
              MainToolbar(
                isMonitoringView: _isMonitoringView,
                onViewChanged: (val) {
                  setState(() {
                    _isMonitoringView = val;
                  });
                },
              ),
              Expanded(
                child: _isMonitoringView
                    ? const Focus(autofocus: true, child: MonitoringTable())
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: const [
                                StatusBar(),
                                Expanded(child: ProjectorWorkspace()),
                              ],
                            ),
                          ),
                          const ControlBar(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
