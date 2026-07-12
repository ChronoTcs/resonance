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

class LyricsActiveOpacityProvider extends Notifier<double> {
  static const String _key = 'lyrics_active_opacity';

  @override
  double build() {
    _load();
    return 1.0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 1.0;
  }

  Future<void> setOpacity(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
  }
}

final lyricsActiveOpacityProvider = NotifierProvider<LyricsActiveOpacityProvider, double>(() {
  return LyricsActiveOpacityProvider();
});

class LyricsInactiveOpacityProvider extends Notifier<double> {
  static const String _key = 'lyrics_inactive_opacity';

  @override
  double build() {
    _load();
    return 0.38;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 0.38;
  }

  Future<void> setOpacity(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
  }
}

final lyricsInactiveOpacityProvider = NotifierProvider<LyricsInactiveOpacityProvider, double>(() {
  return LyricsInactiveOpacityProvider();
});
