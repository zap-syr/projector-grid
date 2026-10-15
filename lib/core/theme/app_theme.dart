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

  /// Fill of a key cap (Keyboard Shortcuts, tooltip shortcuts).
  final Color keyCap;

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
    keyCap: Color(0xFF3A3F47),
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
    );
  }
}

class AppTheme {
  /// Radius every dialog shares; set once in [DialogThemeData].
  static const double dialogRadius = 20;

  /// The one monospace style for IPs, ports, commands and OSC addresses.
  /// A bare `fontFamily: 'monospace'` falls back to Courier New on Windows.
  static TextStyle mono([TextStyle? base]) =>
      (base ?? const TextStyle()).merge(monoStyle);

  /// [mono] as a const, for `static const` styles.
  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'Cascadia Mono',
    fontFamilyFallback: ['Consolas', 'SF Mono', 'Menlo', 'monospace'],
    fontFeatures: [FontFeature.tabularFigures()],
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
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      ),
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
