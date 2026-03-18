import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/workspace_provider.dart';
import '../providers/project_provider.dart';
import 'preferences_dialog.dart';

class TopMenuBar extends ConsumerWidget {
  const TopMenuBar({super.key});

  // ── Unsaved changes guard ──────────────────────────────────────────────────
  static Future<bool> confirmUnsavedChanges(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final projectState = ref.read(projectStateProvider);
    if (!projectState.isDirty) return true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Would you like to save before continuing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      return ref.read(projectStateProvider.notifier).saveProject();
    }
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentProjects = ref.watch(
      projectStateProvider.select((s) => s.recentProjects),
    );
    final notifier = ref.read(projectStateProvider.notifier);

    return Row(
      children: [
        MenuBar(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        ),
      ),
      children: [
            // ── File ────────────────────────────────────────────────────────
            SubmenuButton(
              menuChildren: [
                // New Project
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyN,
                    control: true,
                  ),
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    notifier.newProject();
                  },
                  child: const Text('New Project'),
                ),

                // Open Project
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyO,
                    control: true,
                  ),
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    await notifier.pickAndOpenProject();
                  },
                  child: const Text('Open Project'),
                ),

                // Open Recent
                SubmenuButton(
                  menuChildren: recentProjects.isEmpty
                      ? [
                          const MenuItemButton(
                            onPressed: null,
                            child: Text('(No recent projects)'),
                          ),
                        ]
                      : recentProjects
                          .map(
                            (path) => MenuItemButton(
                              onPressed: () async {
                                if (!await confirmUnsavedChanges(
                                  context,
                                  ref,
                                )) {
                                  return;
                                }
                                await notifier.openProject(path);
                              },
                              child: Tooltip(
                                message: path,
                                child: Text(
                                  projectFileName(path),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  child: const Text('Open Recent'),
                ),

                const Divider(),

                // Save
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    control: true,
                  ),
                  onPressed: () => notifier.saveProject(),
                  child: const Text('Save'),
                ),

                // Save As…
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    control: true,
                    shift: true,
                  ),
                  onPressed: () => notifier.saveProjectAs(),
                  child: const Text('Save As…'),
                ),

                const Divider(),

                // Exit
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyQ,
                    control: true,
                  ),
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    windowManager.destroy();
                  },
                  child: const Text('Exit'),
                ),
              ],
              child: const Text('File'),
            ),

            // ── Edit ────────────────────────────────────────────────────────
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: true,
                  ),
                  onPressed: () {},
                  child: const Text('Undo'),
                ),
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyY,
                    control: true,
                  ),
                  onPressed: () {},
                  child: const Text('Redo'),
                ),
                const Divider(),
                MenuItemButton(
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyR,
                    control: true,
                  ),
                  onPressed: () =>
                      ref.read(workspaceProvider.notifier).refreshAll(),
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

            // ── Help ────────────────────────────────────────────────────────
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
