import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/theme/theme_provider.dart';
import 'package:resonance/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Consolidation Tests', () {
    test('AppThemeMode strictly has exactly 3 modes: system, light, dark', () {
      expect(AppThemeMode.values.length, equals(3));
      expect(AppThemeMode.values, contains(AppThemeMode.system));
      expect(AppThemeMode.values, contains(AppThemeMode.light));
      expect(AppThemeMode.values, contains(AppThemeMode.dark));
    });

    test('Dark theme tokens match unified modern palette specifications', () {
      expect(AppTheme.darkBackground, equals(const Color(0xFF0C0E12)));
      expect(AppTheme.darkSurface, equals(const Color(0xFF15181E)));
      expect(AppTheme.textLight, equals(const Color(0xFFF1F5F9)));
    });

    test('Light theme tokens match clean cream palette specifications', () {
      expect(AppTheme.creamBackground, equals(const Color(0xFFDFE2EC)));
      expect(AppTheme.creamSurface, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.textDark, equals(const Color(0xFF0F172A)));
    });

    test('Scrollbar theme enforces consistent 4.0dp thickness without ballooning on hover', () {
      for (final theme in [AppTheme.getLightTheme(null), AppTheme.getDarkTheme(null)]) {
        final scrollbar = theme.scrollbarTheme;
        expect(scrollbar.thickness?.resolve({}), equals(4.0));
        expect(scrollbar.thickness?.resolve({WidgetState.hovered}), equals(4.0));
        expect(scrollbar.thickness?.resolve({WidgetState.dragged}), equals(4.0));
        expect(scrollbar.radius, equals(const Radius.circular(8)));

        final idleColor = scrollbar.thumbColor?.resolve({});
        final hoveredColor = scrollbar.thumbColor?.resolve({WidgetState.hovered});
        final draggedColor = scrollbar.thumbColor?.resolve({WidgetState.dragged});

        expect(idleColor, isNotNull);
        expect(hoveredColor, isNotNull);
        expect(draggedColor, isNotNull);
        expect((idleColor!.a * 100).round(), equals(25));
        expect((hoveredColor!.a * 100).round(), equals(60));
        expect((draggedColor!.a * 100).round(), equals(60));
      }
    });
  });
}
