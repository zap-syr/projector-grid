import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../providers/selection_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/app_dropdown.dart';
import '../common/dialog_parts.dart';

/// Spacing of the control bar, one set for every tab so the cards line up
/// when switching.
abstract final class ControlBarMetrics {
  static const double width = 320;

  /// Around the tab strip and the cards.
  static const double gutter = 12;

  /// Between two cards.
  static const double cardGap = 10;
  static const double cardPadding = 12;

  /// A card's header (30 px tile) to its content.
  static const double headerGap = 12;

  /// A row of the Power / Shutter / OSD card and the Quad Pixel Drive row.
  static const double commandRowHeight = 50;
  static const double commandButtonHeight = 36;

  /// Between two settings (label + dropdown) inside one card.
  static const double settingGap = 12;
}

/// Whether anything is selected: every command goes to the selected
/// projectors, so without a selection the buttons are disabled.
bool watchHasSelection(WidgetRef ref) =>
    ref.watch(selectionProvider.select((ids) => ids.isNotEmpty));

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

/// Quiet text on the right of a card header (`seconds`, `Favorites`).
class CardHeaderNote extends StatelessWidget {
  const CardHeaderNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.of(context).caption);
}

/// The outlined style of the control bar's command buttons (visual rules
/// §6): many sit side by side, so none of them fills. Text in the primary
/// text colour rather than the M3 blue, which only means state.
ButtonStyle commandButtonStyle(
  BuildContext context, {
  double height = ControlBarMetrics.commandButtonHeight,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10),
  OutlinedBorder shape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  ),
}) {
  final cs = Theme.of(context).colorScheme;
  final t = AppText.of(context);
  // The dropdowns' border, so a button next to one reads as the same family.
  final idle = cs.outline.withValues(alpha: 0.6);
  return OutlinedButton.styleFrom(
    minimumSize: Size(0, height),
    maximumSize: Size(double.infinity, height),
    padding: padding,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: shape,
    foregroundColor: t.primary,
    disabledForegroundColor: t.disabled,
    iconColor: t.secondary,
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

/// One command button: an optional 18 px icon and a label. [widestLabel]
/// keeps the width of the longest label the button family shows (Set and
/// Show share one width, so the dropdowns beside them line up).
class CommandButton extends StatelessWidget {
  const CommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.widestLabel,
    this.height = ControlBarMetrics.commandButtonHeight,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? widestLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final widest = widestLabel;
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return OutlinedButton(
      style: commandButtonStyle(context, height: height),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon), const SizedBox(width: 6)],
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
      ),
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
/// with an optional label above. The dropdown stays usable without a
/// selection, as before; only the button needs one.
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

  /// Null disables the button.
  final VoidCallback? onSend;
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
          ),
        ),
        const SizedBox(width: 8),
        CommandButton(
          label: sendLabel,
          widestLabel: widestSendLabel,
          height: dialogFieldHeight,
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
    this.size = 34,
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
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            onPressed == null ? t.disabled : t.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
