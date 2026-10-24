import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemUiOverlayStyle Edge-to-Edge Integration Tests', () {
    testWidgets('AnnotatedRegion provides transparent system bars and disabled contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.light,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child!,
            );
          },
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      final regionFinder = find.byType(AnnotatedRegion<SystemUiOverlayStyle>);
      expect(regionFinder, findsOneWidget);

      final regionWidget = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(regionFinder);
      expect(regionWidget.value.statusBarColor, equals(Colors.transparent));
      expect(regionWidget.value.systemNavigationBarColor, equals(Colors.transparent));
      expect(regionWidget.value.systemNavigationBarDividerColor, equals(Colors.transparent));
      expect(regionWidget.value.systemNavigationBarContrastEnforced, isFalse);
      expect(regionWidget.value.statusBarIconBrightness, equals(Brightness.dark));
      expect(regionWidget.value.systemNavigationBarIconBrightness, equals(Brightness.dark));
    });

    testWidgets('AnnotatedRegion dynamically switches icon brightness in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child!,
            );
          },
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      final regionFinder = find.byType(AnnotatedRegion<SystemUiOverlayStyle>);
      final regionWidget = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(regionFinder);
      expect(regionWidget.value.statusBarIconBrightness, equals(Brightness.light));
      expect(regionWidget.value.systemNavigationBarIconBrightness, equals(Brightness.light));
    });
  });
}

