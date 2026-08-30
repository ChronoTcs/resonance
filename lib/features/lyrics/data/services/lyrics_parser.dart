import 'package:flutter/foundation.dart';
import '../models/lyric_line.dart';
import '../models/syllable_lyric_line.dart';

class LyricsParser {
  /// Checks if lyrics have time tags
  static bool hasTimeTags(String content) {
    return content.contains(RegExp(r'\[\d{1,3}:\d{2}[.:]\d{2,3}\]'));
  }

  /// Parses raw lyric content (standard LRC, Enhanced LRC, or plain text)
  static List<LyricLine> parse(String content) {
    if (content.isEmpty) return [];

    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    final timeTagRegex = RegExp(r'^\[(\d{1,3}):(\d{2})[.:](\d{2,3})\]');

    for (var line in lines) {
      final cleanLine = line.trim();
      final match = timeTagRegex.firstMatch(cleanLine);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        String millisStr = match.group(3)!;
        if (millisStr.length == 2) millisStr += '0';
        final milliseconds = int.parse(millisStr.substring(0, 3));

        final lineTimestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final rawText = cleanLine.substring(match.end).trim();

        // Check if this line is an Enhanced LRC line with syllable timings
        // Example: <00:12.30> Word1 <00:12.50> Word2
        final syllableRegex = RegExp(r'<(\d{1,3}):(\d{2})[.:](\d{2,3})>\s*([^<]*)');
        final matches = syllableRegex.allMatches(rawText);

        if (matches.isNotEmpty) {
          final List<SyllableWord> syllables = [];
          final buffer = StringBuffer();

          for (final m in matches) {
            final min = int.parse(m.group(1)!);
            final sec = int.parse(m.group(2)!);
            String milStr = m.group(3)!;
            if (milStr.length == 2) milStr += '0';
            final mil = int.parse(milStr.substring(0, 3));

            final wordTimestamp = Duration(
              minutes: min,
              seconds: sec,
              milliseconds: mil,
            );

            // Compute relative offset of the word from parent line start
            final relativeOffset = wordTimestamp - lineTimestamp;
            final wordText = m.group(4) ?? '';
            
            // Add spacing between words in the compiled text buffer
            if (buffer.isNotEmpty && !buffer.toString().endsWith(' ') && !wordText.startsWith(' ')) {
              buffer.write(' ');
            }
            buffer.write(wordText.trim());

            syllables.add(SyllableWord(
              text: wordText.trim(),
              offset: relativeOffset >= Duration.zero ? relativeOffset : Duration.zero,
              duration: const Duration(milliseconds: 300), // Default placeholder
            ));
          }

          // Backfill durations based on the next syllable's start time
          for (int i = 0; i < syllables.length - 1; i++) {
            final current = syllables[i];
            final next = syllables[i + 1];
            final computedDuration = next.offset - current.offset;
            if (computedDuration > Duration.zero) {
              syllables[i] = SyllableWord(
                text: current.text,
                offset: current.offset,
                duration: computedDuration,
              );
            }
          }

          parsedLines.add(LyricLine(
            timestamp: lineTimestamp,
            text: buffer.toString().trim(),
            syllables: syllables,
          ));
        } else {
          // Standard line-by-line LRC fallback (strip out any stray bracket tags if any)
          final cleanText = rawText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          parsedLines.add(LyricLine(
            timestamp: lineTimestamp,
            text: cleanText,
          ));
        }
      }
    }

