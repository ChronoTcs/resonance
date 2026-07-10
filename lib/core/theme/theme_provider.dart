import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light, // Modern Glass
  dark,  // Deep Opulence
  onyx,  // Onyx (Pure Dark)
}

class ThemeProvider extends Notifier<AppThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  @override
  AppThemeMode build() {
    _loadTheme();
    return AppThemeMode.system; // Default until loaded
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);

    if (themeString == 'light') {
      state = AppThemeMode.light;
    } else if (themeString == 'dark') {
      state = AppThemeMode.dark;
    } else if (themeString == 'onyx') {
      state = AppThemeMode.onyx;
    } else {
      state = AppThemeMode.system;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();

    String themeString = 'system';
    if (mode == AppThemeMode.light) themeString = 'light';
    if (mode == AppThemeMode.dark) themeString = 'dark';
    if (mode == AppThemeMode.onyx) themeString = 'onyx';

    await prefs.setString(_themeKey, themeString);
  }
}

final themeProvider = NotifierProvider<ThemeProvider, AppThemeMode>(() {
  return ThemeProvider();
});

class AccentColorProvider extends Notifier<String?> {
  static const String _accentKey = 'app_accent_mode';

  @override
  String? build() {
    _loadAccentColor();
    return null; // null means System Default (App's default)
  }

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_accentKey);
  }

  Future<void> setAccentColor(String? mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_accentKey);
    } else {
      await prefs.setString(_accentKey, mode);
    }
  }
}

final accentColorProvider = NotifierProvider<AccentColorProvider, String?>(() {
  return AccentColorProvider();
});
