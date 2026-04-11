import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../../../../core/data/services/data_usage_service.dart';

class UnifiedLyricsResult {
  final List<LyricLine> translated;
  final List<LyricLine> romanized;

  UnifiedLyricsResult({required this.translated, required this.romanized});
}

class LyricsTranslationService {
  final Ref _ref;

  LyricsTranslationService(this._ref);

  /// Fetches both translation and romanization (pronunciation) from Google Translate
  /// in a single HTTP request for maximum efficiency.
  /// Uses a "Delimiter Hack" to preserve synchronization across lines.
  Future<UnifiedLyricsResult> fetchUnifiedLyrics(
    List<LyricLine> originalLyrics,
    String targetLanguage,
  ) async {
    if (originalLyrics.isEmpty) {
      return UnifiedLyricsResult(translated: [], romanized: []);
    }

    // 1. Injection Phase: Use a special delimiter '|' to preserve line boundaries
    // Google dt=rm often collapses \n, but normally preserves '|'
    final List<String> sourceTexts = originalLyrics.map((l) => l.text).toList();
    final String combinedText = sourceTexts.join(' \n | \n ');

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLanguage&dt=t&dt=rm'
      );

      final response = await http.post(
        url,
        body: {'q': combinedText},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Google Translate API error: ${response.statusCode}');
      }

      _ref.read(dataUsageServiceProvider).addBytes(combinedText.length + response.body.length);

      final dynamic decoded = jsonDecode(response.body);
      
      if (decoded is! List || decoded.isEmpty || decoded[0] is! List) {
        throw Exception('Invalid Google Translate response format');
      }

      final List<dynamic> segments = decoded[0];
      StringBuffer fullTranslatedBuf = StringBuffer();
      String fullRomanized = '';

      // 2. Collection Phase: Build full strings from segments
      for (var segment in segments) {
        if (segment is List && segment.isNotEmpty) {
          // dt=t (Translation) is usually at segment[0]
          if (segment[0] != null) {
            fullTranslatedBuf.write(segment[0].toString());
          }

          // dt=rm (Transliteration/Pronunciation) logic:
          // Google often hides the full pronunciation of the source text in a segment
          // where index 0 and 1 are null, and pronunciation is in index 2 or 3.
          if (segment.length >= 3 && segment[0] == null && segment[1] == null) {
            // Pronunciation segment found
            fullRomanized = segment[3]?.toString() ?? segment[2]?.toString() ?? '';
          }
        }
      }

      final String fullTranslated = fullTranslatedBuf.toString();

      // 3. Splitting Phase: Precision split using Regex to handle optional whitespace
      final delimiterRegex = RegExp(r'\s*\|\s*');
      final List<String> translatedLines = fullTranslated.split(delimiterRegex);
      final List<String> romanizedLines = fullRomanized.split(delimiterRegex);

      // 4. Re-stitching Phase: Align with original timestamps and handle fallbacks
      final List<LyricLine> translatedResult = [];
      final List<LyricLine> romanizedResult = [];

      for (int i = 0; i < originalLyrics.length; i++) {
        final original = originalLyrics[i];
        
        // Translated mapping
        String tText = '';
        if (i < translatedLines.length) {
          tText = translatedLines[i].trim();
        }
        // Fallback if split failed or text was lost
        if (tText.isEmpty || tText == '|') {
          tText = original.text;
        }
        translatedResult.add(LyricLine(timestamp: original.timestamp, text: tText));

        // Romanized mapping
        String rText = '';
        if (i < romanizedLines.length) {
          rText = romanizedLines[i].trim();
        }
        // Fallback if pronunciation is missing (e.g. English) or split failed
        if (rText.isEmpty || rText == '|') {
          rText = original.text;
        }
        romanizedResult.add(LyricLine(timestamp: original.timestamp, text: rText));
      }

      return UnifiedLyricsResult(
        translated: translatedResult,
        romanized: romanizedResult,
      );
    } catch (e) {
      debugPrint('LyricsTranslationService: Unified fetch failed (Delimiter Hack) - $e');
      rethrow;
    }
  }

  /// Converts a list of LyricLines back to a .lrc string for caching
  String stringify(List<LyricLine> lyrics) {
    final buffer = StringBuffer();
    for (var line in lyrics) {
      final totalMs = line.timestamp.inMilliseconds;
      final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final millis = ((totalMs % 1000) ~/ 10).toString().padLeft(2, '0');
      
      buffer.writeln('[$minutes:$seconds.$millis]${line.text}');
    }
    return buffer.toString();
  }
}

final lyricsTranslationServiceProvider = Provider<LyricsTranslationService>((ref) {
  return LyricsTranslationService(ref);
});
