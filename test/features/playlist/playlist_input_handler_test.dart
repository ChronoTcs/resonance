import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/playlist/application/services/playlist_input_handler.dart';

void main() {
  group('PlaylistInputHandler', () {
    test('parses youtu.be short link with tracking parameters', () {
      const input = 'https://youtu.be/3aqeo8cI-04?si=k7mzUI6dRvplA8YX';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.singleTrack);
      expect(res.videoId, '3aqeo8cI-04');
      expect(res.playlistId, isNull);
    });

    test('parses standard youtube.com watch link', () {
      const input = 'https://www.youtube.com/watch?v=3aqeo8cI-04';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.singleTrack);
      expect(res.videoId, '3aqeo8cI-04');
    });

    test('parses youtube.com playlist link', () {
      const input = 'https://www.youtube.com/playlist?list=PLrAlGZ1V3kR6abcdef123';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.playlist);
      expect(res.playlistId, 'PLrAlGZ1V3kR6abcdef123');
    });

    test('parses watch link with list parameter as playlist with video context', () {
      const input = 'https://www.youtube.com/watch?v=3aqeo8cI-04&list=PLrAlGZ1V3kR6abcdef123';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.playlist);
      expect(res.playlistId, 'PLrAlGZ1V3kR6abcdef123');
      expect(res.videoId, '3aqeo8cI-04');
    });

    test('identifies plain text search query', () {
      const input = 'Radiohead Creep live';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.searchQuery);
      expect(res.playlistId, isNull);
      expect(res.videoId, isNull);
    });

    test('identifies raw 11-char video ID', () {
      const input = '3aqeo8cI-04';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.singleTrack);
      expect(res.videoId, '3aqeo8cI-04');
    });

    test('identifies raw playlist ID', () {
      const input = 'PLrAlGZ1V3kR6abcdef123';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.playlist);
      expect(res.playlistId, 'PLrAlGZ1V3kR6abcdef123');
    });

    test('rejects non-youtube domains', () {
      const input = 'https://example.com/watch?v=12345';
      final res = PlaylistInputHandler.analyze(input);

      expect(res.type, PlaylistInputType.invalid);
      expect(res.errorMessage, contains('Unsupported domain'));
    });
  });
}
