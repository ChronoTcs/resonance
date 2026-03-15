import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends Notifier<ThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system; // Default until loaded
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);

    if (themeString == 'light') {
      state = ThemeMode.light;
    } else if (themeString == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();

    String themeString = 'system';
    if (mode == ThemeMode.light) themeString = 'light';
    if (mode == ThemeMode.dark) themeString = 'dark';

    await prefs.setString(_themeKey, themeString);
  }
}

final themeProvider = NotifierProvider<ThemeProvider, ThemeMode>(() {
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
