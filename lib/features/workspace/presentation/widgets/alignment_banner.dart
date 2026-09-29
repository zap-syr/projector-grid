import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alignment.dart';
import '../../domain/card_layout.dart';
import '../../domain/projector_node.dart';
import '../../domain/test_patterns.dart';
import '../providers/alignment_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/workspace_provider.dart';
import 'brightness_control_dialog.dart';
import 'color_correction_dialog.dart';
import 'common/menu_check_gutter.dart';
import 'geometry_correction_dialog.dart';

/// Toolbar / menu / Ctrl+L entry point. Alignment works on the canvas, so
/// entering from Monitoring switches to Controls first.
void toggleAlignmentMode(WidgetRef ref) {
  final alignment = ref.read(alignmentProvider);
  if (alignment.busy) return;
  if (!alignment.active) {
    ref.read(appSettingsProvider.notifier).setMonitoringView(false);
  }
  ref.read(alignmentProvider.notifier).toggle();
}

/// The one-row Alignment mode bar above the canvas (ROADMAP_PLAN.md §3.2,
/// Variant A). Collapses to nothing when the mode is off.
class AlignmentBanner extends ConsumerWidget {
  const AlignmentBanner({super.key});

  static const double height = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alignmentProvider);
    if (!state.active && !state.busy) return const SizedBox.shrink();

    const onColor = AppTheme.onAlignmentAccent;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.alignmentAccent(Theme.of(context).brightness),
      child: IconTheme.merge(
        data: IconThemeData(color: onColor, size: 18),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: onColor, fontSize: 13),
          child: state.active
              ? LayoutBuilder(
                  builder: (_, constraints) => _ActiveRow(
                    state: state,
                    width: constraints.maxWidth,
                    dialogContext: context,
                  ),
                )
              : const _BusyRow(),
        ),
      ),
    );
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.onAlignmentAccent,
          ),
        ),
        const SizedBox(width: 10),
        const Text('Alignment — reading / restoring projectors…'),
      ],
    );
  }
}

class _ActiveRow extends ConsumerWidget {
  const _ActiveRow({
    required this.state,
    required this.width,
    required this.dialogContext,
  });

  final AlignmentState state;
  final double width;

  /// Context above the banner's dark icon/text theme. `showDialog` carries
  /// the caller's inherited themes into the dialog, so opening from inside
  /// the banner turned the dialogs' close buttons and steppers dark.
  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(alignmentProvider.notifier);
    final nodes = ref.watch(workspaceProvider);
    final order = layoutOrder(nodes.where((n) => state.scope.contains(n.id)));
    final index = order.indexWhere((n) => n.id == state.focusedId);
    final focused = index < 0 ? null : order[index];
    final wide = width >= 900;
    final compact = width < 600;

    return Row(
      children: [
        const Icon(Icons.center_focus_strong),
        const SizedBox(width: 4),
        _BannerIcon(icon: Icons.chevron_left, onPressed: notifier.previous),
        SizedBox(
          width: 40,
          // Digits have no descenders, so the line box's centre sits below
          // theirs; the bottom inset lines them up with the arrow icons.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${index + 1}/${order.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        _BannerIcon(icon: Icons.chevron_right, onPressed: notifier.next),
        const SizedBox(width: 6),
        _BannerToggle(
          label: 'Neighbours',
          icon: Icons.view_column_outlined,
          selected: state.showNeighbours,
          wide: wide,
          onPressed: notifier.toggleNeighbours,
        ),
        const SizedBox(width: 6),
        _BannerToggle(
          label: 'Show All',
          icon: Icons.grid_view,
          selected: state.showAll,
          wide: wide,
          onPressed: notifier.toggleShowAll,
        ),
        const SizedBox(width: 6),
        _PresetsMenu(state: state, compact: compact),
        const SizedBox(width: 6),
        _AdjustMenu(
          node: focused,
          compact: compact,
          dialogContext: dialogContext,
        ),
        const Spacer(),
        compact
            ? _BannerIcon(
                icon: Icons.close,
                tooltip: 'Exit',
                onPressed: notifier.exit,
              )
            : TextButton(
                onPressed: notifier.exit,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.onAlignmentAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Exit'),
              ),
      ],
    );
  }
}

class _BannerIcon extends StatelessWidget {
  const _BannerIcon({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.alignmentAccent(Theme.of(context).brightness);
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: selected ? accent : AppTheme.onAlignmentAccent,
        backgroundColor: selected ? AppTheme.onAlignmentAccent : null,
      ),
    );
  }
}

