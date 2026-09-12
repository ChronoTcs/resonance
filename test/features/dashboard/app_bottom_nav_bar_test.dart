import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/dashboard/presentation/widgets/app_bottom_nav_bar.dart';

void main() {
  group('AppBottomNavBar Index Mapping Tests', () {
    test('Translates logical indices to physical indices correctly', () {
      // 0: Home -> physical 0
      expect(AppBottomNavBar.getPhysicalIndex(0), equals(0));
      // 1: Explore -> physical 1
      expect(AppBottomNavBar.getPhysicalIndex(1), equals(1));
      // 2: Library -> physical 2
      expect(AppBottomNavBar.getPhysicalIndex(2), equals(2));
      // 3: Playlists (redirects to Library on compact) -> physical 2
      expect(AppBottomNavBar.getPhysicalIndex(3), equals(2));
      // 4: Downloads (redirects to Library on compact) -> physical 2
      expect(AppBottomNavBar.getPhysicalIndex(4), equals(2));
      // 5: Settings -> physical 3
      expect(AppBottomNavBar.getPhysicalIndex(5), equals(3));
    });

    test('Translates physical taps to logical indices correctly', () {
      // Physical 0 (Home) -> logical 0 (Home)
      expect(AppBottomNavBar.getLogicalIndex(0), equals(0));
      // Physical 1 (Explore) -> logical 1 (Explore)
      expect(AppBottomNavBar.getLogicalIndex(1), equals(1));
      // Physical 2 (Library) -> logical 2 (Library)
      expect(AppBottomNavBar.getLogicalIndex(2), equals(2));
      // Physical 3 (Settings) -> logical 5 (Settings)
      expect(AppBottomNavBar.getLogicalIndex(3), equals(5));
    });

    test('Round-trip identity for primary tabs (Home, Explore, Library, Settings)', () {
      // For each primary physical tab, mapping to logical and back to physical yields identical index
      for (int physical = 0; physical <= 3; physical++) {
        final logical = AppBottomNavBar.getLogicalIndex(physical);
        final roundTrip = AppBottomNavBar.getPhysicalIndex(logical);
        expect(roundTrip, equals(physical),
            reason: 'Failed round-trip for physical index $physical (logical: $logical)');
      }
    });
  });
}
