import 'package:flutter/material.dart';

enum AppPalette {
  cloud('Cloud', 'White + Blue'),
  butter('Butter', 'White + Yellow'),
  lavender('Lavender', 'White + Purple'),
  sage('Sage', 'White + Green');

  const AppPalette(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

class AppPaletteSpec {
  const AppPaletteSpec({
    required this.seed,
    required this.accent,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightGradient,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkGradient,
  });

  final Color seed;
  final Color accent;
  final Color lightBackground;
  final Color lightSurface;
  final List<Color> lightGradient;
  final Color darkBackground;
  final Color darkSurface;
  final List<Color> darkGradient;
}

final Map<AppPalette, AppPaletteSpec> appPaletteSpecs = {
  AppPalette.cloud: const AppPaletteSpec(
    seed: Color(0xFF7CC6FF),
    accent: Color(0xFF2F80ED),
    lightBackground: Color(0xFFF7FBFF),
    lightSurface: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFFF9FCFF), Color(0xFFEAF5FF), Color(0xFFD9EEFF)],
    darkBackground: Color(0xFF0E1724),
    darkSurface: Color(0xFF182434),
    darkGradient: [Color(0xFF0A1420), Color(0xFF122033), Color(0xFF18304A)],
  ),
  AppPalette.butter: const AppPaletteSpec(
    seed: Color(0xFFFFD66B),
    accent: Color(0xFFF4B400),
    lightBackground: Color(0xFFFFFDF7),
    lightSurface: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFFFFFEFB), Color(0xFFFFF5D9), Color(0xFFFFEDBE)],
    darkBackground: Color(0xFF19140C),
    darkSurface: Color(0xFF241D14),
    darkGradient: [Color(0xFF110D07), Color(0xFF1C150C), Color(0xFF2B2113)],
  ),
  AppPalette.lavender: const AppPaletteSpec(
    seed: Color(0xFFCBB6FF),
    accent: Color(0xFF8B6FE8),
    lightBackground: Color(0xFFFCFAFF),
    lightSurface: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFFFFFDFF), Color(0xFFF1EBFF), Color(0xFFE5DAFF)],
    darkBackground: Color(0xFF15111F),
    darkSurface: Color(0xFF211A31),
    darkGradient: [Color(0xFF0F0C17), Color(0xFF181326), Color(0xFF251C3A)],
  ),
  AppPalette.sage: const AppPaletteSpec(
    seed: Color(0xFF9ED8B4),
    accent: Color(0xFF3E8E6A),
    lightBackground: Color(0xFFF8FCF9),
    lightSurface: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFFFCFFFC), Color(0xFFE7F5EC), Color(0xFFD7EEDD)],
    darkBackground: Color(0xFF0F1712),
    darkSurface: Color(0xFF17241B),
    darkGradient: [Color(0xFF0B110D), Color(0xFF122019), Color(0xFF1B2D22)],
  ),
};

AppPaletteSpec paletteSpecFor(AppPalette palette) => appPaletteSpecs[palette]!;

ThemeData buildAppTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final spec = paletteSpecFor(palette);
  final isLight = brightness == Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: spec.seed,
    brightness: brightness,
  ).copyWith(
    primary: spec.accent,
    secondary: spec.seed,
    surface: isLight ? spec.lightSurface : spec.darkSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isLight ? spec.lightBackground : spec.darkBackground,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: isLight ? 0.5 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isLight ? const Color(0xFF1E293B) : spec.darkSurface,
    ),
  );
}
