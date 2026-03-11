import 'package:flutter/material.dart';
import '../widgets/control_bar.dart';
import '../widgets/projector_workspace.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar.dart';
import '../widgets/top_menu_bar.dart';

class MainWorkspaceScreen extends StatelessWidget {
  const MainWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          const TopMenuBar(),
          const MainToolbar(),
          Expanded(
            child: Row(
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
