import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/lyric_line.dart';
import '../data/services/lyrics_translation_service.dart';
import 'lyrics_provider.dart';
import '../../player/application/audio_provider.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/storage_service.dart';
import 'package:path/path.dart' as p;
import 'translation_cache_cleanup.dart';

enum LyricsTranslationMode { original, translated, romanized }

class LyricsTranslationState {
  final bool isSystemEnabled;
  final LyricsTranslationMode mode;
  final String targetLanguage;
  final List<LyricLine>? translatedLyrics;
  final List<LyricLine>? romanizedLyrics;
  final bool isLoading;
  final String? error;

  LyricsTranslationState({
    this.isSystemEnabled = false,
    this.mode = LyricsTranslationMode.original,
    this.targetLanguage = 'id',
    this.translatedLyrics,
    this.romanizedLyrics,
    this.isLoading = false,
    this.error,
  });

  LyricsTranslationState copyWith({
    bool? isSystemEnabled,
    LyricsTranslationMode? mode,
    String? targetLanguage,
    List<LyricLine>? translatedLyrics,
    List<LyricLine>? romanizedLyrics,
    bool? isLoading,
    String? error,
  }) {
    return LyricsTranslationState(
      isSystemEnabled: isSystemEnabled ?? this.isSystemEnabled,
      mode: mode ?? this.mode,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translatedLyrics: translatedLyrics ?? this.translatedLyrics,
      romanizedLyrics: romanizedLyrics ?? this.romanizedLyrics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LyricsTranslationNotifier extends Notifier<LyricsTranslationState> {
  Timer? _debounceTimer;

  @override
  LyricsTranslationState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final systemEnabledPref = prefs.getBool('lyrics_translation_system_enabled') ?? false;
    final modeIndex = prefs.getInt('lyrics_translation_mode') ?? 
        (prefs.getBool('lyrics_translation_active') == true ? 1 : 0);
    final targetLangPref = prefs.getString('lyrics_translation_lang') ?? 'id';

    // Cleanup on dispose
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Run garbage collection on startup
    Future.microtask(() => TranslationCacheCleanup.cleanup(ref.read(cacheManagerProvider)));

    // Listen for track changes to clear translation or trigger it
    ref.listen(audioProvider.select((s) => s.currentTrack), (prev, next) {
      if (prev?.id != next?.id || prev?.path != next?.path) {
        // Cancel any pending request for the previous track immediately
        _debounceTimer?.cancel();
        
        state = state.copyWith(
          translatedLyrics: null, 
          romanizedLyrics: null,
          error: null,
          isLoading: false, 
        );
        _triggerLoadingForCurrentMode();
      }
    });

    // Also listen to lyricsProvider changes (when base lyrics are loaded)
    ref.listen(lyricsProvider, (prev, next) {
      if (next.lyrics.isNotEmpty) {
        _triggerLoadingForCurrentMode();
      }
    });

    return LyricsTranslationState(
      isSystemEnabled: systemEnabledPref,
      mode: systemEnabledPref 
          ? LyricsTranslationMode.values[modeIndex]
          : LyricsTranslationMode.original,
      targetLanguage: targetLangPref,
    );
  }

  /// Detects if lyrics contain scripts that typically require romanization (CJK, Hangul, etc.)
  bool _needsRomanization(List<LyricLine> lyrics) {
    if (lyrics.isEmpty) return false;
    
    // Check first 10 lines for performance
    final sample = lyrics.take(10).map((l) => l.text).join();
    
    // Regex for:
    // CJK characters: \u4e00-\u9fff (Chinese), \u3040-\u30ff (Japanese)
    // Hangul: \uac00-\ud7af
    // Cyrillic: \u0400-\u04ff
    // Thai/others: \u0e00-\u0e7f
    final nonLatinRegex = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff\u0e00-\u0e7f]');
    return nonLatinRegex.hasMatch(sample);
  }

  /// Triggers loading with a debounce to prevent spamming the API.
  /// PROACTIVE: Checks if either translation or romanization is missing
  /// even if not currently in that mode, to ensure background self-healing.
  void _triggerLoadingForCurrentMode() {
    if (!state.isSystemEnabled) return;

    // 1. Cancel any existing timer
    _debounceTimer?.cancel();

    // 2. Determine if fetching is needed (Check BOTH for healing)
    final needsTranslation = state.translatedLyrics == null;
    final needsRomanization = state.romanizedLyrics == null;

    if (!needsTranslation && !needsRomanization) return;

    // 3. Start a new timer (1.5 seconds debounce)
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _fetchAndCacheUnified();
    });
  }

  void toggleSystemEnabled() {
    final newValue = !state.isSystemEnabled;
    state = state.copyWith(
      isSystemEnabled: newValue,
      mode: newValue ? state.mode : LyricsTranslationMode.original,
    );
    ref.read(sharedPreferencesProvider).setBool('lyrics_translation_system_enabled', newValue);
  }

  void cycleMode() {
    if (!state.isSystemEnabled) return;

    // Cycle: Original (0) -> Translated (1) -> Romanized (2) -> Original (0)
    int nextIndex = (state.mode.index + 1) % 3;
    final nextMode = LyricsTranslationMode.values[nextIndex];

    state = state.copyWith(mode: nextMode);
    ref.read(sharedPreferencesProvider).setInt('lyrics_translation_mode', nextIndex);
    
    _triggerLoadingForCurrentMode();
  }

  void setTargetLanguage(String lang) {
    if (state.targetLanguage == lang) return;
    state = state.copyWith(targetLanguage: lang, translatedLyrics: null);
    ref.read(sharedPreferencesProvider).setString('lyrics_translation_lang', lang);
    
    if (state.mode == LyricsTranslationMode.translated) {
      _triggerLoadingForCurrentMode();
    }
  }

  /// Unified fetcher that populates both translation and romanization.
  /// RESILIENCE: Decouples cache discovery from network fetching.
  Future<void> _fetchAndCacheUnified() async {
    final currentTrack = ref.read(audioProvider).currentTrack;
    if (currentTrack == null) return;
    final trackIdAtStart = currentTrack.id ?? currentTrack.path;

    final originalLyrics = ref.read(lyricsProvider).lyrics;
    if (originalLyrics.isEmpty) return;

    if (state.isLoading) return; 

    state = state.copyWith(isLoading: true, error: null);

    try {
      final songId = trackIdAtStart;
      final cacheManager = ref.read(cacheManagerProvider);
      final translateDir = await cacheManager.getTranslateDir();
      final safeId = cacheManager.getSafeFilename(songId);
      
      final String transSuffix = state.targetLanguage.toUpperCase();
      final transCacheFile = File(p.join(translateDir.path, '${safeId}_$transSuffix.lrc'));
      final romanCacheFile = File(p.join(translateDir.path, '${safeId}_romanized.lrc'));

      List<LyricLine>? fetchedTranslated;
      List<LyricLine>? fetchedRomanized;

      // 1. Discovery Phase: Try to load whatever exists on disk
      if (await transCacheFile.exists()) {
        try {
          final content = await transCacheFile.readAsString();
          if (content.isNotEmpty) {
            fetchedTranslated = _internalParseLrc(content);
            if (fetchedTranslated.isNotEmpty) {
              await cacheManager.updateLastAccessed(transCacheFile);
            } else {
              fetchedTranslated = null; 
            }
          }
        } catch (e) {
          debugPrint('LyricsTranslation: FAILED to read trans cache: $e');
        }
      }

      if (await romanCacheFile.exists()) {
        try {
          final content = await romanCacheFile.readAsString();
          if (content.isNotEmpty) {
            fetchedRomanized = _internalParseLrc(content);
            if (fetchedRomanized.isNotEmpty) {
              await cacheManager.updateLastAccessed(romanCacheFile);
            } else {
              fetchedRomanized = null;
            }
          }
        } catch (e) {
          debugPrint('LyricsTranslation: FAILED to read roman cache: $e');
        }
      }

      // 2. Decision Phase: Choose between API call or local generation (ROM only)
      final trackIdConfirm = ref.read(audioProvider).currentTrack?.id ?? 
                             ref.read(audioProvider).currentTrack?.path;
      
      if (trackIdConfirm == trackIdAtStart) {
        final service = ref.read(lyricsTranslationServiceProvider);
        
        bool requiresNetwork = false;
        
        // Use network if ANY results are missing AND (it's TRN mode OR it's ROM mode but needs conversion)
        if (fetchedTranslated == null || fetchedRomanized == null) {
          if (state.mode == LyricsTranslationMode.translated) {
            // Always use network for TRN (to get the translation)
            requiresNetwork = true;
          } else if (state.mode == LyricsTranslationMode.romanized) {
            // Use network for ROM only if lyrics are non-Latin
            if (_needsRomanization(originalLyrics)) {
              requiresNetwork = true;
            } else {
              // OPTIMIZATION: Lirik Latin, gunakan original sebagai Romanized
              fetchedRomanized ??= List.from(originalLyrics);
              await romanCacheFile.writeAsString(service.stringify(fetchedRomanized));
              requiresNetwork = (fetchedTranslated == null && state.mode == LyricsTranslationMode.translated);
            }
          }
        }

        if (requiresNetwork) {
          final result = await service.fetchUnifiedLyrics(originalLyrics, state.targetLanguage);
          
          // Final sanity check before persistent update
          final trackIdNow = ref.read(audioProvider).currentTrack?.id ?? 
                             ref.read(audioProvider).currentTrack?.path;
          
          if (trackIdNow == trackIdAtStart) {
            fetchedTranslated = result.translated;
            fetchedRomanized = result.romanized;

            // 4. Persistence
            await transCacheFile.writeAsString(service.stringify(fetchedTranslated));
            await romanCacheFile.writeAsString(service.stringify(fetchedRomanized));
          }
        }
      }

      // 5. Completion State (Only if still on the same track)
      final trackIdFinal = ref.read(audioProvider).currentTrack?.id ?? 
                           ref.read(audioProvider).currentTrack?.path;
      if (trackIdFinal == trackIdAtStart) {
        state = state.copyWith(
          translatedLyrics: fetchedTranslated,
          romanizedLyrics: fetchedRomanized,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('LyricsTranslation: UNIFIED FETCH FAILED - $e');
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  List<LyricLine> _internalParseLrc(String content) {
    if (content.isEmpty) return [];
    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    final timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = timeTagRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        String millisStr = match.group(3)!;
        if (millisStr.length == 2) millisStr += '0';
        final milliseconds = int.parse(millisStr);

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final text = line.substring(match.end).trim();
        parsedLines.add(LyricLine(timestamp: duration, text: text));
      }
    }
    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsedLines;
  }
}

final lyricsTranslationProvider = NotifierProvider<LyricsTranslationNotifier, LyricsTranslationState>(() {
  return LyricsTranslationNotifier();
});

/// A provider that returns either the original, translated, or romanized lyrics 
/// based on the user's preference and availability.
final displayLyricsProvider = Provider<List<LyricLine>>((ref) {
  final baseLyrics = ref.watch(lyricsProvider).lyrics;
  final translationState = ref.watch(lyricsTranslationProvider);
  
  if (!translationState.isSystemEnabled) return baseLyrics;

  final mode = translationState.mode;

  if (mode == LyricsTranslationMode.translated) {
    final translated = translationState.translatedLyrics;
    if (translated != null && translated.isNotEmpty) {
      return translated;
    }
  }

  if (mode == LyricsTranslationMode.romanized) {
    final romanized = translationState.romanizedLyrics;
    if (romanized != null && romanized.isNotEmpty) {
      return romanized;
    }
  }

  return baseLyrics;
});
