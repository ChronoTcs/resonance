import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/lyric_line.dart';
import '../data/services/lyrics_translation_service.dart';
import 'lyrics_provider.dart';
import '../../player/application/providers/audio_provider.dart';
import '../../../core/data/services/cache_manager.dart';
import '../../../core/data/services/storage_service.dart';
import 'package:path/path.dart' as p;
import 'translation_cache_cleanup_service.dart';

enum LyricsTranslationMode { original, translated, romanized }

class LyricsTranslationState {
  final bool isSystemEnabled;
  final LyricsTranslationMode mode;
  final String targetLanguage;
  final List<LyricLine>? translatedLyrics;
  final List<LyricLine>? romanizedLyrics;
  final String? lastTrackId; // Tracks which song the translations belong to
  final bool isLoading;
  final String? error;

  LyricsTranslationState({
    this.isSystemEnabled = false,
    this.mode = LyricsTranslationMode.original,
    this.targetLanguage = 'id',
    this.translatedLyrics,
    this.romanizedLyrics,
    this.lastTrackId,
    this.isLoading = false,
    this.error,
  });

  LyricsTranslationState copyWith({
    bool? isSystemEnabled,
    LyricsTranslationMode? mode,
    String? targetLanguage,
    List<LyricLine>? translatedLyrics,
    List<LyricLine>? romanizedLyrics,
    String? lastTrackId,
    bool? isLoading,
    String? error,
  }) {
    return LyricsTranslationState(
      isSystemEnabled: isSystemEnabled ?? this.isSystemEnabled,
      mode: mode ?? this.mode,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translatedLyrics: translatedLyrics ?? this.translatedLyrics,
      romanizedLyrics: romanizedLyrics ?? this.romanizedLyrics,
      lastTrackId: lastTrackId ?? this.lastTrackId,
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
      final effectiveId = next?.id ?? next?.path;
      final prevId = prev?.id ?? prev?.path;

      if (effectiveId != prevId) {
        _debounceTimer?.cancel();
        // Use direct constructor — copyWith uses ?? so passing null doesn't clear fields.
        // We must genuinely null translatedLyrics/romanizedLyrics to avoid stale data.
        state = LyricsTranslationState(
          isSystemEnabled: state.isSystemEnabled,
          mode: LyricsTranslationMode.original,
          targetLanguage: state.targetLanguage,
          translatedLyrics: null,
          romanizedLyrics: null,
          lastTrackId: effectiveId, // Claim B's ID immediately so staleness guard passes correctly
          isLoading: false,
          error: null,
        );
        
        // SOTA V3.3: Attempt early cache discovery immediately
        if (effectiveId != null) {
          _tryEarlyCacheLoad(effectiveId);
        }
        
        _triggerLoadingForCurrentMode();
      }
    });

    // Also listen to lyricsProvider changes (when base lyrics are loaded)
    ref.listen(lyricsProvider, (prev, next) {
      if (!next.isLoading && next.lyrics.isNotEmpty) {
        debugPrint('LyricsTranslation: Base lyrics loaded. Evaluating translation fetch...');
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

    // In original mode there is nothing to fetch. Returning here prevents a
    // background isLoading=true that would silently block the user's first
    // explicit "translate" click via the isLoading guard in _fetchAndCacheUnified.
    // Translations are fetched on-demand when the user cycles to a non-original mode.
    if (state.mode == LyricsTranslationMode.original) return;

    // 1. Cancel any existing timer
    _debounceTimer?.cancel();

    // 2. Check if we already have sufficient data in state (from early load)
    final bool hasTranslated = state.translatedLyrics != null;
    final bool hasRomanized = state.romanizedLyrics != null;
    
    // Healing check: if we are in Translated mode but have no TRN, or Romanized mode but no ROM
    bool needsWait = false;
    if (state.mode == LyricsTranslationMode.translated && !hasTranslated) needsWait = true;
    if (state.mode == LyricsTranslationMode.romanized && !hasRomanized) needsWait = true;
    
    if (!needsWait && hasTranslated && hasRomanized) return;

    // 3. Check if base lyrics are ready. If not, wait for them.
    final lyricsState = ref.read(lyricsProvider);
    if (lyricsState.isLoading || lyricsState.lyrics.isEmpty) {
        return; // Silent wait
    }

    // 4. Start a new timer (Short debounce for UX stability)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAndCacheUnified();
    });
  }

  /// SOTA V3.3: Instant disk discovery without waiting for LRC parser.
  /// Uses a Race Condition guard to prevent stale state updates.
  Future<void> _tryEarlyCacheLoad(String trackId) async {
    final cacheManager = ref.read(cacheManagerProvider);
    final translateDir = await cacheManager.getTranslateDir();
    final safeId = cacheManager.getSafeFilename(trackId);
    
    final String transSuffix = state.targetLanguage.toUpperCase();
    final transFile = File(p.join(translateDir.path, '${safeId}_$transSuffix.lrc'));
    final romanFile = File(p.join(translateDir.path, '${safeId}_romanized.lrc'));

    List<LyricLine>? earlyTRN;
    List<LyricLine>? earlyROM;

    if (await transFile.exists()) {
      try {
        final content = await transFile.readAsString();
        if (content.isNotEmpty) earlyTRN = _internalParseLrc(content);
      } catch (_) {}
    }

    if (await romanFile.exists()) {
      try {
        final content = await romanFile.readAsString();
        if (content.isNotEmpty) earlyROM = _internalParseLrc(content);
      } catch (_) {}
    }

    // RACE CONDITION GUARD: Verify we are still on the same track
    final currentId = ref.read(audioProvider).currentTrack?.id ?? 
                      ref.read(audioProvider).currentTrack?.path;
    
    if (currentId != trackId) {
      debugPrint('LyricsTranslation: Early load CANCELED (User skipped fast).');
      return;
    }

    if (earlyTRN != null || earlyROM != null) {
      debugPrint('LyricsTranslation: Early Cache Hit for $trackId');
      state = state.copyWith(
        translatedLyrics: earlyTRN,
        romanizedLyrics: earlyROM,
        lastTrackId: trackId,
      );
    }
  }

