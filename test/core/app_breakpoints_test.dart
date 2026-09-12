import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';

void main() {
  group('AppBreakpoints Window Size Classes Tests', () {
    test('Material 3 breakpoint constants match specifications', () {
      expect(AppBreakpoints.compact, equals(600.0));
      expect(AppBreakpoints.medium, equals(840.0));
      expect(AppBreakpoints.expanded, equals(1200.0));
    });

    test('isCompactWidth identifies compact mobile viewports', () {
      expect(AppBreakpoints.isCompactWidth(360.0), isTrue);
      expect(AppBreakpoints.isCompactWidth(599.9), isTrue);
      expect(AppBreakpoints.isCompactWidth(600.0), isFalse);
      expect(AppBreakpoints.isCompactWidth(800.0), isFalse);
    });

    test('isMediumWidth identifies tablet and snapped window viewports', () {
      expect(AppBreakpoints.isMediumWidth(599.0), isFalse);
      expect(AppBreakpoints.isMediumWidth(600.0), isTrue);
      expect(AppBreakpoints.isMediumWidth(768.0), isTrue);
      expect(AppBreakpoints.isMediumWidth(839.9), isTrue);
      expect(AppBreakpoints.isMediumWidth(840.0), isFalse);
    });

    test('isWideWidth identifies tablet and desktop viewports', () {
      expect(AppBreakpoints.isWideWidth(599.0), isFalse);
      expect(AppBreakpoints.isWideWidth(600.0), isTrue);
      expect(AppBreakpoints.isWideWidth(1280.0), isTrue);
    });

    test('isExpandedWidth identifies full desktop monitors', () {
      expect(AppBreakpoints.isExpandedWidth(839.0), isFalse);
      expect(AppBreakpoints.isExpandedWidth(840.0), isTrue);
      expect(AppBreakpoints.isExpandedWidth(1920.0), isTrue);
    });
  });
}
