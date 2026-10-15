import 'package:flutter/material.dart';

/// Named SmartSave design tokens. Use these instead of raw hex in UI code.
abstract final class SmartSaveTokens {
  /// Brand purple. Safe for white text (hero, selected chrome).
  static const Color primary = Color(0xFF6C5CB8);

  /// Soft purple. Decorative only — never put white text on this.
  static const Color primarySoft = Color(0xFFA99BDB);

  /// Coral-red for main actions. Use with white text.
  static const Color accent = Color(0xFFC9363F);

  /// Soft coral. Decorative only — never put white text on this.
  static const Color accentSoft = Color(0xFFF28B82);

  /// Primary body / heading ink.
  static const Color ink = Color(0xFF1F2347);

  /// Secondary copy and idle icons.
  static const Color inkSoft = Color(0xFF5A5F7A);

  /// App scaffold cream.
  static const Color background = Color(0xFFFFF6EE);

  /// Raised cards and bars.
  static const Color surface = Color(0xFFFFFFFF);

  /// Positive state. Always pair with an icon or the word Success.
  static const Color success = Color(0xFF2F8F5B);

  /// Informational state. Always pair with an icon or a word.
  static const Color info = Color(0xFF3A7CA5);

  /// White on [primary] / [accent] only — never on the Soft tokens.
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Card corner radius.
  static const double radiusCard = 24;

  /// Text field corner radius.
  static const double radiusInput = 16;

  /// Minimum tap target (dp) and recommended control height.
  static const double minTapTarget = 48;

  /// Body copy floor (sp). Do not clamp system text scaling.
  static const double bodySize = 16;

  /// Money copy floor (sp), bold.
  static const double moneySize = 28;

  /// Soft drop shadow: offset plus blur, not a zero-offset halo.
  static List<BoxShadow> get softShadows => [
        BoxShadow(
          color: ink.withValues(alpha: 0.10),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  /// Body text on cream or white.
  static const TextStyle body = TextStyle(
    fontSize: bodySize,
    height: 1.4,
    color: ink,
  );

  /// Whole-peso amounts. Pair with [formatPeso]; never a double.
  static const TextStyle money = TextStyle(
    fontSize: moneySize,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: ink,
  );
}

/// Light Material 3 theme wired to [SmartSaveTokens].
final ThemeData smartSaveTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: SmartSaveTokens.background,
  materialTapTargetSize: MaterialTapTargetSize.padded,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: SmartSaveTokens.primary,
    onPrimary: SmartSaveTokens.onAccent,
    primaryContainer: SmartSaveTokens.primarySoft,
    onPrimaryContainer: SmartSaveTokens.ink,
    secondary: SmartSaveTokens.accent,
    onSecondary: SmartSaveTokens.onAccent,
    secondaryContainer: SmartSaveTokens.accentSoft,
    onSecondaryContainer: SmartSaveTokens.ink,
    tertiary: SmartSaveTokens.info,
    onTertiary: SmartSaveTokens.onAccent,
    error: SmartSaveTokens.accent,
    onError: SmartSaveTokens.onAccent,
    surface: SmartSaveTokens.surface,
    onSurface: SmartSaveTokens.ink,
    onSurfaceVariant: SmartSaveTokens.inkSoft,
    outline: SmartSaveTokens.inkSoft,
    outlineVariant: SmartSaveTokens.primarySoft,
    inverseSurface: SmartSaveTokens.ink,
    onInverseSurface: SmartSaveTokens.background,
    inversePrimary: SmartSaveTokens.primary,
    surfaceContainerLowest: SmartSaveTokens.surface,
    surfaceContainerLow: SmartSaveTokens.background,
    surfaceContainer: SmartSaveTokens.background,
    surfaceContainerHigh: SmartSaveTokens.surface,
    surfaceContainerHighest: SmartSaveTokens.surface,
  ),
  textTheme: const TextTheme(
    bodyLarge: SmartSaveTokens.body,
    bodyMedium: SmartSaveTokens.body,
    bodySmall: SmartSaveTokens.body,
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: SmartSaveTokens.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SmartSaveTokens.ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: SmartSaveTokens.ink,
    ),
    headlineMedium: SmartSaveTokens.money,
    labelLarge: TextStyle(
      fontSize: SmartSaveTokens.bodySize,
      fontWeight: FontWeight.w600,
      color: SmartSaveTokens.ink,
    ),
  ),
  iconTheme: const IconThemeData(color: SmartSaveTokens.ink, size: 24),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: SmartSaveTokens.accent,
      foregroundColor: SmartSaveTokens.onAccent,
      minimumSize: const Size(
        SmartSaveTokens.minTapTarget,
        SmartSaveTokens.minTapTarget,
      ),
      textStyle: const TextStyle(
        fontSize: SmartSaveTokens.bodySize,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: SmartSaveTokens.primary,
      minimumSize: const Size(
        SmartSaveTokens.minTapTarget,
        SmartSaveTokens.minTapTarget,
      ),
      textStyle: const TextStyle(
        fontSize: SmartSaveTokens.bodySize,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: SmartSaveTokens.primary, width: 2),
      shape: const StadiumBorder(),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: SmartSaveTokens.accent,
      foregroundColor: SmartSaveTokens.onAccent,
      minimumSize: const Size(
        SmartSaveTokens.minTapTarget,
        SmartSaveTokens.minTapTarget,
      ),
      elevation: 0,
      shadowColor: SmartSaveTokens.ink.withValues(alpha: 0.12),
      textStyle: const TextStyle(
        fontSize: SmartSaveTokens.bodySize,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
  ),
  cardTheme: CardThemeData(
    color: SmartSaveTokens.surface,
    elevation: 0,
    shadowColor: SmartSaveTokens.ink.withValues(alpha: 0.10),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SmartSaveTokens.radiusCard),
    ),
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: SmartSaveTokens.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: SmartSaveTokens.body.copyWith(color: SmartSaveTokens.inkSoft),
    labelStyle: SmartSaveTokens.body,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
      borderSide: BorderSide(color: SmartSaveTokens.inkSoft.withValues(alpha: 0.35)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
      borderSide: BorderSide(color: SmartSaveTokens.inkSoft.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
      borderSide: const BorderSide(color: SmartSaveTokens.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SmartSaveTokens.radiusInput),
      borderSide: const BorderSide(color: SmartSaveTokens.accent, width: 1.5),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: SmartSaveTokens.surface,
    elevation: 0,
    height: 80,
    indicatorColor: SmartSaveTokens.primary.withValues(alpha: 0.16),
    indicatorShape: const StadiumBorder(),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 24,
        color: selected ? SmartSaveTokens.primary : SmartSaveTokens.inkSoft,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? SmartSaveTokens.primary : SmartSaveTokens.inkSoft,
      );
    }),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: SmartSaveTokens.primary,
  ),
);