    // Fallback: If no time tags found, treat as plain text with 2s intervals
    if (parsedLines.isEmpty && content.trim().isNotEmpty) {
      debugPrint('[LyricsParser] No time tags found. Parsing as plain text.');
      final plainLines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (int i = 0; i < plainLines.length; i++) {
        parsedLines.add(
          LyricLine(
            timestamp: Duration(seconds: i * 2),
            text: plainLines[i].trim(),
          ),
        );
      }
    }

    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsedLines;
  }

  /// Strips YouTube video packaging noise while PRESERVING musical variants
  /// (e.g. keeps "(feat. ...)", "[feat. ...]", "(Remix)", "(Acoustic)", "(Live)").
  static String cleanVideoNoise(String title) {
    if (title.isEmpty) return "";
    String clean = title;

    final videoNoisePatterns = [
      RegExp(r'\s*\(.*?(official\s*(music\s*)?video|official\s*audio|lyric\s*video|lyrics|visualizer|hd|hq|4k|1080p|remaster(ed)?).*?\)', caseSensitive: false),
      RegExp(r'\s*\[.*?(official\s*(music\s*)?video|official\s*audio|lyric\s*video|lyrics|visualizer|hd|hq|4k|1080p|remaster(ed)?).*?\]', caseSensitive: false),
      RegExp(r'\s*【.*?】'),
      RegExp(r'\s*\|.*$'),
      RegExp(r'\s*-\s*(official\s*(music\s*)?video|official\s*audio|lyric\s*video|lyrics|visualizer).*$', caseSensitive: false),
    ];

    for (var pattern in videoNoisePatterns) {
      clean = clean.replaceAll(pattern, '');
    }

    return clean.trim();
  }

  /// Cleans title completely (stripping features & variants too) for fallback search stages
  static String cleanTitle(String title) {
    if (title.isEmpty) return "";
    String clean = cleanVideoNoise(title);

    final variantPatterns = [
      RegExp(r'\s*\(.*?(remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\)', caseSensitive: false),
      RegExp(r'\s*\[.*?(remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\]', caseSensitive: false),
      RegExp(r'\s*\((feat\.|ft\.|featuring|with).*?\)', caseSensitive: false),
      RegExp(r'\s*\[(feat\.|ft\.|featuring|with).*?\]', caseSensitive: false),
      RegExp(r'\s*(feat\.|ft\.|featuring|with)\s+.*$', caseSensitive: false),
    ];

    for (var pattern in variantPatterns) {
      clean = clean.replaceAll(pattern, '');
    }

    return clean.trim();
  }

  /// Cleans artist names.
  /// When [preserveCollaborators] is true, keeps secondary artists ("Artist A & Artist B" or "Artist A feat. B").
  /// When false, extracts only the primary artist name.
  static String cleanArtist(String artist, {bool preserveCollaborators = false}) {
    if (artist.isEmpty) return "";
    String result = artist.split('•')[0].trim();

    final suffixes = [" - Topic", "VEVO", " Official", " Music", " TV"];
    for (var suffix in suffixes) {
      if (result.toLowerCase().endsWith(suffix.toLowerCase())) {
        result = result.substring(0, result.length - suffix.length).trim();
      }
    }

    if (!preserveCollaborators) {
      final artistSeparators = [' & ', ' and ', ', ', ' x ', ' X ', ' feat. ', ' feat ', ' ft. ', ' ft ', ' featuring ', ' with '];
      for (var sep in artistSeparators) {
        if (result.contains(sep)) {
          result = result.split(sep)[0].trim();
        }
      }
    }

    return result.trim();
  }

  /// Parses hyphenated track title (e.g. "Artist - Title (feat. Someone)")
  /// When [preserveFeatures] is true, keeps "(feat. ...)" or variant tags in title.
  static ({String artist, String title}) parseHyphenatedTitle(
    String title,
    String defaultArtist, {
    bool preserveFeatures = true,
  }) {
    String cleanedTitle = preserveFeatures ? cleanVideoNoise(title) : cleanTitle(title);
    if (cleanedTitle.contains('|')) {
      cleanedTitle = cleanedTitle.split('|')[0].trim();
    }
    final cleanDefaultArtist = cleanArtist(defaultArtist, preserveCollaborators: preserveFeatures);
    if (cleanDefaultArtist.isNotEmpty && cleanedTitle.toLowerCase().startsWith(cleanDefaultArtist.toLowerCase())) {
      cleanedTitle = cleanedTitle.substring(cleanDefaultArtist.length).trim();
      if (cleanedTitle.startsWith('-')) {
        cleanedTitle = cleanedTitle.substring(1).trim();
      }
    }

    if (cleanedTitle.contains(' - ')) {
      final parts = cleanedTitle.split(' - ');
      final potentialArtist = parts[0].trim();
      final potentialTitle = parts.sublist(1).join(' - ').trim();
      if (potentialArtist.isNotEmpty && potentialTitle.isNotEmpty) {
        return (artist: potentialArtist, title: potentialTitle);
      }
    }
    return (artist: cleanDefaultArtist, title: cleanedTitle);
  }
}
