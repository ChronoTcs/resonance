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
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.hovered) ? 8.0 : 4.0),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
          primary.withValues(alpha: states.contains(WidgetState.hovered) ? 0.5 : 0.2)),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        minThumbLength: 48,
        interactive: true,
      ),
      listTileTheme: const ListTileThemeData(iconColor: textDark),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 700),
        showDuration: const Duration(seconds: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(8),
      ),
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
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.hovered) ? 8.0 : 4.0),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
          primary.withValues(alpha: states.contains(WidgetState.hovered) ? 0.5 : 0.2)),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        minThumbLength: 48,
        interactive: true,
      ),
      listTileTheme: const ListTileThemeData(iconColor: textLight),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF000000).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 700),
        showDuration: const Duration(seconds: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
