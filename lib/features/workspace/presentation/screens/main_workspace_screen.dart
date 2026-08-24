import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/app_settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/workspace_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/event_log_panel.dart';
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

class _ShowControlsIntent extends Intent {
  const _ShowControlsIntent();
}

class _ShowMonitoringIntent extends Intent {
  const _ShowMonitoringIntent();
}

class MainWorkspaceScreen extends ConsumerStatefulWidget {
  const MainWorkspaceScreen({super.key});

  @override
  ConsumerState<MainWorkspaceScreen> createState() =>
      _MainWorkspaceScreenState();
}

// Watches both isMonitoringView and showLogs independently so neither
// triggers a rebuild of the keyboard-shortcut / action tree above it.
// Holds two FocusScopeNodes so it can re-focus the correct view after every
// IndexedStack switch (IndexedStack wraps inactive children in Visibility,
// which inserts ExcludeFocus and unfocuses the previously active widget,
// leaving primaryFocus = null and silently breaking all Shortcuts).
class _WorkspaceBody extends ConsumerStatefulWidget {
  const _WorkspaceBody();

  @override
  ConsumerState<_WorkspaceBody> createState() => _WorkspaceBodyState();
}

class _WorkspaceBodyState extends ConsumerState<_WorkspaceBody> {
  // FocusScopeNode remembers its last focused descendant in _focusedChildren.
  // When the view becomes inactive, IndexedStack's Visibility wraps it with
  // ExcludeFocus(excluding: true), making canRequestFocus == false on the scope.
  // unfocus() only clears _focusedChildren when canRequestFocus == true, so the
  // inner focus is preserved. When requestFocus() is called on the scope after
  // the view becomes active again, _doRequestFocus restores the inner Focus —
  // which means the inner Shortcuts (Ctrl+A, Ctrl+Z, etc.) keep working.
  final _controlsScopeNode = FocusScopeNode(debugLabel: 'workspace-controls');
  final _monitoringScopeNode = FocusScopeNode(
    debugLabel: 'workspace-monitoring',
  );

  @override
  void dispose() {
    _controlsScopeNode.dispose();
    _monitoringScopeNode.dispose();
    super.dispose();
  }

  void _requestViewFocus(bool isMonitoring) {
    // Schedule after the frame so Visibility/ExcludeFocus from IndexedStack
    // have already updated before we call requestFocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (isMonitoring ? _monitoringScopeNode : _controlsScopeNode).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMonitoringView = ref.watch(
      appSettingsProvider.select((s) => s.isMonitoringView),
    );
    final showLogs = ref.watch(appSettingsProvider.select((s) => s.showLogs));

    ref.listen(
      appSettingsProvider.select((s) => s.isMonitoringView),
      (_, isMonitoring) => _requestViewFocus(isMonitoring),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve at least 150px for the workspace above the log panel.
        const minWorkspaceHeight = 150.0;
        final maxLogHeight = (constraints.maxHeight - minWorkspaceHeight).clamp(
          EventLogPanel.minHeight,
          EventLogPanel.defaultHeight,
        );

        return Column(
          children: [
            // Shared above the Controls/Monitoring switch (rather than
            // nested inside the Controls branch) so it stays visible in
            // both views instead of disappearing in Monitoring.
            const StatusBar(),
            Expanded(
              child: IndexedStack(
                index: isMonitoringView ? 1 : 0,
                children: [
                  FocusScope(
                    node: _controlsScopeNode,
                    child: const Row(
                      children: [
                        Expanded(child: ProjectorWorkspace()),
                        ControlBar(),
                      ],
                    ),
                  ),
                  FocusScope(
                    node: _monitoringScopeNode,
                    child: const MonitoringTable(),
                  ),
                ],
              ),
            ),
            if (showLogs) EventLogPanel(maxHeight: maxLogHeight),
          ],
        );
      },
    );
  }
}

class _MainWorkspaceScreenState extends ConsumerState<MainWorkspaceScreen>
    with WindowListener {
  static const _quitChannel = MethodChannel('projector_grid/quit');

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    if (Platform.isMacOS) {
      _quitChannel.setMethodCallHandler(_handleQuitChannelCall);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (Platform.isMacOS) {
      _quitChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  /// Answers AppDelegate's `applicationShouldTerminate` — invoked when the
  /// app is quit via the system menu bar (or its Cmd+Q equivalent when no
  /// Flutter view has focus), which bypasses `onWindowClose` below entirely.
  Future<bool> _handleQuitChannelCall(MethodCall call) async {
    if (call.method != 'confirmQuit') return true;
    if (!mounted) return true;
    return TopMenuBar.confirmUnsavedChanges(context, ref);
  }

  /// `windowManager.destroy()` always calls `NSApp.terminate(nil)` under the
  /// hood, which re-enters AppDelegate's `applicationShouldTerminate` on
  /// macOS. Call this right before `destroy()` in a path that already ran
  /// its own confirmation, so that re-entry doesn't prompt a second time.
  static Future<void> _markTerminationApproved() async {
    if (!Platform.isMacOS) return;
    try {
      await _quitChannel.invokeMethod('markTerminationApproved');
    } catch (_) {
      // Best-effort: if this doesn't land, applicationShouldTerminate falls
      // back to asking Flutter again via confirmQuit.
    }
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
      await _markTerminationApproved();
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
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          ): const _SaveAsProjectIntent(),
          const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
              const _ExitIntent(),
          const SingleActivator(LogicalKeyboardKey.f5): const _RefreshIntent(),
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              const _ShowControlsIntent(),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              const _ShowMonitoringIntent(),
          if (Platform.isMacOS) ...<ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
                const _NewProjectIntent(),
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
                const _OpenProjectIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                const _SaveProjectIntent(),
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: true,
              shift: true,
            ): const _SaveAsProjectIntent(),
            const SingleActivator(LogicalKeyboardKey.keyQ, meta: true):
                const _ExitIntent(),
            const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
                const _ShowControlsIntent(),
            const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
                const _ShowMonitoringIntent(),
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
                await _markTerminationApproved();
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
            _ShowControlsIntent: CallbackAction<_ShowControlsIntent>(
              onInvoke: (_) {
                ref.read(appSettingsProvider.notifier).setMonitoringView(false);
                return null;
              },
            ),
            _ShowMonitoringIntent: CallbackAction<_ShowMonitoringIntent>(
              onInvoke: (_) {
                ref.read(appSettingsProvider.notifier).setMonitoringView(true);
                return null;
              },
            ),
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Column(
              children: [
                if (!Platform.isMacOS) const TopMenuBar(),
                const MainToolbar(),
                const Expanded(child: _WorkspaceBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
