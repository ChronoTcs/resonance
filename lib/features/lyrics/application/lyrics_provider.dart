import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/lyric_line.dart';
import '../../player/application/providers/audio_provider.dart';
import '../../library/application/library_provider.dart';
import '../../library/data/models/media_item.dart';
import '../data/repositories/lyrics_repository.dart';

class LyricsState {
  final List<LyricLine> lyrics;
  final bool isLoading;
  final String? error;
  final bool isVideoSynced;

  LyricsState({
    this.lyrics = const [],
    this.isLoading = false,
    this.error,
    this.isVideoSynced = false,
  });

  LyricsState copyWith({
    List<LyricLine>? lyrics,
    bool? isLoading,
    String? error,
    bool? isVideoSynced,
  }) {
    return LyricsState(
      lyrics: lyrics ?? this.lyrics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isVideoSynced: isVideoSynced ?? this.isVideoSynced,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  String? _lastLoadingPath;

  @override
  LyricsState build() {
    ref.listen(audioProvider, (previous, current) {
      final currTrack = current.currentTrack;

      if (currTrack == null) {
        _lastLoadingPath = null;
        state = LyricsState();
        return;
      }

      final effectiveId = currTrack.id ?? currTrack.path;
      if (effectiveId != _lastLoadingPath) {
        _lastLoadingPath = effectiveId;
        _loadLyrics(currTrack);
      }
    });

    ref.listen(libraryProvider.select((s) => s.lyricsFolderPath), (
      previous,
      current,
    ) {
      final audioState = ref.read(audioProvider);
      if (audioState.currentTrack != null) {
        _loadLyrics(audioState.currentTrack!);
      }
    });

    final initialAudioState = ref.read(audioProvider);
    if (initialAudioState.currentTrack != null) {
      final initialTrack = initialAudioState.currentTrack!;
      _lastLoadingPath = initialTrack.id ?? initialTrack.path;
      Future.microtask(
        () => _loadLyrics(initialTrack),
      );
    }

    return LyricsState();
  }

  Future<void> _loadLyrics(MediaItem track) async {
    final String songId = track.id ?? track.path;
    state = state.copyWith(lyrics: [], isLoading: true, error: null, isVideoSynced: false);
    
    try {
      final repo = ref.read(lyricsRepositoryProvider);
      final lyricsFolderPath = ref.read(libraryProvider).lyricsFolderPath;
      
      final result = await repo.getLyrics(track, lyricsFolderPath: lyricsFolderPath);

      if (_lastLoadingPath == songId) {
        state = state.copyWith(
          lyrics: result.lines,
          isVideoSynced: result.isVideoSynced,
          isLoading: false,
        );
      }
    } catch (e) {
      if (_lastLoadingPath == songId) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }

  /// Reloads lyrics for the current track (used when background sync finishes).
  void refresh() {
    final audioState = ref.read(audioProvider);
    if (audioState.currentTrack != null) {
      _loadLyrics(audioState.currentTrack!);
    }
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(() {
  return LyricsNotifier();
});

final adjustedLyricsPositionProvider = Provider.autoDispose<Duration>((ref) {
  final audioState = ref.watch(audioProvider);
  final lyricsState = ref.watch(lyricsProvider);
  final lyrics = lyricsState.lyrics;

  if (lyrics.isEmpty) return audioState.position;

  final offset = audioState.currentTrack?.lyricsOffset ?? Duration.zero;
  return audioState.position + offset;
});

final activeLyricIndexProvider = Provider.autoDispose<int>((ref) {
  final lyricsState = ref.watch(lyricsProvider);
  final lyrics = lyricsState.lyrics;

  if (lyrics.isEmpty) return -1;

  final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);

  int index = -1;
  for (int i = 0; i < lyrics.length; i++) {
    if (adjustedPosition >= lyrics[i].timestamp) {
      index = i;
    } else {
      break; 
    }
  }
  return index;
});
