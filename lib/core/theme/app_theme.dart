import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_theme/system_theme.dart';

class AppTheme {
  // Palette 7 (Modern Glass - Light Mode Default) & Palette 8 (Deep Opulence - Dark Mode Default)
  static const Color creamBackground = Color(0xFFFFFFFF); // White background
  static const Color creamSurface = Color(0xFFF7F3E3); // Gilded Ivory surface / cards
  static const Color textDark = Color(0xFF2E2A27); // Obsidian Brown

  static const Color darkBackground = Color(0xFF232D35); // Dark Slate Gold Glass
  static const Color darkSurface = Color(0xFF2D3A45); // Slate Grey Glass
  static const Color textLight = Color(0xFFF7F3E3); // Gilded Ivory

  static const Color accentGrey = Color(0xFF404041); // Obsidian Grey (Secondary Light text)
  static const Color accentSoft = Color(0xFF707070); // Gilded Grey (Secondary Dark text)

  static Color? _resolveAccent(String? mode, Brightness brightness) {
    if (mode == null) {
      // Default fallback: Auroral Glow for Light Mode, Copper-Amber for Dark Mode
      return brightness == Brightness.light
          ? const Color(0xFFE9AD71)
          : const Color(0xFFAE8C50);
    }
    if (mode == 'windows') {
      return SystemTheme.accentColor.accent;
    }
    
    // Adaptive Palette Colors (balancing brightness vs contrast)
    final bool isLight = brightness == Brightness.light;
    switch (mode) {
      case 'palette1': // Muted Sand
        return isLight ? const Color(0xFFA89689) : const Color(0xFFDBCDC2);
      case 'palette2': // Cream Alabaster
        return isLight ? const Color(0xFFDDD4C5) : const Color(0xFFFCFAF5);
      case 'palette3': // Sage & Slate Mint
        return isLight ? const Color(0xFFA3B5AE) : const Color(0xFFE4ECE8);
      case 'palette4': // Glacier Steel
        return isLight ? const Color(0xFFA5B6BD) : const Color(0xFFE2EBEE);
      case 'palette5': // Nordic Blue
        return isLight ? const Color(0xFF8A9EA9) : const Color(0xFFCBD8DF);
      case 'palette6': // Deep Dusk Blue
        return isLight ? const Color(0xFF738995) : const Color(0xFFB7C9D1);
      case 'palette7': // Auroral Glow
        return isLight ? const Color(0xFFE9AD71) : const Color(0xFFFFCEAA);
      case 'palette8': // Copper-Amber
        return isLight ? const Color(0xFFBB6B4C) : const Color(0xFFAE8C50);
      default:
        if (mode.startsWith('0x')) {
          return Color(int.parse(mode));
        }
        return null;
    }
  }

  static ThemeData getLightTheme(String? accentMode) {
    final accentColor = _resolveAccent(accentMode, Brightness.light) ?? const Color(0xFFE9AD71);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );
    final primary = baseScheme.primary;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary, // Black/Dark grey or custom primary
      scaffoldBackgroundColor: creamBackground,
      colorScheme: baseScheme.copyWith(
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

  static ThemeData getDarkTheme(String? accentMode, {bool isOnyx = false}) {
    final defaultAccent = isOnyx ? const Color(0xFFE2B35B) : const Color(0xFFAE8C50);
    final accentColor = _resolveAccent(accentMode, Brightness.dark) ?? defaultAccent;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    );
    final primary = baseScheme.primary;
    final bg = isOnyx ? const Color(0xFF090C0E) : darkBackground;
    final surf = isOnyx ? const Color(0xFF12161A) : darkSurface;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary, // Cream or custom primary in dark mode
      scaffoldBackgroundColor: bg,
      colorScheme: baseScheme.copyWith(
        primary: primary,
        secondary: accentSoft,
        surface: surf,
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: creamBackground,
        unselectedItemColor: accentGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surf,
        selectedIconTheme: const IconThemeData(color: creamBackground),
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
