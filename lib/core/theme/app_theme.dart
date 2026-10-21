import 'package:flutter/material.dart';

/// Status colours M3's [ColorScheme] has no roles for: success green, warning
/// amber, the muted red / green of the − / + step buttons, and the raised
/// tooltip surface. Read with `AppStatusColors.of(context)`.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarning,
    required this.mutedMinus,
    required this.mutedPlus,
    required this.tooltipBackground,
    required this.tooltipBorder,
    required this.keyCap,
    required this.keyCapBorder,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;

  /// Text and icons on a solid [warning] fill.
  final Color onWarning;
  final Color mutedMinus;
  final Color mutedPlus;
  final Color tooltipBackground;
  final Color tooltipBorder;

  /// Fill and border of a key cap (Keyboard Shortcuts, tooltip shortcuts),
  /// the mockup's values.
  final Color keyCap;
  final Color keyCapBorder;

  static const light = AppStatusColors(
    success: Color(0xFF1E7B3A),
    successContainer: Color(0xFFD5EEDB),
    warning: Color(0xFF8A5300),
    warningContainer: Color(0xFFFBE7C6),
    onWarning: Color(0xFFFFFFFF),
    mutedMinus: Color(0xFFB0504A),
    mutedPlus: Color(0xFF3C8A52),
    tooltipBackground: Color(0xFFFFFFFF),
    tooltipBorder: Color(0xFFD6D5DA),
    keyCap: Color(0xFFF0EFF3),
    keyCapBorder: Color(0xFFC9C8CE),
  );

  static const dark = AppStatusColors(
    success: Color(0xFF6DD58C),
    successContainer: Color(0xFF1E3A27),
    warning: Color(0xFFF5B544),
    warningContainer: Color(0xFF3D2E12),
    onWarning: Color(0xFF2A1A00),
    mutedMinus: Color(0xFFE09A94),
    mutedPlus: Color(0xFF8CCB9C),
    tooltipBackground: Color(0xFF2E3238),
    tooltipBorder: Color(0xFF42464E),
    keyCap: Color(0xFF2C2F35),
    keyCapBorder: Color(0xFF53565F),
  );

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>()!;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarning,
    Color? mutedMinus,
    Color? mutedPlus,
    Color? tooltipBackground,
    Color? tooltipBorder,
    Color? keyCap,
    Color? keyCapBorder,
  }) => AppStatusColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarning: onWarning ?? this.onWarning,
    mutedMinus: mutedMinus ?? this.mutedMinus,
    mutedPlus: mutedPlus ?? this.mutedPlus,
    tooltipBackground: tooltipBackground ?? this.tooltipBackground,
    tooltipBorder: tooltipBorder ?? this.tooltipBorder,
    keyCap: keyCap ?? this.keyCap,
    keyCapBorder: keyCapBorder ?? this.keyCapBorder,
  );

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      mutedMinus: Color.lerp(mutedMinus, other.mutedMinus, t)!,
      mutedPlus: Color.lerp(mutedPlus, other.mutedPlus, t)!,
      tooltipBackground: Color.lerp(
        tooltipBackground,
        other.tooltipBackground,
        t,
      )!,
      tooltipBorder: Color.lerp(tooltipBorder, other.tooltipBorder, t)!,
      keyCap: Color.lerp(keyCap, other.keyCap, t)!,
      keyCapBorder: Color.lerp(keyCapBorder, other.keyCapBorder, t)!,
    );
  }
}

