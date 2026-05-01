import 'package:flutter/material.dart';

class AppTheme {
  // ── Monochrome palette ─────────────────────────────────
  static const Color primary      = Color(0xFF000000); // black (light) / white (dark)
  static const Color primaryLight = Color(0xFFF0F0F0); // subtle bg tint

  // Keep these for compatibility — all mapped to black/white
  static const Color secondary    = Color(0xFF000000);
  static const Color danger       = Color(0xFF000000);
  static const Color warning      = Color(0xFF555555);

  // Light
  static const Color bgLight      = Color(0xFFFFFFFF);
  static const Color cardLight    = Color(0xFFFFFFFF);
  static const Color borderLight  = Color(0xFFD1D1D1);
  static const Color textLight    = Color(0xFF000000);
  static const Color subTextLight = Color(0xFF555555);

  // Dark
  static const Color bgDark       = Color(0xFF000000);
  static const Color cardDark     = Color(0xFF111111);
  static const Color borderDark   = Color(0xFF2A2A2A);
  static const Color textDark     = Color(0xFFFFFFFF);
  static const Color subTextDark  = Color(0xFFAAAAAA);

  // ── Light Theme ────────────────────────────────────────
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF000000),
      onSecondary: Color(0xFFFFFFFF),
      background: bgLight,
      surface: bgLight,
      onSurface: textLight,
    ),
    scaffoldBackgroundColor: bgLight,
    cardColor: cardLight,

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: textLight),
      bodyMedium:  TextStyle(color: textLight),
      bodySmall:   TextStyle(color: subTextLight),
      titleLarge:  TextStyle(color: textLight, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: textLight, fontWeight: FontWeight.w600),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: bgLight,
      foregroundColor: textLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: textLight),
      iconTheme: IconThemeData(color: textLight),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Color(0xFFFFFFFF),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFF000000),
        side: const BorderSide(color: Color(0xFF000000)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      labelStyle: const TextStyle(color: subTextLight),
    ),

    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderLight),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgLight,
      selectedItemColor: Color(0xFF000000),
      unselectedItemColor: Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF000000) : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFFCCCCCC) : const Color(0xFFE5E7EB)),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF000000),
    ),
  );

  // ── Dark Theme ─────────────────────────────────────────
  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFF000000),
      background: bgDark,
      surface: cardDark,
      onSurface: textDark,
    ),
    scaffoldBackgroundColor: bgDark,
    cardColor: cardDark,

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: textDark),
      bodyMedium:  TextStyle(color: textDark),
      bodySmall:   TextStyle(color: subTextDark),
      titleLarge:  TextStyle(color: textDark, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: textDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: textDark),
      iconTheme: IconThemeData(color: textDark),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF000000),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFFFFFFFF),
        side: const BorderSide(color: Color(0xFFFFFFFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      labelStyle: const TextStyle(color: subTextDark),
    ),

    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderDark),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgDark,
      selectedItemColor: Color(0xFFFFFFFF),
      unselectedItemColor: Color(0xFF555555),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFFFFFFFF) : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF555555) : const Color(0xFF2A2A2A)),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFFFFFFFF),
    ),
  );
}
