import 'package:flutter/material.dart';

/// Plink's look, matched to the SwiftUI app: iOS system neutrals (white or
/// black backgrounds, gray fills, secondary-label grays) with the amber
/// AccentColor as the only tint. Material's seeded palettes tint every
/// surface with the accent, which the iOS app never does, so the scheme is
/// spelled out instead.
@immutable
class PlinkPalette extends ThemeExtension<PlinkPalette> {
  const PlinkPalette({
    required this.background,
    required this.groupedBackground,
    required this.groupedCell,
    required this.card,
    required this.fill,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.sidebar,
    required this.cardShadow,
  });

  /// systemBackground
  final Color background;

  /// systemGroupedBackground (Settings, forms)
  final Color groupedBackground;

  /// secondarySystemGroupedBackground (rows inside grouped sections)
  final Color groupedCell;

  /// Card background (`.regularMaterial` over the page)
  final Color card;

  /// Placeholder and search-field fill (`.quaternary` / tertiarySystemFill)
  final Color fill;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color sidebar;
  final Color cardShadow;

  static const light = PlinkPalette(
    background: Color(0xFFFFFFFF),
    groupedBackground: Color(0xFFF2F2F7),
    groupedCell: Color(0xFFFFFFFF),
    card: Color(0xFFF7F7F8),
    fill: Color(0xFFEEEEF0),
    label: Color(0xFF000000),
    secondaryLabel: Color(0xFF8A8A8E),
    tertiaryLabel: Color(0xFFC4C4C7),
    separator: Color(0xFFDCDCE0),
    sidebar: Color(0xFFF2F2F7),
    cardShadow: Color(0x14000000),
  );

  static const dark = PlinkPalette(
    background: Color(0xFF000000),
    groupedBackground: Color(0xFF000000),
    groupedCell: Color(0xFF1C1C1E),
    card: Color(0xFF1C1C1E),
    fill: Color(0xFF242426),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF8D8D93),
    tertiaryLabel: Color(0xFF48484A),
    separator: Color(0xFF38383A),
    sidebar: Color(0xFF111112),
    cardShadow: Color(0x00000000),
  );

  static PlinkPalette of(BuildContext context) =>
      Theme.of(context).extension<PlinkPalette>()!;

  @override
  PlinkPalette copyWith() => this;

  @override
  PlinkPalette lerp(PlinkPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// The SwiftUI AccentColor asset (no separate dark variant).
const plinkAccent = Color(0xFFD88A1A);
const _destructive = Color(0xFFFF3B30);
const _destructiveDark = Color(0xFFFF453A);

ThemeData plinkTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? PlinkPalette.dark : PlinkPalette.light;
  final accentSoft = plinkAccent.withValues(alpha: dark ? 0.24 : 0.14);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: plinkAccent,
    onPrimary: Colors.white,
    primaryContainer: accentSoft,
    onPrimaryContainer: plinkAccent,
    secondary: plinkAccent,
    onSecondary: Colors.white,
    secondaryContainer: accentSoft,
    onSecondaryContainer: p.label,
    tertiary: plinkAccent,
    onTertiary: Colors.white,
    error: dark ? _destructiveDark : _destructive,
    onError: Colors.white,
    surface: p.background,
    onSurface: p.label,
    onSurfaceVariant: p.secondaryLabel,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.sidebar,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.groupedCell,
    surfaceContainerHighest: p.fill,
    surfaceTint: Colors.transparent,
    outline: p.separator,
    outlineVariant: p.separator,
    shadow: Colors.black,
    inverseSurface: dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
    onInverseSurface: dark ? Colors.black : Colors.white,
    inversePrimary: plinkAccent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );
  final text = _tight(
    base.textTheme.apply(bodyColor: p.label, displayColor: p.label),
  );
  const stadium = StadiumBorder();
  final rounded12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.separator,
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.fill.withValues(alpha: 0.6),
    textTheme: text.copyWith(
      // Large navigation title, like `.navigationTitle` on iOS.
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: text.bodySmall?.copyWith(
        fontSize: 12,
        color: p.secondaryLabel,
      ),
    ),
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.label,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.label,
      ),
      iconTheme: IconThemeData(color: p.label),
      actionsIconTheme: IconThemeData(color: p.label),
    ),
    iconTheme: IconThemeData(color: p.label),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.label),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: plinkAccent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.fill,
        disabledForegroundColor: p.tertiaryLabel,
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: plinkAccent,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: plinkAccent,
        backgroundColor: p.fill,
        side: BorderSide.none,
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(p.fill),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: const WidgetStatePropertyAll(stadium),
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      hintStyle: WidgetStatePropertyAll(
        TextStyle(color: p.secondaryLabel, fontSize: 17),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(color: p.label, fontSize: 17),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.fill,
      hintStyle: TextStyle(color: p.secondaryLabel),
      labelStyle: TextStyle(color: p.secondaryLabel),
      floatingLabelStyle: const TextStyle(color: plinkAccent),
      helperStyle: TextStyle(color: p.secondaryLabel),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: plinkAccent, width: 1.5),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: plinkAccent,
      selectionColor: plinkAccent.withValues(alpha: 0.3),
      selectionHandleColor: plinkAccent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: p.fill,
      indicatorShape: stadium,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: s.contains(WidgetState.selected) ? plinkAccent : p.label,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? plinkAccent : p.label,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF2C2C2E) : p.groupedCell,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: text.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.label,
      ),
      contentTextStyle: text.bodyMedium?.copyWith(color: p.label),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? const Color(0xFF2C2C2E) : p.groupedCell,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black38,
      shape: rounded12,
      textStyle: text.bodyLarge?.copyWith(color: p.label),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: plinkAccent,
      textColor: p.label,
      selectedColor: Colors.white,
      selectedTileColor: plinkAccent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.fill,
      side: BorderSide.none,
      shape: stadium,
      labelStyle: TextStyle(color: p.label),
      iconTheme: const IconThemeData(color: plinkAccent, size: 18),
      deleteIconColor: p.secondaryLabel,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? plinkAccent : null,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: p.tertiaryLabel, width: 1.5),
      shape: const CircleBorder(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.secondaryLabel),
    dividerTheme: DividerThemeData(color: p.separator, thickness: 0.5),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: plinkAccent,
      shape: rounded12,
      elevation: 4,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A3A3C) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

/// iOS text has no extra tracking; Material's defaults add up to 0.5pt.
TextTheme _tight(TextTheme t) => t.copyWith(
  displayLarge: t.displayLarge?.copyWith(letterSpacing: 0),
  displayMedium: t.displayMedium?.copyWith(letterSpacing: 0),
  displaySmall: t.displaySmall?.copyWith(letterSpacing: 0),
  headlineLarge: t.headlineLarge?.copyWith(letterSpacing: 0),
  headlineMedium: t.headlineMedium?.copyWith(letterSpacing: 0),
  headlineSmall: t.headlineSmall?.copyWith(letterSpacing: 0),
  titleLarge: t.titleLarge?.copyWith(letterSpacing: 0),
  titleMedium: t.titleMedium?.copyWith(letterSpacing: 0),
  titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
  bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
  bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
  bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
  labelLarge: t.labelLarge?.copyWith(letterSpacing: 0),
  labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
  labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
);