/// Styled like the Presets / Adjust buttons so it doesn't outweigh them;
/// when on, it turns into a solid dark pill with accent text. Icon-only on narrower
/// banners.
class _BannerToggle extends StatelessWidget {
  const _BannerToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.wide,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool wide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return _BannerIcon(
        icon: icon,
        tooltip: label,
        selected: selected,
        onPressed: onPressed,
      );
    }
    final accent = AppTheme.alignmentAccent(Theme.of(context).brightness);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected ? accent : AppTheme.onAlignmentAccent,
        backgroundColor: selected ? AppTheme.onAlignmentAccent : null,
        visualDensity: VisualDensity.compact,
        // Same weight on and off: a bolder label would widen the button and
        // nudge everything after it.
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.controller,
    required this.icon,
    required this.label,
    required this.compact,
  });

  final MenuController controller;
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void toggle() => controller.isOpen ? controller.close() : controller.open();
    if (compact) {
      return _BannerIcon(icon: icon, tooltip: label, onPressed: toggle);
    }
    return TextButton.icon(
      onPressed: toggle,
      icon: Icon(icon),
      label: Text('$label ▾'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.onAlignmentAccent,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Preset, Focused and Others pattern pickers plus the diagonal-neighbour
/// option — rarely changed, so kept out of the banner row itself.
class _PresetsMenu extends ConsumerStatefulWidget {
  const _PresetsMenu({required this.state, required this.compact});

  final AlignmentState state;
  final bool compact;

  @override
  ConsumerState<_PresetsMenu> createState() => _PresetsMenuState();
}

class _PresetsMenuState extends ConsumerState<_PresetsMenu> {
  final _controller = MenuController();

  // Wide enough for "Cross Hatch Magenta" plus the pattern icon.
  static const double _patternLabelWidth = 170;

  // Custom lists every pattern; cap the submenu so it scrolls instead of
  // running the full height of the window.
  static const _patternMenuStyle = MenuStyle(
    maximumSize: WidgetStatePropertyAll(Size(double.infinity, 360)),
  );

  Widget _check(bool on) => MenuCheckGutter(checked: on);

  Widget _patternItem(String code, bool checked, VoidCallback onPressed) {
    final icon = kTestPatternIcons[code];
    return MenuItemButton(
      leadingIcon: _check(checked),
      trailingIcon: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 12, right: 6),
              child: SvgPicture.asset(icon, width: 18, height: 18),
            ),
      onPressed: onPressed,
      child: SizedBox(
        width: _patternLabelWidth,
        child: Text(testPatternLabel(code)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(alignmentProvider.notifier);
    final patterns = state.preset.patterns;
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        SubmenuButton(
          menuChildren: [
            for (final p in AlignmentPreset.values)
              MenuItemButton(
                leadingIcon: _check(p == state.preset),
                onPressed: () => notifier.setPreset(p),
                child: Text(p.label),
              ),
          ],
          leadingIcon: _check(false),
          child: const Text('Preset'),
        ),
        SubmenuButton(
          menuChildren: [
            for (final code in patterns)
              _patternItem(
                code,
                code == state.focusedPattern,
                () => notifier.setFocusedPattern(code),
              ),
          ],
          menuStyle: _patternMenuStyle,
          leadingIcon: _check(false),
          child: const Text('Focused'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              leadingIcon: _check(state.othersPattern == null),
              onPressed: () => notifier.setOthersPattern(null),
              child: const SizedBox(
                width: _patternLabelWidth,
                child: Text('Same as focused'),
              ),
            ),
            for (final code in patterns)
              _patternItem(
                code,
                code == state.othersPattern,
                () => notifier.setOthersPattern(code),
              ),
          ],
          menuStyle: _patternMenuStyle,
          leadingIcon: _check(false),
          child: const Text('Others'),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: _check(state.includeDiagonals),
          closeOnActivate: false,
          onPressed: notifier.toggleDiagonals,
          child: const Text('Diagonal neighbours'),
        ),
      ],
      child: _MenuButton(
        controller: _controller,
        icon: Icons.tune,
        label: 'Presets',
        compact: widget.compact,
      ),
    );
  }
}

/// Opens an adjustment dialog for the focused projector.
class _AdjustMenu extends StatefulWidget {
  const _AdjustMenu({
    required this.node,
    required this.compact,
    required this.dialogContext,
  });

  final ProjectorNode? node;
  final bool compact;
  final BuildContext dialogContext;

  @override
  State<_AdjustMenu> createState() => _AdjustMenuState();
}

class _AdjustMenuState extends State<_AdjustMenu> {
  final _controller = MenuController();

  void _open(Widget Function(ProjectorNode node) dialog) {
    final node = widget.node;
    if (node == null) return;
    showDialog(context: widget.dialogContext, builder: (_) => dialog(node));
  }

  // Items get room on both sides instead of hugging the menu's edges.
  Widget _item(IconData icon, String label, VoidCallback onPressed) =>
      MenuItemButton(
        style: MenuItemButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        leadingIcon: Icon(icon, size: 18),
        onPressed: onPressed,
        child: SizedBox(width: 150, child: Text(label)),
      );

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        _item(
          Icons.grid_4x4_outlined,
          'Geometry',
          () => _open((n) => GeometryCorrectionDialog(node: n)),
        ),
        _item(
          Icons.brightness_6,
          'Brightness',
          () => _open((n) => BrightnessControlDialog(node: n)),
        ),
        _item(
          Icons.tune,
          'Color Correction',
          () => _open((n) => ColorCorrectionDialog(node: n)),
        ),
      ],
      child: _MenuButton(
        controller: _controller,
        icon: Icons.build_outlined,
        label: 'Adjust',
        compact: widget.compact,
      ),
    );
  }
}
