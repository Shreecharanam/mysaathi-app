import 'package:flutter/material.dart';

/// Central design tokens for MySaathi.
/// Palette: deep navy, ivory, charcoal, champagne-gold accents.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF12243A);
  static const navySoft = Color(0xFF1E3A5F);
  static const ivory = Color(0xFFF7F3EA);
  static const ivoryDeep = Color(0xFFEFE9DC);
  static const charcoal = Color(0xFF232323);
  static const gold = Color(0xFFC8A96A);
  static const goldSoft = Color(0xFFE4D2A8);
  static const success = Color(0xFF2E7D5B);
  static const danger = Color(0xFFB3261E);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE4DDCF);
  static const lineDark = Color(0xFF33312D);
  static const surfaceDark = Color(0xFF1B1B1B);
  static const bgDark = Color(0xFF101010);
  static const appBarDark = Color(0xFF0D1B2A);
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const pill = 999.0;
}

class AppTheme {
  AppTheme._();

  static ColorScheme _scheme(Brightness b) {
    final base = ColorScheme.fromSeed(seedColor: AppColors.navy, brightness: b);
    return base.copyWith(
      primary: AppColors.navy,
      secondary: AppColors.gold,
      error: AppColors.danger,
    );
  }

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = _scheme(b);
    final surface = dark ? AppColors.surfaceDark : Colors.white;
    final bg = dark ? AppColors.bgDark : AppColors.ivory;
    final line = dark ? AppColors.lineDark : AppColors.line;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.appBarDark : AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        labelStyle: TextStyle(color: dark ? Colors.white70 : AppColors.muted),
        hintStyle: TextStyle(color: dark ? Colors.white38 : AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? Colors.white : AppColors.navy,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: line),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? AppColors.goldSoft : AppColors.navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF242424) : Colors.white,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: dark ? AppColors.navySoft : AppColors.ivoryDeep,
        elevation: 2,
        height: 68,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dark ? Colors.white70 : AppColors.navy,
        textColor: dark ? Colors.white : AppColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
}

/// Theme-aware foreground tints, so text and the logo stay readable in
/// both light and dark mode.
class AppTint {
  AppTint._();

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Brand foreground (logo icon, app title).
  static Color brand(BuildContext c) =>
      _dark(c) ? AppColors.gold : AppColors.navy;

  /// Normal secondary text.
  static Color muted(BuildContext c) =>
      _dark(c) ? const Color(0xFFC2C8D2) : AppColors.muted;

  /// Faint helper / hint text.
  static Color faint(BuildContext c) =>
      _dark(c) ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280);

  /// Subtle labels (stat captions).
  static Color subtle(BuildContext c) =>
      _dark(c) ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280);

  /// Error / danger text.
  static Color danger(BuildContext c) =>
      _dark(c) ? const Color(0xFFEF9A9A) : AppColors.danger;
}
