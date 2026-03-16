import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import 'preferences_dialog.dart';

class TopMenuBar extends ConsumerWidget {
  const TopMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        MenuBar(
          style: MenuStyle(
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
            children: [
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
                    onPressed: () {},
                    child: const Text('New Project'),
                  ),
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
                    onPressed: () {},
                    child: const Text('Open Project'),
                  ),
                  const Divider(),
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, control: true),
                    onPressed: () {},
                    child: const Text('Exit'),
                  ),
                ],
                child: const Text('File'),
              ),
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
                    onPressed: () {},
                    child: const Text('Undo'),
                  ),
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyY, control: true),
                    onPressed: () {},
                    child: const Text('Redo'),
                  ),
                  const Divider(),
                  MenuItemButton(
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyR, control: true),
                    onPressed: () => ref.read(workspaceProvider.notifier).refreshAll(),
                    child: const Text('Refresh'),
                  ),
                  MenuItemButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const PreferencesDialog(),
                    ),
                    child: const Text('Preferences'),
                  ),
                ],
                child: const Text('Edit'),
              ),
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    onPressed: () {},
                    child: const Text('Documentation'),
                  ),
                  MenuItemButton(
                    onPressed: () {},
                    child: const Text('About'),
                  ),
                ],
                child: const Text('Help'),
              ),
            ],
          ),
        ],
      );
  }
}
