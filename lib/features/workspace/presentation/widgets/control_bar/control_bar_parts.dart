import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../providers/workspace_provider.dart';
import '../common/app_dropdown.dart';
import '../common/dialog_parts.dart';

/// Spacing of the control bar, one set for every tab so the cards line up
/// when switching.
abstract final class ControlBarMetrics {
  /// Wide enough for `Standby` beside its icon in the Power row.
  static const double width = 344;

  /// Around the tab strip and the cards.
  static const double gutter = 12;

  /// Between two cards.
  static const double cardGap = 10;
  static const double cardPadding = 12;

  /// A card's header (30 px tile) to its content.
  static const double headerGap = 12;

  /// A row of the Power / Shutter / OSD card and the Quad Pixel Drive row.
  static const double commandRowHeight = 50;

  /// Every button and dropdown of the bar (owner, 2026-10-17): one height,
  /// so a Set next to a dropdown lines up with the Power buttons above.
  static const double commandButtonHeight = 36;

  /// Between two settings (label + dropdown) inside one card.
  static const double settingGap = 12;
}

/// Every command goes to the selected projectors. The buttons stay enabled
/// without a selection and then send nothing, so the bar doesn't rebuild on
/// every selection change.
void sendToSelected(WidgetRef ref, String cmd) =>
    ref.read(workspaceProvider.notifier).sendCommandToSelected(cmd);

/// A card of the control bar: [DialogCard] with an optional header (30 px
/// icon tile, sentence-case title, [trailing] on the right).
class ControlBarCard extends StatelessWidget {
  const ControlBarCard({
    super.key,
    required this.child,
    this.icon,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(ControlBarMetrics.cardPadding),
    this.headerGap = ControlBarMetrics.headerGap,
  });

  final IconData? icon;
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return DialogCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  if (icon != null) ...[
                    DialogIconTile(icon!, size: 30),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.of(context).cardTitle,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            SizedBox(height: headerGap),
          ],
          child,
        ],
      ),
    );
  }
}

/// The outlined style of the control bar's command buttons (visual rules
/// §6): many sit side by side, so none of them fills. Text in the primary
/// text colour rather than the M3 blue, which only means state.
/// [iconColor] marks what a button turns on or off (Power On green).
ButtonStyle commandButtonStyle(
  BuildContext context, {
  double height = ControlBarMetrics.commandButtonHeight,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10),
  OutlinedBorder shape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  ),
  Color? iconColor,
}) {
  final cs = Theme.of(context).colorScheme;
  final t = AppText.of(context);
  // The dropdowns' border, so a button next to one reads as the same family.
  final idle = cs.outline.withValues(alpha: 0.6);
  return OutlinedButton.styleFrom(
    minimumSize: Size(0, height),
    maximumSize: Size(double.infinity, height),
    // The theme's compact density takes 8 px off the minimum height.
    visualDensity: VisualDensity.standard,
    padding: padding,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: shape,
    foregroundColor: t.primary,
    disabledForegroundColor: t.disabled,
    iconColor: iconColor ?? t.secondary,
    disabledIconColor: t.disabled,
    iconSize: 18,
    textStyle: t.body.copyWith(fontWeight: FontWeight.w500),
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? idle.withValues(alpha: 0.3)
            : idle,
      ),
    ),
  );
}

/// The tonal style of the send buttons (*Set*, *Show*, *Run*, visual rules
/// §6): they send what is picked next to them, so they stand out from the
/// outlined On / Off pairs.
ButtonStyle sendButtonStyle(
  BuildContext context, {
  double height = ControlBarMetrics.commandButtonHeight,
}) {
  final cs = Theme.of(context).colorScheme;
  final t = AppText.of(context);
  return FilledButton.styleFrom(
    minimumSize: Size(0, height),
    maximumSize: Size(double.infinity, height),
    visualDensity: VisualDensity.standard,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    backgroundColor: cs.primaryContainer,
    foregroundColor: cs.onPrimaryContainer,
    iconColor: cs.onPrimaryContainer,
    iconSize: 18,
    textStyle: t.body.copyWith(fontWeight: FontWeight.w600),
  );
}

