import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alignment_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/project_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/edit_history_status_provider.dart';
import '../providers/monitoring_view_provider.dart';
import 'preferences_dialog.dart';
import 'manage_groups_dialog.dart';
import 'scheduled_tasks/scheduled_tasks_dialog.dart';
import 'keyboard_shortcuts_dialog.dart';
import 'about_dialog.dart';
import 'common/confirm_dialog.dart';
import 'common/menu_check_gutter.dart';
import 'add_projector_dialog.dart';
import 'alignment_banner.dart';
import 'monitoring_table.dart';
import '../../../../core/services/app_log_file.dart';
import '../../../../core/services/docs_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Quit, handled by the main screen's `Actions`: File → Exit and Ctrl+Q
/// take the same path (unsaved changes, leaving Alignment mode, the logs).
class ExitIntent extends Intent {
  const ExitIntent();
}

class TopMenuBar extends ConsumerWidget {
  const TopMenuBar({super.key});

  // Standard label/shortcut column width shared by most dropdown rows.
  // Submenus with wider labels (Columns, Presets, Row density, Monitoring
  // Table's own toggles) size themselves individually instead.
  static const double _menuItemWidth = 220;

  static Widget _leadingGutter(bool checked) =>
      MenuCheckGutter(checked: checked);

  static Widget _menuItem(
    BuildContext context, {
    required String label,
    String? shortcutLabel,
    bool checked = false,
    double? width,
    required VoidCallback? onPressed,
  }) {
    final labelWidget = shortcutLabel == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                shortcutLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          );
    return MenuItemButton(
      leadingIcon: _leadingGutter(checked),
      onPressed: onPressed,
      child: width == null
          ? labelWidget
          : SizedBox(width: width, child: labelWidget),
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
      builder: (ctx) => const ConfirmDialog<String>(
        icon: Icons.save_outlined,
        title: 'Unsaved changes',
        subtitle: 'Save this project before you continue?',
        actions: [
          ConfirmAction(label: 'Cancel', value: 'cancel'),
          ConfirmAction(label: 'Discard', value: 'discard'),
          ConfirmAction(
            label: 'Save',
            value: 'save',
            kind: ConfirmActionKind.filled,
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
    final editHistory = ref.watch(editHistoryStatusProvider);
    final wsNotifier = ref.read(workspaceProvider.notifier);
    final showLogs = ref.watch(appSettingsProvider.select((s) => s.showLogs));
    final isMonitoringView = ref.watch(
      appSettingsProvider.select((s) => s.isMonitoringView),
    );
    final alignmentActive = ref.watch(
      alignmentProvider.select((s) => s.active),
    );
    final monitoringColumns = ref.watch(
      monitoringViewProvider.select((s) => s.columns),
    );
    final monitoringView = ref.read(monitoringViewProvider.notifier);
    final monitoringFitToWidth = ref.watch(
      appSettingsProvider.select((s) => s.monitoringFitToWidth),
    );
    final monitoringDensity = ref.watch(
      appSettingsProvider.select((s) => s.monitoringDensity),
    );
    final monitoringGroupBy = ref.watch(
      monitoringViewProvider.select((s) => s.groupByGroup),
    );
    final visibleColumns = MonitoringTable.resolveVisible(monitoringColumns);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);

    // The toolbar's colour, so the menu bar and the toolbar read as one band.
    return ColoredBox(
      color: AppTheme.chromeBackground(Theme.of(context).colorScheme),
      child: Row(
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
                    width: _menuItemWidth,
                    onPressed: () async {
                      if (!await confirmUnsavedChanges(context, ref)) return;
                      notifier.newProject();
                    },
                  ),
                  _menuItem(
                    context,
                    label: 'Open Project',
                    shortcutLabel: 'Ctrl+O',
                    width: _menuItemWidth,
                    onPressed: () async {
                      if (!await confirmUnsavedChanges(context, ref)) return;
                      await notifier.pickAndOpenProject();
                    },
                  ),

                  // Open Recent
                  SubmenuButton(
                    alignmentOffset: AppTheme.submenuOffset,
                    leadingIcon: _leadingGutter(false),
                    menuChildren: recentProjects.isEmpty
                        ? [
                            _menuItem(
                              context,
                              label: '(No recent projects)',
                              onPressed: null,
                            ),
                          ]
                        : [
                            ...recentProjects.map(
                              (path) => MenuItemButton(
                                leadingIcon: _leadingGutter(false),
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
                            _menuItem(
                              context,
                              label: 'Clear Recent Projects',
                              onPressed: () => notifier.clearRecentProjects(),
                            ),
                          ],
                    child: const Text('Open Recent'),
                  ),

                  const Divider(),

                  _menuItem(
                    context,
                    label: 'Save',
                    shortcutLabel: 'Ctrl+S',
                    width: _menuItemWidth,
                    onPressed: () => notifier.saveProject(),
                  ),
                  _menuItem(
                    context,
                    label: 'Save As…',
                    shortcutLabel: 'Ctrl+Shift+S',
                    width: _menuItemWidth,
                    onPressed: () => notifier.saveProjectAs(),
                  ),

                  const Divider(),

                  _menuItem(
                    context,
                    label: 'Exit',
                    shortcutLabel: 'Ctrl+Q',
                    width: _menuItemWidth,
                    onPressed: () async {
                      // The same path as Ctrl+Q, which also puts the
                      // projectors back from Alignment mode.
                      Actions.maybeInvoke(context, const ExitIntent());
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
                    width: _menuItemWidth,
                    onPressed: editHistory.canUndo
                        ? () => wsNotifier.undo()
                        : null,
                  ),
                  _menuItem(
                    context,
                    label: 'Redo',
                    shortcutLabel: 'Ctrl+Y',
                    width: _menuItemWidth,
                    onPressed: editHistory.canRedo
                        ? () => wsNotifier.redo()
                        : null,
                  ),
                ],
                child: const Text('Edit'),
              ),

              // ── Tools ─────────────────────────────────────────────────────
              SubmenuButton(
                menuChildren: [
                  _menuItem(
                    context,
                    label: 'Add Projectors',
                    onPressed: () {
                      final existingIps = ref
                          .read(workspaceProvider)
                          .map((n) => n.ipAddress)
                          .toList();
                      showDialog(
                        context: context,
                        builder: (context) => AddProjectorDialog(
                          existingIps: existingIps,
                          onAddProjectors: (projectors) {
                            ref
                                .read(workspaceProvider.notifier)
                                .addProjectors(projectors);
                          },
                        ),
                      );
                    },
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
                    label: 'Scheduled Tasks',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const ScheduledTasksDialog(),
                    ),
                  ),
                  _menuItem(
                    context,
                    label: 'Alignment Mode',
                    checked: alignmentActive,
                    shortcutLabel: 'Ctrl+L',
                    width: _menuItemWidth,
                    onPressed: () => toggleAlignmentMode(ref),
                  ),
                  const Divider(),
                  _menuItem(
                    context,
                    label: 'Refresh',
                    shortcutLabel: 'F5',
                    width: _menuItemWidth,
                    onPressed: () =>
                        ref.read(workspaceProvider.notifier).refreshAll(),
                  ),
                  const Divider(),
                  _menuItem(
                    context,
                    label: 'Preferences',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const PreferencesDialog(),
                    ),
                  ),
                ],
                child: const Text('Tools'),
              ),

              // ── View ──────────────────────────────────────────────────────
              SubmenuButton(
                menuChildren: [
                  _menuItem(
                    context,
                    label: 'Controls',
                    checked: !isMonitoringView,
                    shortcutLabel: 'Ctrl+1',
                    width: _menuItemWidth,
                    onPressed: () => settingsNotifier.setMonitoringView(false),
                  ),
                  _menuItem(
                    context,
                    label: 'Monitoring',
                    checked: isMonitoringView,
                    shortcutLabel: 'Ctrl+2',
                    width: _menuItemWidth,
                    onPressed: () => settingsNotifier.setMonitoringView(true),
                  ),
                  const Divider(),
                  _menuItem(
                    context,
                    label: 'Show Logs',
                    checked: showLogs,
                    onPressed: () => settingsNotifier.setShowLogs(!showLogs),
                  ),
                  const Divider(),
                  SubmenuButton(
                    alignmentOffset: AppTheme.submenuOffset,
                    leadingIcon: _leadingGutter(false),
                    menuChildren: [
                      // ── Columns ──────────────────────────────────────────
                      SubmenuButton(
                        alignmentOffset: AppTheme.submenuOffset,
                        leadingIcon: _leadingGutter(false),
                        menuChildren: [
                          for (final id in MonitoringTable.allColumnIds)
                            _menuItem(
                              context,
                              label: MonitoringTable.labelFor(id),
                              checked: visibleColumns.contains(id),
                              width: _menuItemWidth,
                              onPressed: () {
                                final next = MonitoringTable.toggledColumn(
                                  monitoringColumns,
                                  id,
                                );
                                if (next != null) {
                                  monitoringView.setColumns(next);
                                }
                              },
                            ),
                          const Divider(),
                          _menuItem(
                            context,
                            label: 'Show all columns',
                            width: _menuItemWidth,
                            onPressed: () => monitoringView.setColumns(
                              MonitoringTable.showAllColumns,
                            ),
                          ),
                        ],
                        child: const SizedBox(
                          width: 252,
                          child: Text('Columns'),
                        ),
                      ),
                      // ── Presets ──────────────────────────────────────────
                      SubmenuButton(
                        alignmentOffset: AppTheme.submenuOffset,
                        leadingIcon: _leadingGutter(false),
                        menuChildren: [
                          for (final entry in MonitoringTable.presets.entries)
                            _menuItem(
                              context,
                              label: entry.key,
                              width: 180,
                              onPressed: () =>
                                  monitoringView.setColumns(entry.value),
                            ),
                        ],
                        child: const SizedBox(
                          width: 252,
                          child: Text('Presets'),
                        ),
                      ),
                      const Divider(),
                      // ── Row density ──────────────────────────────────────
                      SubmenuButton(
                        alignmentOffset: AppTheme.submenuOffset,
                        leadingIcon: _leadingGutter(false),
                        menuChildren: [
                          for (final d in MonitoringDensity.values)
                            _menuItem(
                              context,
                              label: d.label,
                              checked: monitoringDensity == d,
                              width: 160,
                              onPressed: () =>
                                  settingsNotifier.setMonitoringDensity(d),
                            ),
                        ],
                        child: const SizedBox(
                          width: 252,
                          child: Text('Row density'),
                        ),
                      ),
                      const Divider(),
                      _menuItem(
                        context,
                        label: 'Fit columns to window',
                        checked: monitoringFitToWidth,
                        width: 252,
                        onPressed: () => settingsNotifier
                            .setMonitoringFitToWidth(!monitoringFitToWidth),
                      ),
                      _menuItem(
                        context,
                        label: 'Merge into groups',
                        checked: monitoringGroupBy,
                        width: 252,
                        onPressed: () =>
                            monitoringView.setGroupByGroup(!monitoringGroupBy),
                      ),
                    ],
                    child: const Text('Monitoring Table'),
                  ),
                ],
                child: const Text('View'),
              ),

              // ── Help ──────────────────────────────────────────────────────
              SubmenuButton(
                menuChildren: [
                  _menuItem(
                    context,
                    label: 'Keyboard Shortcuts',
                    width: _menuItemWidth,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const KeyboardShortcutsDialog(),
                    ),
                  ),
                  _menuItem(
                    context,
                    label: 'OSC Reference',
                    width: _menuItemWidth,
                    onPressed: () => DocsService.openOscReference(),
                  ),
                  _menuItem(
                    context,
                    label: 'Open Logs Folder',
                    width: _menuItemWidth,
                    onPressed: AppLog.openFolder,
                  ),
                  const Divider(),
                  _menuItem(
                    context,
                    label: 'About',
                    width: _menuItemWidth,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AppAboutDialog(),
                    ),
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
