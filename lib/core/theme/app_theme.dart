import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => _base(Brightness.light);

  static ThemeData get darkTheme => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: brightness,
    );

    // Pop-up surfaces (right-click MenuAnchor, DropdownMenu list, submenus,
    // PopupMenuButton) render with no border by default in M3 — just a faint
    // shadow and tonal tint that all but vanishes on the light theme. Give
    // them an opaque container colour, a visible 1px outline and a real
    // shadow so they read as a distinct layer above the content.
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: colorScheme.outlineVariant),
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(colorScheme.shadow),
      elevation: const WidgetStatePropertyAll(8),
      side: WidgetStatePropertyAll(
        BorderSide(color: colorScheme.outlineVariant),
      ),
      shape: WidgetStatePropertyAll(menuShape),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.compact,
      // Right-click context menus and DropdownMenu popups both resolve their
      // container style through MenuThemeData.
      menuTheme: MenuThemeData(style: menuStyle),
      // DropdownMenu's own popup list falls back to this before MenuThemeData.
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
      // PopupMenuButton / showMenu use a separate theme object.
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow,
        elevation: 8,
        shape: menuShape,
      ),
    );
  }
}
