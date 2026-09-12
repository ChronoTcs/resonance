import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/download/application/utils/download_input_detector.dart';
import 'package:resonance/features/download/data/models/download_item.dart';

void main() {
  group('DownloadInputDetector', () {
    test('detects empty input', () {
      final analysis = DownloadInputDetector.analyze('');
      expect(analysis.primaryType, DownloadInputType.empty);
      expect(analysis.isValid, false);
      expect(analysis.totalCount, 0);
    });

    test('detects YouTube Music track URL', () {
      final analysis = DownloadInputDetector.analyze(
        'https://music.youtube.com/watch?v=2zPGWGqdfJ8&feature=shared',
      );
      expect(analysis.primaryType, DownloadInputType.youtubeMusic);
      expect(analysis.resolvedSource, DownloadSource.ytmusic);
      expect(analysis.isValid, true);
      expect(analysis.hasUnsupportedUrl, false);
      expect(analysis.items.first.videoId, '2zPGWGqdfJ8');
    });

    test('detects standard YouTube video URL (watch?v=)', () {
      final analysis = DownloadInputDetector.analyze(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(analysis.primaryType, DownloadInputType.youtubeVideo);
      expect(analysis.resolvedSource, DownloadSource.youtube);
      expect(analysis.isValid, true);
      expect(analysis.items.first.videoId, 'dQw4w9WgXcQ');
    });

    test('detects youtu.be short URL', () {
      final analysis = DownloadInputDetector.analyze(
        'https://youtu.be/dQw4w9WgXcQ',
      );
      expect(analysis.primaryType, DownloadInputType.youtubeVideo);
      expect(analysis.resolvedSource, DownloadSource.youtube);
      expect(analysis.isValid, true);
      expect(analysis.items.first.videoId, 'dQw4w9WgXcQ');
    });

    test('detects pure YouTube playlist URL', () {
      final analysis = DownloadInputDetector.analyze(
        'https://www.youtube.com/playlist?list=PL1234567890abcdef',
      );
      expect(analysis.primaryType, DownloadInputType.youtubePlaylist);
      expect(analysis.hasPlaylist, true);
      expect(analysis.isValid, true);
      expect(analysis.warningMessage, contains('Playlist link detected'));
      expect(analysis.items.first.playlistId, 'PL1234567890abcdef');
    });

    test('detects plain text song search query', () {
      final analysis = DownloadInputDetector.analyze('Queen - Bohemian Rhapsody');
      expect(analysis.primaryType, DownloadInputType.songSearch);
      expect(analysis.resolvedSource, DownloadSource.auto);
      expect(analysis.isValid, true);
      expect(analysis.hasUnsupportedUrl, false);
    });

    test('detects unsupported URL (e.g. Spotify)', () {
      final analysis = DownloadInputDetector.analyze(
        'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
      );
      expect(analysis.primaryType, DownloadInputType.unsupportedUrl);
      expect(analysis.hasUnsupportedUrl, true);
      expect(analysis.isValid, false);
      expect(analysis.invalidCount, 1);
      expect(analysis.warningMessage, contains('open.spotify.com'));
    });

    test('analyzes multi-line batch inputs with mixed valid and invalid lines', () {
      const batchInput = '''
https://music.youtube.com/watch?v=2zPGWGqdfJ8
Queen - Don't Stop Me Now
https://open.spotify.com/track/12345
''';
      final analysis = DownloadInputDetector.analyze(batchInput);
      expect(analysis.totalCount, 3);
      expect(analysis.validCount, 2);
      expect(analysis.invalidCount, 1);
      expect(analysis.hasUnsupportedUrl, true);
      expect(analysis.isValid, false); // Blocked because of 1 invalid URL
    });

    test('analyzes multi-line batch inputs with all valid lines', () {
      const batchInput = '''
https://music.youtube.com/watch?v=2zPGWGqdfJ8
https://youtu.be/dQw4w9WgXcQ
Pink Floyd - Time
''';
      final analysis = DownloadInputDetector.analyze(batchInput);
      expect(analysis.totalCount, 3);
      expect(analysis.validCount, 3);
      expect(analysis.invalidCount, 0);
      expect(analysis.hasUnsupportedUrl, false);
      expect(analysis.isValid, true);
    });
  });
}
