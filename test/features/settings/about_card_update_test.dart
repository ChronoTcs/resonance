import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/settings/application/update_provider.dart';
import 'package:resonance/features/settings/data/models/release_model.dart';
import 'package:resonance/features/settings/presentation/widgets/about_card.dart';

class _MockUpdateNotifier extends UpdateNotifier {
  final UpdateState initialState;
  bool fetchReleasesCalled = false;

  _MockUpdateNotifier(this.initialState);

  @override
  UpdateState build() {
    return initialState;
  }

  @override
  Future<void> fetchReleases({bool force = false}) async {
    fetchReleasesCalled = true;
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
      version: '0.1.7',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  final sampleRelease = AppRelease.fromJson({
    'tag_name': 'v0.1.8',
    'name': 'Resonance v0.1.8',
    'body': 'Changelog details',
    'prerelease': false,
    'published_at': '2026-09-12T12:00:00Z',
    'assets': [
      {
        'name': 'resonance-windows-setup.exe',
        'browser_download_url': 'https://github.com/test/resonance-windows-setup.exe',
        'size': 50000000,
      }
    ],
  }, '0.1.7');

  Widget createWidgetUnderTest({
    required UpdateState updateState,
    VoidCallback? onOpenUpdates,
    _MockUpdateNotifier? notifier,
  }) {
    final mockNotifier = notifier ?? _MockUpdateNotifier(updateState);
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateProvider.overrideWith(() => mockNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AboutCard(onOpenUpdates: onOpenUpdates),
          ),
        ),
      ),
    );
  }

  testWidgets('AboutCard renders version badge in header', (tester) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        updateState: UpdateState(currentVersion: '0.1.7'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resonance'), findsOneWidget);
    expect(find.textContaining('0.1.7'), findsAtLeastNWidgets(1));
  });

  testWidgets('Expanding AboutCard reveals update section and Check Now button', (tester) async {
    final notifier = _MockUpdateNotifier(UpdateState(currentVersion: '0.1.7'));
    await tester.pumpWidget(
      createWidgetUnderTest(
        updateState: UpdateState(currentVersion: '0.1.7'),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    // Expand AboutCard ExpansionTile
    await tester.tap(find.text('Resonance'));
    await tester.pumpAndSettle();

    expect(find.text('Software Updates'), findsOneWidget);
    expect(find.text('Check Now'), findsOneWidget);

    // Tap Check Now
    await tester.tap(find.text('Check Now'));
    await tester.pumpAndSettle();

    expect(notifier.fetchReleasesCalled, isTrue);
  });

  testWidgets('Shows Update Available badge & triggers onOpenUpdates', (tester) async {
    bool openedUpdates = false;
    final state = UpdateState(
      currentVersion: '0.1.7',
      releases: [sampleRelease],
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        updateState: state,
        onOpenUpdates: () => openedUpdates = true,
      ),
    );
    await tester.pumpAndSettle();

    // Verify header badge displays update available indicator
    expect(find.textContaining('Update'), findsAtLeastNWidgets(1));

    // Expand tile
    await tester.tap(find.text('Resonance'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Update available: v0.1.8'), findsOneWidget);
    expect(find.text('View Update'), findsOneWidget);

    // Tap View Update
    await tester.tap(find.text('View Update'));
    await tester.pumpAndSettle();

    expect(openedUpdates, isTrue);
  });

  testWidgets('Displays Checking state with progress indicator', (tester) async {
    final state = UpdateState(
      currentVersion: '0.1.7',
      isChecking: true,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(updateState: state),
    );
    await tester.pump();

    // Expand tile
    await tester.tap(find.text('Resonance'));
    await tester.pump();

    expect(find.text('Checking for updates...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
  });

  testWidgets('Displays Up to date status when installed is latest', (tester) async {
    final upToDateRelease = AppRelease.fromJson({
      'tag_name': 'v0.1.7',
      'name': 'Resonance v0.1.7',
      'body': 'Already on this version',
      'prerelease': false,
      'published_at': '2026-09-12T12:00:00Z',
      'assets': [],
    }, '0.1.7');

    final state = UpdateState(
      currentVersion: '0.1.7',
      releases: [upToDateRelease],
    );

    await tester.pumpWidget(
      createWidgetUnderTest(updateState: state),
    );
    await tester.pumpAndSettle();

    // Expand tile
    await tester.tap(find.text('Resonance'));
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version"), findsOneWidget);
    expect(find.text('Check Now'), findsOneWidget);
  });
}