/// One command button: an optional 18 px icon and a label. [widestLabel]
/// keeps the width of the longest label the button family shows (Set and
/// Show share one width, so the dropdowns beside them line up). [tonal]
/// for a send button, [iconColor] for an On / Off pair. [alignStart] puts
/// the icon at a fixed inset from the left edge, so in a column of buttons
/// (Power, Shutter, OSD) the icons and the labels each line up.
class CommandButton extends StatelessWidget {
  const CommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.widestLabel,
    this.tonal = false,
    this.alignStart = false,
    this.height = ControlBarMetrics.commandButtonHeight,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final String? widestLabel;
  final bool tonal;
  final bool alignStart;
  final double height;

  @override
  Widget build(BuildContext context) {
    final widest = widestLabel;
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final content = Row(
      mainAxisSize: alignStart ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon), SizedBox(width: alignStart ? 10 : 6)],
        Flexible(
          child: widest == null
              ? text
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text(widest, maxLines: 1),
                    ),
                    text,
                  ],
                ),
        ),
      ],
    );
    return tonal
        ? FilledButton(
            style: sendButtonStyle(context, height: height),
            onPressed: onPressed,
            child: content,
          )
        : OutlinedButton(
            style: commandButtonStyle(
              context,
              height: height,
              padding: alignStart
                  ? const EdgeInsets.only(left: 12, right: 10)
                  : const EdgeInsets.symmetric(horizontal: 10),
              iconColor: iconColor,
            ),
            onPressed: onPressed,
            child: content,
          );
  }
}

/// A 50 px row: label on the left, two command buttons sharing the rest.
class CommandRow extends StatelessWidget {
  const CommandRow({
    super.key,
    required this.label,
    required this.first,
    required this.second,
    this.labelWidth = 64,
  });

  final String label;
  final Widget first;
  final Widget second;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ControlBarMetrics.commandRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.of(context).body
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: first),
          const SizedBox(width: 8),
          Expanded(child: second),
        ],
      ),
    );
  }
}

/// Divider between the rows of one card.
class CardRowDivider extends StatelessWidget {
  const CardRowDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
  );
}

/// A dropdown and its send button (`Set`, or `Show` for test patterns),
/// with an optional label above.
class DropdownSendRow<T> extends StatelessWidget {
  const DropdownSendRow({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.onSend,
    this.label,
    this.sendLabel = 'Set',
    this.menuHeight = 260,
  });

  final String? label;
  final List<AppDropdownItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  final VoidCallback onSend;
  final String sendLabel;
  final double menuHeight;

  /// Every send button of the bar is as wide as this label.
  static const widestSendLabel = 'Show';

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: AppDropdown<T>(
            items: items,
            value: value,
            onChanged: onChanged,
            menuHeight: menuHeight,
            height: ControlBarMetrics.commandButtonHeight,
          ),
        ),
        const SizedBox(width: 8),
        CommandButton(
          label: sendLabel,
          widestLabel: widestSendLabel,
          tonal: true,
          onPressed: onSend,
        ),
      ],
    );
    final label = this.label;
    return label == null ? row : LabeledField(label: label, child: row);
  }
}

/// Builds dropdown items from an NTCONTROL command to label map.
List<AppDropdownItem<String>> dropdownItems(
  Map<String, String> options, {
  Widget? Function(String value)? leading,
}) => [
  for (final e in options.entries)
    AppDropdownItem(
      value: e.key,
      label: e.value,
      leading: leading?.call(e.key),
    ),
];

/// A round outlined button with one of the lens chevron SVGs
/// (`assets/icons/lens_shift/`).
class LensStepButton extends StatelessWidget {
  const LensStepButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.size = 38,
  });

  final String asset;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox.square(
      dimension: size,
      child: OutlinedButton(
        style: commandButtonStyle(
          context,
          height: size,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        child: SvgPicture.asset(
          asset,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            onPressed == null ? t.disabled : t.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
