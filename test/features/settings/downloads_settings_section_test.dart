import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/download/application/providers/download_settings_provider.dart';
import 'package:resonance/features/settings/presentation/widgets/downloads_settings_section.dart';

class _MockDownloadSettingsNotifier extends DownloadSettingsNotifier {
  @override
  Future<DownloadSettings> build() async {
    return const DownloadSettings(
      maxConcurrent: 3,
      maxRetries: 4,
      connectionTimeout: 45,
      fragmentsPerDownload: 6,
    );
  }
}

void main() {
  testWidgets('DownloadsSettingsSection renders without obsolete stream engine selector', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadSettingsProvider.overrideWith(_MockDownloadSettingsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DownloadsSettingsSection(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 'Advance Limits Downloads' header is present
    expect(find.text('Advance Limits Downloads'), findsOneWidget);

    // Verify obsolete engine controls are completely absent
    expect(find.text('Default Source'), findsNothing);
    expect(find.text('Select default streaming engine'), findsNothing);
    expect(find.text('Native IPC First (yt-dlp)'), findsNothing);
    expect(find.text('In-App Dart First (youtube_explode)'), findsNothing);

    // Verify download limit controls render with mocked values
    expect(find.text('Max Concurrent Downloads'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Max Retry Limit'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Connection Timeout (seconds)'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('Segments per Download'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
}

