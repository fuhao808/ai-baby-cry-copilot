import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeSettings {
  const ThemeSettings({required this.palette});

  final AppPalette palette;

  ThemeSettings copyWith({AppPalette? palette}) {
    return ThemeSettings(palette: palette ?? this.palette);
  }
}

class ThemeSettingsController extends StateNotifier<ThemeSettings> {
  ThemeSettingsController() : super(const ThemeSettings(palette: AppPalette.cloud)) {
    _load();
  }

  static const _paletteKey = 'theme_palette';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paletteKey);
    if (raw == null) {
      return;
    }

    final palette = AppPalette.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AppPalette.cloud,
    );
    state = state.copyWith(palette: palette);
  }

  Future<void> setPalette(AppPalette palette) async {
    state = state.copyWith(palette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsController, ThemeSettings>(
  (ref) => ThemeSettingsController(),
);
