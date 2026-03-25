import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/workspace_provider.dart';
import '../providers/project_provider.dart';
import 'preferences_dialog.dart';
import 'manage_groups_dialog.dart';
import 'keyboard_shortcuts_dialog.dart';
import '../../../../core/services/docs_service.dart';

class TopMenuBar extends ConsumerWidget {
  const TopMenuBar({super.key});

  static Widget _menuItem(
    BuildContext context, {
    required String label,
    String? shortcutLabel,
    required VoidCallback? onPressed,
  }) {
    return MenuItemButton(
      onPressed: onPressed,
      child: shortcutLabel == null
          ? Text(label)
          : SizedBox(
              width: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  Text(
                    shortcutLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

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
    // Watch workspace to rebuild when undo/redo availability changes.
    ref.watch(workspaceProvider);
    final wsNotifier = ref.read(workspaceProvider.notifier);

    return Row(
      children: [
        MenuBar(
          style: const MenuStyle(
            elevation: WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          children: [
            // ── File ──────────────────────────────────────────────────────
            SubmenuButton(

              menuChildren: [
                _menuItem(
                  context,
                  label: 'New Project',
                  shortcutLabel: 'Ctrl+N',
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    notifier.newProject();
                  },
                ),
                _menuItem(
                  context,
                  label: 'Open Project',
                  shortcutLabel: 'Ctrl+O',
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    await notifier.pickAndOpenProject();
                  },
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
                      : [
                          ...recentProjects.map(
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
                              child: Text(
                                projectFileName(path),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const Divider(),
                          MenuItemButton(
                            onPressed: () => notifier.clearRecentProjects(),
                            child: const Text('Clear Recent Projects'),
                          ),
                        ],
                  child: const Text('Open Recent'),
                ),

                const Divider(),

                _menuItem(
                  context,
                  label: 'Save',
                  shortcutLabel: 'Ctrl+S',
                  onPressed: () => notifier.saveProject(),
                ),
                _menuItem(
                  context,
                  label: 'Save As…',
                  shortcutLabel: 'Ctrl+Shift+S',
                  onPressed: () => notifier.saveProjectAs(),
                ),

                const Divider(),

                _menuItem(
                  context,
                  label: 'Exit',
                  shortcutLabel: 'Ctrl+Q',
                  onPressed: () async {
                    if (!await confirmUnsavedChanges(context, ref)) return;
                    windowManager.destroy();
                  },
                ),
              ],
              child: const Text('File'),
            ),

            // ── Edit ──────────────────────────────────────────────────────
            SubmenuButton(

              menuChildren: [
                _menuItem(
                  context,
                  label: 'Undo',
                  shortcutLabel: 'Ctrl+Z',
                  onPressed: wsNotifier.canUndo ? () => wsNotifier.undo() : null,
                ),
                _menuItem(
                  context,
                  label: 'Redo',
                  shortcutLabel: 'Ctrl+Y',
                  onPressed: wsNotifier.canRedo ? () => wsNotifier.redo() : null,
                ),
                const Divider(),
                _menuItem(
                  context,
                  label: 'Refresh',
                  shortcutLabel: 'F5',
                  onPressed: () =>
                      ref.read(workspaceProvider.notifier).refreshAll(),
                ),
                _menuItem(
                  context,
                  label: 'Manage Groups',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const ManageGroupsDialog(),
                  ),
                ),
                _menuItem(
                  context,
                  label: 'Preferences',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const PreferencesDialog(),
                  ),
                ),
              ],
              child: const Text('Edit'),
            ),

            // ── Help ──────────────────────────────────────────────────────
            SubmenuButton(
              menuChildren: [
                _menuItem(
                  context,
                  label: 'Keyboard Shortcuts',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const KeyboardShortcutsDialog(),
                  ),
                ),
                _menuItem(
                  context,
                  label: 'OSC Reference',
                  onPressed: () => DocsService.openOscReference(),
                ),
                const Divider(),
                _menuItem(context, label: 'About', onPressed: () {}),
              ],
              child: const Text('Help'),
            ),
          ],
        ),
      ],
    );
  }
}
