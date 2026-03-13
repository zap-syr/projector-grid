import 'package:flutter/material.dart';
import '../widgets/control_bar.dart';
import '../widgets/projector_workspace.dart';
import '../widgets/monitoring_table.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar.dart';
import '../widgets/top_menu_bar.dart';

class MainWorkspaceScreen extends StatefulWidget {
  const MainWorkspaceScreen({super.key});

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  bool _isMonitoringView = false;

  @override
  Widget build(BuildContext context) {
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
              ? const MonitoringTable() // Table View
              : Row( // Original Grid Workspace
                  children: [
                    Expanded(
                      child: Column(
                        children: const [
                          StatusBar(),
                          Expanded(
                            child: ProjectorWorkspace(),
                          ),
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
