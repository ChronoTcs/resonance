import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../../../player/data/repositories/audio_provider.dart';
import '../../../library/data/repositories/library_provider.dart';

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
  @override
  LyricsState build() {
    // Automatically listen to audio state changes to trigger lyric loading
    ref.listen(audioProvider, (previous, current) {
      if (previous?.currentTrack?.path != current.currentTrack?.path) {
        if (current.currentTrack != null) {
          _loadLyricsForPath(current.currentTrack!.path);
        } else {
          state = LyricsState();
        }
      }
    });

    // Automatically listen to lyrics folder path setting changes
    ref.listen(libraryProvider.select((s) => s.lyricsFolderPath), (
      previous,
      current,
    ) {
      final audioState = ref.read(audioProvider);
      if (audioState.currentTrack != null) {
        _loadLyricsForPath(audioState.currentTrack!.path);
      }
    });

    // Check if there's already a track playing before this provider was initialized
    final initialAudioState = ref.read(audioProvider);
    if (initialAudioState.currentTrack != null) {
      Future.microtask(
        () => _loadLyricsForPath(initialAudioState.currentTrack!.path),
      );
    }

    return LyricsState();
  }

  Future<void> _loadLyricsForPath(String audioPath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Assuming LRC file has same name as media file
      String lrcPath =
          audioPath.substring(0, audioPath.lastIndexOf('.')) + '.lrc';
      File file = File(lrcPath);

      if (!(await file.exists())) {
        final libraryState = ref.read(libraryProvider);
        if (libraryState.lyricsFolderPath != null) {
          final fileName = audioPath.split(RegExp(r'[/\\]')).last;
          final lastDotIndex = fileName.lastIndexOf('.');
          final baseName = lastDotIndex != -1
              ? fileName.substring(0, lastDotIndex)
              : fileName;
          lrcPath =
              libraryState.lyricsFolderPath! +
              Platform.pathSeparator +
              baseName +
              '.lrc';
          file = File(lrcPath);
        }
      }

      if (await file.exists()) {
        final content = await file.readAsString();
        final parsedLyrics = _parseLrc(content);
        state = state.copyWith(lyrics: parsedLyrics, isLoading: false);
      } else {
        // No lyrics found
        state = state.copyWith(lyrics: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
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
