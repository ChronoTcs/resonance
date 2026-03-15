import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../../../player/data/repositories/audio_provider.dart';
import '../../../library/data/repositories/library_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../core/services/data_usage_service.dart';

class LyricsState {
  final List<LyricLine> lyrics;
  final bool isLoading;
  final String? error;

  LyricsState({this.lyrics = const [], this.isLoading = false, this.error});

  LyricsState copyWith({
    List<LyricLine>? lyrics,
    bool? isLoading,
    String? error,
  }) {
    return LyricsState(
      lyrics: lyrics ?? this.lyrics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  String? _lastLoadingPath;

  @override
  LyricsState build() {
    // Automatically listen to audio state changes to trigger lyric loading
    ref.listen(audioProvider, (previous, current) {
      final currTrack = current.currentTrack;

      if (currTrack == null) {
        _lastLoadingPath = null;
        state = LyricsState();
        return;
      }

      // Trigger if path has changed. 
      // This allows refetching when moving from skeleton (thumbnail path) to real stream URL.
      final effectiveId = currTrack.id ?? currTrack.path;
      if (effectiveId != _lastLoadingPath) {
        _lastLoadingPath = effectiveId;
        _loadLyrics(currTrack);
      }
    });

    // Automatically listen to lyrics folder path setting changes
    ref.listen(libraryProvider.select((s) => s.lyricsFolderPath), (
      previous,
      current,
    ) {
      final audioState = ref.read(audioProvider);
      if (audioState.currentTrack != null) {
        _loadLyrics(audioState.currentTrack!);
      }
    });

    // Check if there's already a track playing before this provider was initialized
    final initialAudioState = ref.read(audioProvider);
    if (initialAudioState.currentTrack != null) {
      Future.microtask(
        () => _loadLyrics(initialAudioState.currentTrack!),
      );
    }

    return LyricsState();
  }

  Future<void> _loadLyrics(MediaItem track) async {
    final String trackPath = track.path;
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final cacheService = MediaCacheService();
      final libraryState = ref.read(libraryProvider);
      
      // Determine Identity
      final String songId = track.id ?? trackPath;
      final bool isStreaming = trackPath.startsWith('http') || track.id != null;
      
      // Determine filename for cache (safe version of ID)
      final String safeCacheId = isStreaming ? songId : p.basenameWithoutExtension(trackPath);

      // Recover metadata for cached tracks
      MediaItem currentTrack = track;
      if (track.artist == null || track.artist!.isEmpty || track.title == songId) {
         final cachedMeta = await cacheService.getCachedMetadata(songId);
         if (cachedMeta != null) {
           currentTrack = cachedMeta;
         }
      }

      // STEP 1: Check Custom Lyrics Folder (Selected in Settings)
      if (libraryState.lyricsFolderPath != null) {
        final fileName = isStreaming ? currentTrack.title : p.basenameWithoutExtension(trackPath);
        final lrcPath = p.join(libraryState.lyricsFolderPath!, '$fileName.lrc');
        final file = File(lrcPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          _updateLyrics(content, songId);
          return;
        }
      }

      // STEP 2: Check Local Folder (Same directory as track, for local files only)
      if (!isStreaming) {
        if (trackPath.contains('.')) {
          final lrcPath = trackPath.substring(0, trackPath.lastIndexOf('.')) + '.lrc';
          final file = File(lrcPath);
          if (await file.exists()) {
            final content = await file.readAsString();
            _updateLyrics(content, songId);
            return;
          }
        }
      }

      final cacheDir = await cacheService.getCacheDir();
      final safeId = cacheService.getSafeFilename(safeCacheId);
      final cachedFile = File(p.join(cacheDir.path, '$safeId.lrc'));
      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        _updateLyrics(content, songId);
        return;
      }

      // STEP 4: Fetch from LRCLIB (Streaming only)
      if (isStreaming && currentTrack.title.isNotEmpty && currentTrack.title != songId) {
        final artist = (currentTrack.artist ?? '').replaceAll(RegExp(r' - Topic$'), '');
        final title = currentTrack.title;

        print('Fetching lyrics from LRCLIB for: $artist - $title');

        final uri = Uri.parse('https://lrclib.net/api/get').replace(queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (currentTrack.duration != null && currentTrack.duration!.inSeconds > 0)
            'duration': currentTrack.duration!.inSeconds.toString(),
        });
        
        try {
          final response = await http.get(uri);
          if (response.statusCode == 200) {
            // Track data usage
            DataUsageService().addBytes(response.bodyBytes.length);
            
            final data = jsonDecode(response.body);
            final syncing = data['syncedLyrics'] as String?;
            final plain = data['plainLyrics'] as String?;
            final lyrics = syncing ?? plain;
            
            if (lyrics != null && lyrics.isNotEmpty) {
              // Save to cache
              await cachedFile.writeAsString(lyrics);
              _updateLyrics(lyrics, songId);
              return;
            }
          }
        } catch (e) {
          print('LRCLIB fetch error: $e');
        }
      }

      // All options exhausted
      if (_lastLoadingPath == songId) {
        state = state.copyWith(lyrics: [], isLoading: false);
      }
    } catch (e) {
      final String songId = track.id ?? trackPath;
      if (_lastLoadingPath == songId) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }

  void _updateLyrics(String content, String matchId) {
    if (_lastLoadingPath == matchId) {
      final parsedLyrics = _parseLrc(content);
      state = state.copyWith(lyrics: parsedLyrics, isLoading: false);
    }
  }

  List<LyricLine> _parseLrc(String content) {
    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    final timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = timeTagRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        // Sometimes milliseconds are 2 digits (e.g., .50 = 500ms) or 3 digits (e.g., .050 = 50ms)
        String millisStr = match.group(3)!;
        if (millisStr.length == 2) millisStr += '0';
        final milliseconds = int.parse(millisStr);

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        // Extract text part (everything after the time tag)
        final text = line.substring(match.end).trim();
        parsedLines.add(LyricLine(timestamp: duration, text: text));
      }
    }

    // Sort just in case LRC tags are jumbled
    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsedLines;
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(() {
  return LyricsNotifier();
});
