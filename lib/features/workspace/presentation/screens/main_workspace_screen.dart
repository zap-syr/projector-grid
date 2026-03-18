import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/project_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/projector_workspace.dart';
import '../widgets/monitoring_table.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar.dart';
import '../widgets/top_menu_bar.dart';

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

  static const _appName = 'Panasonic Projectors Manager';

  void _updateWindowTitle(ProjectState projectState) {
    final String title;
    if (projectState.currentFilePath == null && !projectState.isDirty) {
      title = _appName;
    } else {
      final fileName = projectState.currentFilePath != null
          ? projectFileName(projectState.currentFilePath!)
          : 'New Project';
      final dirtyMark = projectState.isDirty ? '● ' : '';
      title = '$_appName — $fileName $dirtyMark';
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          const TopMenuBar(),
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
                ? const MonitoringTable()
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
    );
  }
}
