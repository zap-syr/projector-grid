import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/docs_service.dart';
import '../providers/project_provider.dart';
import '../providers/workspace_provider.dart';
import 'about_dialog.dart';
import 'keyboard_shortcuts_dialog.dart';
import 'manage_groups_dialog.dart';
import 'preferences_dialog.dart';
import 'top_menu_bar.dart';

/// Wraps [child] with a native macOS menu bar via [PlatformMenuBar].
/// On Windows/Linux the widget is a transparent pass-through.
class MacMenuBar extends ConsumerWidget {
  const MacMenuBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isMacOS) return child;

    final recentProjects = ref.watch(
      projectStateProvider.select((s) => s.recentProjects),
    );
    ref.watch(workspaceProvider); // rebuild when undo/redo availability changes
    final projectNotifier = ref.read(projectStateProvider.notifier);
    final wsNotifier = ref.read(workspaceProvider.notifier);

    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        // ── App menu (first slot = app-name menu on macOS) ────────────────
        PlatformMenu(
          label: 'Projector Grid',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'About Projector Grid',
                  onSelected: () {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => const AppAboutDialog(),
                    );
                  },
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Settings…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: () {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => const PreferencesDialog(),
                    );
                  },
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),

        // ── File ──────────────────────────────────────────────────────────
        PlatformMenu(
          label: 'File',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'New Project',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyN,
                    meta: true,
                  ),
                  onSelected: () async {
                    if (!context.mounted) return;
                    if (!await TopMenuBar.confirmUnsavedChanges(context, ref)) {
                      return;
                    }
                    projectNotifier.newProject();
                  },
                ),
                PlatformMenuItem(
                  label: 'Open…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyO,
                    meta: true,
                  ),
                  onSelected: () async {
                    if (!context.mounted) return;
                    if (!await TopMenuBar.confirmUnsavedChanges(context, ref)) {
                      return;
                    }
                    await projectNotifier.pickAndOpenProject();
                  },
                ),
                PlatformMenu(
                  label: 'Open Recent',
                  menus: recentProjects.isEmpty
                      ? <PlatformMenuItem>[
                          const PlatformMenuItem(
                            label: '(No recent projects)',
                            onSelected: null,
                          ),
                        ]
                      : <PlatformMenuItem>[
                          ...recentProjects.map(
                            (path) => PlatformMenuItem(
                              label: projectFileName(path),
                              onSelected: () async {
                                if (!context.mounted) return;
                                if (!await TopMenuBar.confirmUnsavedChanges(
                                  context,
                                  ref,
                                )) {
                                  return;
                                }
                                await projectNotifier.openProject(path);
                              },
                            ),
                          ),
                          PlatformMenuItemGroup(
                            members: <PlatformMenuItem>[
                              PlatformMenuItem(
                                label: 'Clear Recent Projects',
                                onSelected: () =>
                                    projectNotifier.clearRecentProjects(),
                              ),
                            ],
                          ),
                        ],
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Save',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    meta: true,
                  ),
                  onSelected: () => projectNotifier.saveProject(),
                ),
                PlatformMenuItem(
                  label: 'Save As…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: () => projectNotifier.saveProjectAs(),
                ),
              ],
            ),
          ],
        ),

        // ── Edit ──────────────────────────────────────────────────────────
        PlatformMenu(
          label: 'Edit',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Undo',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                  onSelected:
                      wsNotifier.canUndo ? () => wsNotifier.undo() : null,
                ),
                PlatformMenuItem(
                  label: 'Redo',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  onSelected:
                      wsNotifier.canRedo ? () => wsNotifier.redo() : null,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Refresh',
                  shortcut: const SingleActivator(LogicalKeyboardKey.f5),
                  onSelected: () => wsNotifier.refreshAll(),
                ),
                PlatformMenuItem(
                  label: 'Manage Groups…',
                  onSelected: () {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => const ManageGroupsDialog(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ── Help ──────────────────────────────────────────────────────────
        PlatformMenu(
          label: 'Help',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Keyboard Shortcuts',
                  onSelected: () {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => const KeyboardShortcutsDialog(),
                    );
                  },
                ),
                PlatformMenuItem(
                  label: 'OSC Reference',
                  onSelected: () => DocsService.openOscReference(),
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
