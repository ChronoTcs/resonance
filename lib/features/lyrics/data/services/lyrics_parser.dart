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
      debugPrint('LyricsParser: No time tags found. Parsing as plain text.');
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

  /// Cleans YouTube titles
  static String cleanTitle(String title) {
    if (title.isEmpty) return "";
    String clean = title;

    final titleCleanupPatterns = [
      RegExp(r'\s*\(.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\)', caseSensitive: false),
      RegExp(r'\s*\[.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\]', caseSensitive: false),
      RegExp(r'\s*【.*?】'),
      RegExp(r'\s*\|.*$'),
      RegExp(r'\s*-\s*(official|video|audio|lyrics|lyric|visualizer).*$', caseSensitive: false),
      RegExp(r'\s*\((feat\.|ft\.).*?\)', caseSensitive: false),
      RegExp(r'\s*(feat\.|ft\.).*$', caseSensitive: false),
    ];

    for (var pattern in titleCleanupPatterns) {
      clean = clean.replaceAll(pattern, '');
    }

    return clean.trim();
  }

  /// Cleans artist names
  static String cleanArtist(String artist) {
    if (artist.isEmpty) return "";
    String primary = artist.split('•')[0];

    final artistSeparators = [' & ', ' and ', ', ', ' x ', ' X ', ' feat. ', ' feat ', ' ft. ', ' ft ', ' featuring ', ' with '];
    for (var sep in artistSeparators) {
      if (primary.contains(sep)) {
        primary = primary.split(sep)[0];
      }
    }

    final suffixes = [" - Topic", "VEVO", " Official", " Music", " TV"];
    for (var suffix in suffixes) {
      if (primary.endsWith(suffix)) {
        primary = primary.substring(0, primary.length - suffix.length).trim();
      }
    }
    return primary.trim();
  }

  /// Parses hyphenated track title
  static ({String artist, String title}) parseHyphenatedTitle(String title, String defaultArtist) {
    String cleanedTitle = cleanTitle(title);
    if (cleanedTitle.contains('|')) {
      cleanedTitle = cleanedTitle.split('|')[0].trim();
    }
    final cleanDefaultArtist = cleanArtist(defaultArtist);
    if (cleanDefaultArtist.isNotEmpty && cleanedTitle.startsWith(cleanDefaultArtist)) {
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
