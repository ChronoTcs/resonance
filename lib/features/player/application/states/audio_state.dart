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
  final bool isPlaylistMode;
  final String? activePlaylistId;

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
    this.isPlaylistMode = false,
    this.activePlaylistId,
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
    bool? isPlaylistMode,
    String? activePlaylistId,
    bool clearCurrentTrack = false,
    bool clearNextTrack = false,
    bool clearActivePlaylistId = false,
  }) {
    return AudioState(
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
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
      nextTrack: clearNextTrack ? null : (nextTrack ?? this.nextTrack),
      isLoading: isLoading ?? this.isLoading,
      isPlaylistMode: isPlaylistMode ?? this.isPlaylistMode,
      activePlaylistId: clearActivePlaylistId
          ? null
          : (activePlaylistId ?? this.activePlaylistId),
    );
  }
}
