import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/lyric_line.dart';
import '../../player/application/audio_provider.dart';
import '../../library/application/library_provider.dart';
import '../../library/data/models/media_item.dart';
import '../data/repositories/lyrics_repository.dart';

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
      Future.microtask(
        () => _loadLyrics(initialAudioState.currentTrack!),
      );
    }

    return LyricsState();
  }

  Future<void> _loadLyrics(MediaItem track) async {
    final String songId = track.id ?? track.path;
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final repo = ref.read(lyricsRepositoryProvider);
      final lyricsFolderPath = ref.read(libraryProvider).lyricsFolderPath;
      
      final lyrics = await repo.getLyrics(track, lyricsFolderPath: lyricsFolderPath);

      if (_lastLoadingPath == songId) {
        state = state.copyWith(lyrics: lyrics, isLoading: false);
      }
    } catch (e) {
      if (_lastLoadingPath == songId) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(() {
  return LyricsNotifier();
});

final activeLyricIndexProvider = Provider.autoDispose<int>((ref) {
  final audioState = ref.watch(audioProvider);
  final lyricsState = ref.watch(lyricsProvider);
  final lyrics = lyricsState.lyrics;

  if (lyrics.isEmpty) return -1;

  int index = -1;
  for (int i = 0; i < lyrics.length; i++) {
    if (audioState.position >= lyrics[i].timestamp) {
      index = i;
    } else {
      break; 
    }
  }
  return index;
});
