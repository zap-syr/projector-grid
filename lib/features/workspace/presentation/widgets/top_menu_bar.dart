import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TopMenuBar extends StatelessWidget {
  const TopMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          MenuBar(
            style: MenuStyle(
              elevation: WidgetStateProperty.all(0),
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
      ),
    );
  }
}
