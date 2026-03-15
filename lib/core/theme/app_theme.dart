import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_theme/system_theme.dart';

class AppTheme {
  // Monochrome & Cream Palette
  static const Color creamBackground = Color(0xFFF4EFE6);
  static const Color creamSurface = Color(0xFFE8E2D2);

  static const Color darkBackground = Color(0xFF191919);
  static const Color darkSurface = Color(0xFF242424);

  static const Color textDark = Color(0xFF1C1C1C);
  static const Color textLight = Color(0xFFF4EFE6);

  static const Color accentGrey = Color(0xFF6B6B6B);
  static const Color accentSoft = Color(0xFFB5B5B5);

  static Color? _resolveAccent(String? mode, Brightness brightness) {
    if (mode == null) return null;
    if (mode == 'windows') {
      return SystemTheme.accentColor.accent;
    }
    if (mode == 'cream') {
      // Soft Cream (Old Lace/Krem)
      // In light mode (cream background), we need a dark contrast (dark brownish cream)
      // In dark mode, we use the soft light cream
      return brightness == Brightness.light
          ? const Color(0xFF5D574B) // Dark Warm Grey/Brown
          : const Color(0xFFFDF5E6); // Soft Cream
    }
    if (mode.startsWith('0x')) {
      return Color(int.parse(mode));
    }
    return null;
  }

  static ThemeData getLightTheme(String? accentMode) {
    final accentColor = _resolveAccent(accentMode, Brightness.light);
    final primary = accentColor ?? textDark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary, // Black/Dark grey or custom primary
      scaffoldBackgroundColor: creamBackground,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accentGrey,
        surface: creamSurface,
        background: creamBackground,
        onBackground: textDark,
        onSurface: textDark,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: textDark, displayColor: textDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: creamBackground,
        selectedItemColor: textDark,
        unselectedItemColor: accentGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: creamSurface,
        selectedIconTheme: IconThemeData(color: textDark),
        unselectedIconTheme: IconThemeData(color: accentGrey),
        selectedLabelTextStyle: TextStyle(color: textDark),
        unselectedLabelTextStyle: TextStyle(color: accentGrey),
      ),
      iconTheme: const IconThemeData(color: textDark),
      sliderTheme: const SliderThemeData(
        activeTrackColor: textDark,
        inactiveTrackColor: accentSoft,
        thumbColor: textDark,
      ),
      listTileTheme: const ListTileThemeData(iconColor: textDark),
    );
  }

  static ThemeData getDarkTheme(String? accentMode) {
    final accentColor = _resolveAccent(accentMode, Brightness.dark);
    final primary = accentColor ?? creamBackground;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary, // Cream or custom primary in dark mode
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accentSoft,
        surface: darkSurface,
        background: darkBackground,
        onBackground: textLight,
        onSurface: textLight,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: textLight, displayColor: textLight),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: creamBackground,
        unselectedItemColor: accentGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkSurface,
        selectedIconTheme: IconThemeData(color: creamBackground),
        unselectedIconTheme: IconThemeData(color: accentGrey),
        selectedLabelTextStyle: TextStyle(color: creamBackground),
        unselectedLabelTextStyle: TextStyle(color: accentGrey),
      ),
      iconTheme: const IconThemeData(color: textLight),
      sliderTheme: const SliderThemeData(
        activeTrackColor: creamBackground,
        inactiveTrackColor: accentGrey,
        thumbColor: creamBackground,
      ),
      listTileTheme: const ListTileThemeData(iconColor: textLight),
    );
  }
}
