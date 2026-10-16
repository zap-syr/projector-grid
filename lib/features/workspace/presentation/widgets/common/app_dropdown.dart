import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

import 'dialog_parts.dart';

class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.menuTitle,
    this.detail,
  });

  final T value;

  /// Shown in the field once picked, and in the list unless [menuTitle]
  /// is set.
  final String label;

  /// The list row's own text when [detail] already carries part of [label]
  /// (the interface name, with its IP as the detail).
  final String? menuTitle;

  /// Muted monospace text at the right of the list row (an interface's IP).
  final String? detail;
}

/// The app's dropdown: a field whose list opens right under it at the
/// field's own width (an M3 [DropdownMenu]), not Flutter's classic popup
/// over the field. The control bar uses the same widget in its pill shape.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.height = dialogFieldHeight,
    this.radius = 10,
    this.menuHeight = 260,
  });

  final List<AppDropdownItem<T>> items;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final double height;
  final double radius;
  final double menuHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );
    final idle = cs.outline.withValues(alpha: 0.6);
    return Theme(
      data: Theme.of(context).copyWith(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: DropdownMenu<T>(
        // A new list of items (e.g. interfaces read later) must rebuild the
        // field's text, which DropdownMenu only reads from initialSelection
        // on first build.
        key: ValueKey(Object.hashAll([value, ...items.map((i) => i.value)])),
        enabled: onChanged != null,
        requestFocusOnTap: false,
        enableFilter: false,
        expandedInsets: EdgeInsets.zero,
        menuHeight: menuHeight,
        initialSelection: value,
        textStyle: plainFieldStyle,
        trailingIcon: const UnconstrainedBox(
          child: Icon(Icons.expand_more, size: 20),
        ),
        selectedTrailingIcon: const UnconstrainedBox(
          child: Icon(Icons.expand_less, size: 20),
        ),
        inputDecorationTheme: InputDecorationTheme(
          constraints: BoxConstraints.tightFor(height: height),
          isDense: true,
          filled: true,
          fillColor: DialogSurfaces.of(context).field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          suffixIconConstraints: BoxConstraints(
            minHeight: height,
            minWidth: 36,
          ),
          border: border(idle),
          enabledBorder: border(idle),
          disabledBorder: border(idle.withValues(alpha: 0.3)),
          focusedBorder: border(cs.primary, 2),
        ),
        menuStyle: MenuStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
        ),
        dropdownMenuEntries: [
          for (final item in items)
            DropdownMenuEntry<T>(
              value: item.value,
              label: item.label,
              labelWidget: Text(
                item.menuTitle ?? item.label,
                overflow: TextOverflow.ellipsis,
              ),
              trailingIcon: item.detail == null
                  ? null
                  : Text(item.detail!, style: AppText.of(context).monoSmall),
            ),
        ],
        onSelected: (v) {
          if (v != null) onChanged?.call(v);
        },
      ),
    );
  }
}
