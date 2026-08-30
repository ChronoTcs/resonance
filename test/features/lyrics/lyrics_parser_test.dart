import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/lyrics/data/services/lyrics_parser.dart';

void main() {
  group('LyricsParser Tests', () {
    test('Should parse standard line-by-line LRC lyrics correctly', () {
      const lrcContent = '''
[00:12.30]Line 1 lyrics text
[00:15.80]Line 2 lyrics text
''';
      final parsed = LyricsParser.parse(lrcContent);

      expect(parsed.length, equals(2));
      expect(parsed[0].timestamp, equals(const Duration(seconds: 12, milliseconds: 300)));
      expect(parsed[0].text, equals('Line 1 lyrics text'));
      expect(parsed[0].syllables, isNull);

      expect(parsed[1].timestamp, equals(const Duration(seconds: 15, milliseconds: 800)));
      expect(parsed[1].text, equals('Line 2 lyrics text'));
      expect(parsed[1].syllables, isNull);
    });

    test('Should parse Enhanced syllable-level LRC lyrics correctly', () {
      const enhancedLrcContent = '''
[00:10.00]<00:10.00> Hello <00:10.50> World
''';
      final parsed = LyricsParser.parse(enhancedLrcContent);

      expect(parsed.length, equals(1));
      expect(parsed[0].timestamp, equals(const Duration(seconds: 10)));
      expect(parsed[0].text, equals('Hello World'));
      expect(parsed[0].syllables, isNotNull);
      expect(parsed[0].syllables!.length, equals(2));

      final syllables = parsed[0].syllables!;
      expect(syllables[0].text, equals('Hello'));
      expect(syllables[0].offset, equals(Duration.zero));
      expect(syllables[0].duration, equals(const Duration(milliseconds: 500)));

      expect(syllables[1].text, equals('World'));
      expect(syllables[1].offset, equals(const Duration(milliseconds: 500)));
      // The last syllable defaults to 300ms since there's no next syllable to measure from
      expect(syllables[1].duration, equals(const Duration(milliseconds: 300)));
    });

    test('Should clean YouTube metadata noise terms from track titles', () {
      expect(LyricsParser.cleanTitle('Blinding Lights (Official Video)'), equals('Blinding Lights'));
      expect(LyricsParser.cleanTitle('Song Name (feat. Artist B)'), equals('Song Name'));
    });

    test('cleanVideoNoise should strip video packaging but preserve musical variants', () {
      expect(
        LyricsParser.cleanVideoNoise('Starboy (Official Music Video) (feat. Daft Punk)'),
        equals('Starboy (feat. Daft Punk)'),
      );
      expect(
        LyricsParser.cleanVideoNoise('Save Your Tears (Official Audio) (Remix) [feat. Ariana Grande]'),
        equals('Save Your Tears (Remix) [feat. Ariana Grande]'),
      );
      expect(
        LyricsParser.cleanVideoNoise('Hotel California (Live on MTV) [4K Remastered]'),
        equals('Hotel California (Live on MTV)'),
      );
    });

    test('cleanArtist should support preserving and stripping collaborators', () {
      expect(LyricsParser.cleanArtist('The Weeknd - Topic'), equals('The Weeknd'));
      expect(LyricsParser.cleanArtist('Taylor Swift feat. Kendrick Lamar', preserveCollaborators: true), equals('Taylor Swift feat. Kendrick Lamar'));
      expect(LyricsParser.cleanArtist('Taylor Swift feat. Kendrick Lamar', preserveCollaborators: false), equals('Taylor Swift'));
      expect(LyricsParser.cleanArtist('B.o.B & Bruno Mars', preserveCollaborators: false), equals('B.o.B'));
      expect(LyricsParser.cleanArtist('B.o.B & Bruno Mars', preserveCollaborators: true), equals('B.o.B & Bruno Mars'));
    });

    test('parseHyphenatedTitle should respect preserveFeatures flag', () {
      final preserved = LyricsParser.parseHyphenatedTitle('B.o.B - Nothin\' on You (Official Video) (feat. Bruno Mars)', 'B.o.B', preserveFeatures: true);
      expect(preserved.artist, equals('B.o.B'));
      expect(preserved.title, equals('Nothin\' on You (feat. Bruno Mars)'));

      final stripped = LyricsParser.parseHyphenatedTitle('B.o.B - Nothin\' on You (Official Video) (feat. Bruno Mars)', 'B.o.B', preserveFeatures: false);
      expect(stripped.artist, equals('B.o.B'));
      expect(stripped.title, equals('Nothin\' on You'));
    });
  });
}
