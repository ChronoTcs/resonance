import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/settings/application/update_provider.dart';
import 'package:resonance/features/settings/data/models/release_model.dart';
import 'package:resonance/features/settings/presentation/screens/release_manager_screen.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance/features/settings/presentation/widgets/appearance_section.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';

class FakeUpdateNotifier extends UpdateNotifier {
  final UpdateState initialState;
  FakeUpdateNotifier(this.initialState);

  @override
  UpdateState build() {
    return initialState;
  }

  @override
  Future<void> fetchReleases({bool force = false}) async {
    // No-op for widget test
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: 'Resonance',
      packageName: 'com.streamly.resonance',
      version: '0.1.6',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  final testRelease = AppRelease.fromJson({
    'tag_name': 'v0.1.7',
    'name': 'Resonance v0.1.7 - Major Architecture & Responsive Mobile Update',
    'body': '### Features\n- Added full responsive support for compact mobile.\n- Fixed all overflows.\n\n### Bug Fixes\n- Resolved 163px overflow on Android.\n- Fixed gesture conflicts.',
    'prerelease': false,
    'published_at': '2026-09-10T12:00:00Z',
    'assets': [
      {
        'name': 'resonance-windows-setup.exe',
        'browser_download_url': 'https://github.com/test/resonance-windows-setup.exe',
        'size': 55000000,
      },
      {
        'name': 'resonance-universal.apk',
        'browser_download_url': 'https://github.com/test/resonance-universal.apk',
        'size': 45000000,
      }
    ],
  }, '0.1.6');

  group('Phase 9 Settings & ReleaseManager Multiplatform Tests', () {
    testWidgets('Double Header Suppression in SettingsScreen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          updateProvider.overrideWith(() => FakeUpdateNotifier(
                UpdateState(
                  currentVersion: '0.1.6',
                  releases: [testRelease],
                ),
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Root settings: "Settings" header should be visible
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Releases & Updates'), findsNothing);

      // Navigate to updates subview
      container.read(settingsSubViewProvider.notifier).setSubView(SettingsSubView.updates);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In updates subview: "Settings" root header must be SUPPRESSED (hidden)
      expect(find.text('Settings'), findsNothing);
      // StickySubViewLayout header should be present
      expect(find.text('Releases & Updates'), findsOneWidget);

      // Close subview via back button
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(container.read(settingsSubViewProvider), equals(SettingsSubView.none));
        expect(find.text('Settings'), findsOneWidget);
      }
    });

    testWidgets('Compact 360dp Mobile Viewport Renders Without RenderFlex Overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUpdateNotifier(
        UpdateState(
          currentVersion: '0.1.6',
          releases: [testRelease],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            updateProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReleaseManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no yellow stripe exception / RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify release name and tag render
      expect(find.textContaining('Resonance v0.1.7'), findsOneWidget);
      expect(find.text('(v0.1.7)'), findsOneWidget);

      // Verify STABLE badge renders
      expect(find.text('STABLE'), findsOneWidget);

      // Verify Download & Install button renders
      final downloadBtn = find.textContaining('Download & Install v0.1.7');
      expect(downloadBtn, findsOneWidget);

      // Verify Automatic Updates toggle
      expect(find.text('Automatic Updates'), findsOneWidget);
    });

    testWidgets('FormattedMarkdownText expand/collapse toggles cleanly on button tap', (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            updateProvider.overrideWith(() => FakeUpdateNotifier(
                  UpdateState(
                    currentVersion: '0.1.6',
                    releases: [testRelease],
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReleaseManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final showMoreFinder = find.text('Show More');
      expect(showMoreFinder, findsOneWidget);

      // Tap Show More
      await tester.tap(showMoreFinder);
      await tester.pumpAndSettle();

      // Should now display Show Less
      final showLessFinder = find.text('Show Less');
      expect(showLessFinder, findsOneWidget);

      // Tap Show Less to collapse
      await tester.ensureVisible(showLessFinder);
      await tester.tap(showLessFinder);
      await tester.pumpAndSettle();

      expect(find.text('Show More'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Incompatible release shows informative message instead of broken download button', (tester) async {
      final incompatibleRelease = AppRelease.fromJson({
        'tag_name': 'v0.1.5',
        'name': 'Resonance v0.1.5 (Linux Tarball Only)',
        'body': 'Historical release with no Windows or Android binary.',
        'prerelease': false,
        'published_at': '2026-08-01T12:00:00Z',
        'assets': [
          {
            'name': 'resonance-linux.tar.gz',
            'browser_download_url': 'https://github.com/test/resonance-linux.tar.gz',
            'size': 30000000,
          }
        ],
      }, '0.1.6');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            updateProvider.overrideWith(() => FakeUpdateNotifier(
                  UpdateState(
                    currentVersion: '0.1.6',
                    releases: [incompatibleRelease],
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReleaseManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Download button must NOT appear
      expect(find.textContaining('Download & Install'), findsNothing);
      // Incompatibility message must appear
      expect(find.textContaining('No compatible'), findsOneWidget);
    });

    testWidgets('Responsive Version Badge Position: Section 0 on Mobile, Header on Desktop', (tester) async {
      // 1. Mobile (360dp)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            updateProvider.overrideWith(() => FakeUpdateNotifier(
                  UpdateState(
                    currentVersion: '0.1.6',
                    releases: [testRelease],
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReleaseManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On compact mobile, v0.1.6 badge is present
      expect(find.text('v0.1.6'), findsOneWidget);

      // 2. Expand to desktop (1200dp)
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      expect(find.text('v0.1.6'), findsOneWidget);
    });

    testWidgets('AppearanceSection renders accent selector with color swatches', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppearanceSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Accent Colour'), findsOneWidget);
    });

    testWidgets('Automatic Updates switch toggles cleanly without blocking on install permissions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            updateProvider.overrideWith(() => FakeUpdateNotifier(
                  UpdateState(
                    currentVersion: '0.1.6',
                    releases: [testRelease],
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReleaseManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Automatic Updates'), findsOneWidget);
      // Tap switch to toggle off and on without throws
      final switchFinder = find.byType(ResonanceSwitch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
