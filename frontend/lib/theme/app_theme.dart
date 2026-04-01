import 'package:flutter/material.dart';

enum AppPalette {
  apricot('Apricot', 'Cream + Orange'),
  cloud('Cloud', 'Cream + Blue'),
  lavender('Lavender', 'Cream + Purple'),
  butter('Butter', 'Cream + Yellow'),
  sage('Sage', 'Cream + Green');

  const AppPalette(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

class AppPaletteSpec {
  const AppPaletteSpec({
    required this.seed,
    required this.primary,
    required this.primaryContainer,
  });

  final Color seed;
  final Color primary;
  final Color primaryContainer;

  Color get accent => primary;
  Color get lightBackground => _creamBackground;
  List<Color> get lightGradient => [
        _creamBackground,
        primaryContainer.withValues(alpha: 0.9),
      ];
  List<Color> get darkGradient => [
        _darkBackground,
        primary.withValues(alpha: 0.22),
      ];
}

const _creamBackground = Color(0xFFFDFCFB);
const _inkText = Color(0xFF1E293B);
const _darkBackground = Color(0xFF0A0A0A);
const _darkSurface = Color(0xFF1A1A1A);

final Map<AppPalette, AppPaletteSpec> appPaletteSpecs = {
  AppPalette.apricot: const AppPaletteSpec(
    seed: Color(0xFFF97316),
    primary: Color(0xFFF97316),
    primaryContainer: Color(0xFFFFE3D2),
  ),
  AppPalette.cloud: const AppPaletteSpec(
    seed: Color(0xFF60A5FA),
    primary: Color(0xFF3B82F6),
    primaryContainer: Color(0xFFDBEAFE),
  ),
  AppPalette.lavender: const AppPaletteSpec(
    seed: Color(0xFFA78BFA),
    primary: Color(0xFF8B5CF6),
    primaryContainer: Color(0xFFEDE9FE),
  ),
  AppPalette.butter: const AppPaletteSpec(
    seed: Color(0xFFFBBF24),
    primary: Color(0xFFF59E0B),
    primaryContainer: Color(0xFFFEF3C7),
  ),
  AppPalette.sage: const AppPaletteSpec(
    seed: Color(0xFF4ADE80),
    primary: Color(0xFF22C55E),
    primaryContainer: Color(0xFFDCFCE7),
  ),
};

AppPaletteSpec paletteSpecFor(AppPalette palette) => appPaletteSpecs[palette]!;

ThemeData buildAppTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final spec = paletteSpecFor(palette);
  final isLight = brightness == Brightness.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: spec.seed,
    brightness: brightness,
  );
  final colorScheme = baseScheme.copyWith(
    primary: spec.primary,
    secondary: spec.primary.withValues(alpha: isLight ? 0.18 : 0.28),
    surface: isLight ? Colors.white.withValues(alpha: 0.7) : _darkSurface,
    surfaceContainerHighest:
        isLight ? const Color(0xFFF3EEE8) : const Color(0xFF262626),
    primaryContainer: isLight
        ? spec.primaryContainer
        : spec.primary.withValues(alpha: 0.18),
    onPrimary: Colors.white,
    onSurface: isLight ? _inkText : Colors.white,
    onSurfaceVariant:
        isLight ? const Color(0xFF64748B) : const Color(0xFFB0B0B0),
    outlineVariant:
        isLight ? Colors.white.withValues(alpha: 0.8) : Colors.white12,
  );

  final textTheme = Typography.blackMountainView.copyWith(
    headlineLarge: Typography.blackMountainView.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: colorScheme.onSurface,
    ),
    headlineMedium: Typography.blackMountainView.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: colorScheme.onSurface,
    ),
    headlineSmall: Typography.blackMountainView.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: colorScheme.onSurface,
    ),
    titleLarge: Typography.blackMountainView.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: colorScheme.onSurface,
    ),
    titleMedium: Typography.blackMountainView.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    bodyLarge: Typography.blackMountainView.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
    ),
    bodyMedium: Typography.blackMountainView.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isLight ? _creamBackground : _darkBackground,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: isLight
          ? Colors.white.withValues(alpha: 0.72)
          : const Color(0xFF1A1A1A).withValues(alpha: 0.88),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(
          color: isLight ? const Color(0xFFD6D3D1) : Colors.white12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isLight
          ? colorScheme.primaryContainer
          : colorScheme.primary.withValues(alpha: 0.16),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: isLight ? colorScheme.primary : Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 86,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      backgroundColor: isLight
          ? Colors.white.withValues(alpha: 0.78)
          : const Color(0xFF121212).withValues(alpha: 0.92),
      indicatorColor: colorScheme.primary.withValues(alpha: isLight ? 0.16 : 0.28),
    ),
    dividerColor: isLight ? const Color(0xFFE7E5E4) : Colors.white10,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isLight ? _inkText : const Color(0xFF242424),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
