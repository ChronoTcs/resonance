import '../../../library/data/models/media_item.dart';
import '../../data/models/player_enums.dart';

/// Immutable state for the audio player.
/// Extracted from audio_provider.dart for separation of concerns.
class AudioState {
  final MediaItem? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final LoopMode loopMode;
  final bool isShuffleEnabled;
  final double volume;
  final double speed;
  final double pitch;
  final List<MediaItem> queue;
  final int currentIndex;
  final MediaItem? nextTrack;
  final bool isLoading;

  AudioState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loopMode = LoopMode.off,
    this.isShuffleEnabled = false,
    this.volume = 100.0,
    this.speed = 1.0,
    this.pitch = 0.0,
    this.queue = const [],
    this.currentIndex = -1,
    this.nextTrack,
    this.isLoading = false,
  });

  AudioState copyWith({
    MediaItem? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? isShuffleEnabled,
    double? volume,
    double? speed,
    double? pitch,
    List<MediaItem>? queue,
    int? currentIndex,
    MediaItem? nextTrack,
    bool? isLoading,
  }) {
    return AudioState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      nextTrack: nextTrack ?? this.nextTrack,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