/// The type scale of the redesigned dialogs (owner, 2026-10-16), already in
/// the text colours of the theme: `final t = AppText.of(context)`, then
/// `Text('…', style: t.description)`. Widgets take a role from here instead
/// of a `fontSize` of their own; a one-off tweak is a `copyWith` of a role.
///
/// Text colours: [primary] (onSurface), [secondary] (onSurfaceVariant: field
/// labels, descriptions, help lines), [tertiary] (outline: captions, scale
/// labels, placeholders), [disabled] (onSurface at 38 %, disabled controls
/// only).
@immutable
class AppText {
  AppText._(ColorScheme cs)
    : primary = cs.onSurface,
      secondary = cs.onSurfaceVariant,
      tertiary = cs.outline,
      disabled = cs.onSurface.withValues(alpha: 0.38),
      hero = _role(22, FontWeight.w700, cs.onSurface),
      dialogTitle = _role(16, FontWeight.w600, cs.onSurface),
      cardTitle = _role(15, FontWeight.w600, cs.onSurface),
      label = _role(12.5, FontWeight.w600, cs.onSurfaceVariant),
      body = _role(14, FontWeight.w400, cs.onSurface),
      description = _role(12.5, FontWeight.w400, cs.onSurfaceVariant),
      caption = _role(11.5, FontWeight.w500, cs.outline),
      value = _role(
        26,
        FontWeight.w600,
        cs.onSurface,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      mono = AppTheme.mono(TextStyle(fontSize: 13.5, color: cs.onSurface)),
      monoSmall = AppTheme.mono(
        TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      );

  factory AppText.of(BuildContext context) =>
      AppText._(Theme.of(context).colorScheme);

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color disabled;

  /// 22, w700: the app name in About, the one hero line in the app.
  final TextStyle hero;

  /// 16, w600: the dialog title in the title bar, a confirm dialog's title.
  final TextStyle dialogTitle;

  /// 15, w600: the title of a card or section.
  final TextStyle cardTitle;

  /// 12.5, w600, secondary: the label above a field, a small header.
  final TextStyle label;

  /// 14, w400: body text, list rows, field values, buttons.
  final TextStyle body;

  /// 12.5, w400, secondary: a card subtitle, a help line, a footer message.
  final TextStyle description;

  /// 11.5, w500, tertiary: scale labels, counters, legends, small pills.
  final TextStyle caption;

  /// 26, w600, tabular: the large value of a card (`85%`).
  final TextStyle value;

  /// 13.5 IBM Plex Mono: IPs, ports, commands and OSC addresses in fields
  /// and rows.
  final TextStyle mono;

  /// 12 IBM Plex Mono, secondary: model + IP under a title, small chips.
  final TextStyle monoSmall;

  static TextStyle _role(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: AppTheme.tracking(size),
      );
}

class AppTheme {
  /// Radius every dialog shares; set once in [DialogThemeData].
  static const double dialogRadius = 20;

  /// The UI font, bundled (pubspec `fonts:`, OFL in `LicenseRegistry`) so the
  /// app looks the same on Windows and macOS; chosen by the owner on
  /// 2026-10-16. Plus Jakarta Sans is bundled too, and switching to it is
  /// this name alone; another font is this name plus the pubspec entry and
  /// the licence. Widgets never name a font.
  static const String fontFamily = 'Inter';

  /// Letter spacing for [fontFamily] at [size]: +1 % for text up to 14 px,
  /// where the font is tight, none for titles and large values.
  static double tracking(double size) => size <= 14 ? size * 0.01 : 0;

  /// The one monospace style for IPs, ports, commands and OSC addresses:
  /// IBM Plex Mono, bundled (pubspec `fonts:`), so it looks the same on
  /// every machine. A bare `fontFamily: 'monospace'` falls back to Courier
  /// New on Windows.
  static TextStyle mono([TextStyle? base]) =>
      (base ?? const TextStyle()).merge(monoStyle);

  /// [mono] as a const, for `static const` styles. No letter spacing: the
  /// UI font's tracking would otherwise carry over from the text theme.
  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'IBM Plex Mono',
    fontFamilyFallback: ['Consolas', 'Menlo', 'monospace'],
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0,
  );

  static TextStyle? _tracked(TextStyle? style) {
    final size = style?.fontSize;
    return size == null
        ? style
        : style!.copyWith(letterSpacing: tracking(size));
  }

  /// The M3 text theme with [tracking] instead of M3's own letter spacing,
  /// which was set for Roboto.
  static TextTheme _trackedTextTheme(TextTheme t) => TextTheme(
    displayLarge: _tracked(t.displayLarge),
    displayMedium: _tracked(t.displayMedium),
    displaySmall: _tracked(t.displaySmall),
    headlineLarge: _tracked(t.headlineLarge),
    headlineMedium: _tracked(t.headlineMedium),
    headlineSmall: _tracked(t.headlineSmall),
    titleLarge: _tracked(t.titleLarge),
    titleMedium: _tracked(t.titleMedium),
    titleSmall: _tracked(t.titleSmall),
    bodyLarge: _tracked(t.bodyLarge),
    bodyMedium: _tracked(t.bodyMedium),
    bodySmall: _tracked(t.bodySmall),
    labelLarge: _tracked(t.labelLarge),
    labelMedium: _tracked(t.labelMedium),
    labelSmall: _tracked(t.labelSmall),
  );

  /// Alignment mode's accent: orange, opposite the blue selection accent, so
  /// its card rings and banner never blend with selection.
  static Color alignmentAccent(Brightness brightness) =>
      brightness == Brightness.light
      ? const Color(0xFFE8710A)
      : const Color(0xFFFF9E40);

  /// Ring of the focused projector's open neighbours: a paler tone of
  /// [alignmentAccent], so neighbours read as related but clearly not the
  /// focused card.
  static Color alignmentNeighbour(Brightness brightness) =>
      brightness == Brightness.light
      ? const Color(0xFFF7B77E)
      : const Color(0xFFFFDDB3);

  /// Text and icons on [alignmentAccent].
  static const Color onAlignmentAccent = Color(0xFF231200);

  /// The inset between a menu's border and its items.
  static const double menuInset = 6;