  void toggleSystemEnabled() {
    final newValue = !state.isSystemEnabled;
    state = state.copyWith(
      isSystemEnabled: newValue,
      mode: newValue ? state.mode : LyricsTranslationMode.original,
    );
    ref.read(sharedPreferencesProvider).setBool('lyrics_translation_system_enabled', newValue);
    
    if (newValue) {
      _triggerLoadingForCurrentMode();
    }
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
    state = state.copyWith(targetLanguage: lang, translatedLyrics: null, error: null);
    ref.read(sharedPreferencesProvider).setString('lyrics_translation_lang', lang);
    
    // Trigger loading regardless of mode, to pre-fetch for other modes
    _triggerLoadingForCurrentMode();
  }

  /// Manually retries the failed fetch for the current mode.
  void retry() {
    if (state.isLoading) return;
    state = state.copyWith(error: null);
    _triggerLoadingForCurrentMode();
  }

  /// Unified fetcher that populates both translation and romanization.
  /// RESILIENCE: Decouples cache discovery from network fetching.
  Future<void> _fetchAndCacheUnified() async {
    final currentTrack = ref.read(audioProvider).currentTrack;
    if (currentTrack == null) return;
    final trackIdAtStart = currentTrack.id ?? currentTrack.path;

    // IDENTTY GUARD: Always claim the track ID early if it's missing or changed.
    // This ensures that displayLyricsProvider knows we are tracking the current song,
    // even if we haven't fetched the translations yet.
    if (state.lastTrackId != trackIdAtStart) {
      state = state.copyWith(lastTrackId: trackIdAtStart);
    }

    final originalLyrics = ref.read(lyricsProvider).lyrics;
    if (originalLyrics.isEmpty) {
      debugPrint('LyricsTranslation: Base lyrics not yet available for $trackIdAtStart. Waiting...');
      return;
    }

    if (state.isLoading) return; 

    // SOTA V3.3: State-First Discovery. If early loader already finished, use that data.
    List<LyricLine>? fetchedTranslated = state.translatedLyrics;
    List<LyricLine>? fetchedRomanized = state.romanizedLyrics;

    final songId = trackIdAtStart;
    final cacheManager = ref.read(cacheManagerProvider);
    final translateDir = await cacheManager.getTranslateDir();
    final safeId = cacheManager.getSafeFilename(songId);
    
    final String transSuffix = state.targetLanguage.toUpperCase();
    final transCacheFile = File(p.join(translateDir.path, '${safeId}_$transSuffix.lrc'));
    final romanCacheFile = File(p.join(translateDir.path, '${safeId}_romanized.lrc'));

    // 1. Discovery Phase (PRE-LOADING): Only read from disk if state is missing
    if (fetchedTranslated == null && await transCacheFile.exists()) {
      try {
        final content = await transCacheFile.readAsString();
        if (content.isNotEmpty) fetchedTranslated = _internalParseLrc(content);
      } catch (_) {}
    }

    if (fetchedRomanized == null && await romanCacheFile.exists()) {
      try {
        final content = await romanCacheFile.readAsString();
        if (content.isNotEmpty) fetchedRomanized = _internalParseLrc(content);
      } catch (_) {}
    }

    // Check if we hit everything from cache
    final hasAllNeeded = fetchedTranslated != null && fetchedRomanized != null;
    
    if (hasAllNeeded) {
      state = state.copyWith(
        translatedLyrics: fetchedTranslated,
        romanizedLyrics: fetchedRomanized,
        lastTrackId: trackIdAtStart,
        isLoading: false,
      );
      return;
    }

    // 2. Network Phase: Only now we show loading
    state = state.copyWith(isLoading: true, error: null);

    try {

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
              // OPTIMIZATION SOTA V3.3: Lirik Latin, gunakan original sebagai Romanized (Silent Healing)
              fetchedRomanized ??= List.from(originalLyrics);
              // Background fire-and-forget write to satisfy hasAllNeeded in future
              romanCacheFile.writeAsString(service.stringify(fetchedRomanized)).catchError((e) {
                debugPrint('LyricsTranslation: Silent ROM healing failed - $e');
                return romanCacheFile;
              });
              
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
          translatedLyrics: fetchedTranslated ?? state.translatedLyrics,
          romanizedLyrics: fetchedRomanized ?? state.romanizedLyrics,
          lastTrackId: trackIdAtStart,
          isLoading: false,
          error: null,
        );
      } else {
        // Track changed during fetch, just clear loading
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('LyricsTranslation: FAILED fetch for $trackIdAtStart - $e');
      
      // Only set error if we are still on the same track
      final trackIdError = ref.read(audioProvider).currentTrack?.id ?? 
                           ref.read(audioProvider).currentTrack?.path;
      if (trackIdError == trackIdAtStart) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false);
      }
    } finally {
      // Safety guarantee: Always reset loading if it stays hanging
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

  // STALENESS GUARD: If the translation state belongs to a different track, fallback to base.
  final currentTrack = ref.watch(audioProvider.select((s) => s.currentTrack));
  final effectiveId = currentTrack?.id ?? currentTrack?.path;
  if (translationState.lastTrackId != effectiveId) {
     return baseLyrics;
  }

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