  /// `alignmentOffset` of a submenu that opens beside its parent menu (not
  /// one dropping from the menu bar): a submenu opens at its item's right
  /// edge, which [menuInset] keeps inside the parent's border, so without
  /// it the submenu covers the parent's edge.
  static const Offset submenuOffset = Offset(menuInset, 0);

  /// The window behind the canvas and the lists. In dark mode `surface` is
  /// the darkest tone of the ramp with next to no blue, so the window takes
  /// the container ramp's low step, as in the redesign mockup.
  static Color windowBackground(ColorScheme cs) =>
      cs.brightness == Brightness.light ? cs.surface : cs.surfaceContainerLow;

  /// The toolbar, the status bar and the bars and headers of the panels: one
  /// step above [windowBackground] in dark mode.
  static Color chromeBackground(ColorScheme cs) =>
      cs.brightness == Brightness.light ? cs.surface : cs.surfaceContainer;

  static ThemeData get lightTheme => _base(Brightness.light);

  static ThemeData get darkTheme => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final statusColors = isLight ? AppStatusColors.light : AppStatusColors.dark;

    var colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: brightness,
      // Neutral variant strips most of the coloured undertone so the light
      // theme's near-whites read as plain grey instead of a cool blue tint.
      dynamicSchemeVariant: isLight
          ? DynamicSchemeVariant.neutral
          : DynamicSchemeVariant.tonalSpot,
    );

    // The default M3 light surfaces sit almost at pure white, which feels
    // harsh on a large desktop window. Pull the whole surface ramp down into
    // a soft grey while keeping cards slightly lighter than the canvas so the
    // layering still reads.
    if (isLight) {
      colorScheme = colorScheme.copyWith(
        surface: const Color(0xFFF6F5F7),
        surfaceBright: const Color(0xFFF6F5F7),
        surfaceDim: const Color(0xFFDDDCDE),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF1F0F2),
        surfaceContainer: const Color(0xFFEBEAEC),
        surfaceContainerHigh: const Color(0xFFE5E4E6),
        surfaceContainerHighest: const Color(0xFFDFDEE0),
      );

      // The neutral variant above desaturates the *entire* scheme it
      // derives to get those plain-grey surfaces — primary included, which
      // otherwise leaves buttons/tabs/segmented-selection a muted slate
      // (#595E6C) instead of a real accent. Re-derive just the accent roles
      // from the same seed through tonalSpot (the variant dark mode already
      // uses) and layer them back on, so the accent reads as intentional
      // colour again without reintroducing the blue tint the neutral
      // surfaces above exist to avoid.
      final accentScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8),
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      colorScheme = colorScheme.copyWith(
        primary: accentScheme.primary,
        onPrimary: accentScheme.onPrimary,
        secondaryContainer: accentScheme.secondaryContainer,
        onSecondaryContainer: accentScheme.onSecondaryContainer,
      );
    }

    // Pop-up surfaces (right-click MenuAnchor, DropdownMenu list, submenus,
    // PopupMenuButton) render with no border by default in M3 — just a faint
    // shadow and tonal tint that all but vanishes on the light theme. Give
    // them an opaque container colour, a visible 1px outline and a real
    // shadow so they read as a distinct layer above the content. Radius 12
    // with a 6 px inset and rounded item highlights, as the projector card's
    // context menu board, for every menu (owner, 2026-10-17).
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
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
      padding: const WidgetStatePropertyAll(EdgeInsets.all(menuInset)),
    );
    // The highlight of a hovered item, rounded inside the menu's inset.
    const menuItemShape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      // Canvas behind every screen — a touch darker than the surface ramp so
      // panels and cards lift off it.
      scaffoldBackgroundColor: isLight ? const Color(0xFFECECEF) : null,
      visualDensity: VisualDensity.compact,
      // One step below the DialogTitleBar header band's
      // surfaceContainerHigh, on the same container ramp — not the base
      // `surface` tone, which in dark mode is also scaffoldBackgroundColor's
      // fallback and would make every dialog read as sunk into the window
      // instead of floating above it.
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
      ),
      extensions: [statusColors],
      // Material tooltips (IconButton.tooltip and the like) take the same
      // raised surface as CustomTooltip, minus the arrow.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: statusColors.tooltipBackground,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: statusColors.tooltipBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.14 : 0.35),
              blurRadius: isLight ? 14 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: tracking(12.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      ),
      // Right-click context menus and DropdownMenu popups both resolve their
      // container style through MenuThemeData.
      menuTheme: MenuThemeData(style: menuStyle),
      menuButtonTheme: const MenuButtonThemeData(
        style: ButtonStyle(shape: menuItemShape),
      ),
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
    return theme.copyWith(
      textTheme: _trackedTextTheme(theme.textTheme),
      primaryTextTheme: _trackedTextTheme(theme.primaryTextTheme),
    );
  }
}
