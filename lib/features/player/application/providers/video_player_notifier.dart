import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'active_media_focus_provider.dart';
import 'audio_provider.dart';
import '../services/windows_system_media_service.dart';
import '../../../library/data/models/media_item.dart';
import '../../../../core/data/services/data_usage_service.dart';

enum VideoPlayerViewType { mini, full, fullscreen, none }

class VideoState {
  final MediaItem? currentVideo;
  final bool isPlaying;
  final bool isFullscreen;
  final bool isMiniPlayerActive;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final double volume; // 0.0 to 1.0
  final String? error;
  final List<VideoTrack> availableVideoTracks;
  final VideoTrack? selectedVideoTrack;
  final Map<String, String>? currentHeaders;
  final VideoPlayerViewType activeViewType;

  VideoState({
    this.currentVideo,
    this.isPlaying = false,
    this.isFullscreen = false,
    this.isMiniPlayerActive = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.volume = 1.0,
    this.error,
    this.availableVideoTracks = const [],
    this.selectedVideoTrack,
    this.currentHeaders,
    this.activeViewType = VideoPlayerViewType.none,
  });

  VideoState copyWith({
    MediaItem? currentVideo,
    bool? isPlaying,
    bool? isFullscreen,
    bool? isMiniPlayerActive,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    double? volume,
    String? error,
    List<VideoTrack>? availableVideoTracks,
    VideoTrack? selectedVideoTrack,
    Map<String, String>? currentHeaders,
    VideoPlayerViewType? activeViewType,
  }) {
    return VideoState(
      currentVideo: currentVideo ?? this.currentVideo,
      isPlaying: isPlaying ?? this.isPlaying,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isMiniPlayerActive: isMiniPlayerActive ?? this.isMiniPlayerActive,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      volume: volume ?? this.volume,
      error: error,
      availableVideoTracks: availableVideoTracks ?? this.availableVideoTracks,
      selectedVideoTrack: selectedVideoTrack ?? this.selectedVideoTrack,
      currentHeaders: currentHeaders ?? this.currentHeaders,
      activeViewType: activeViewType ?? this.activeViewType,
    );
  }

  List<VideoTrack> get uniqueVideoTracks {
    final seen = <String>{};
    final unique = <VideoTrack>[];
    
    // Always put 'Auto' (id: 'auto' or similar, but media_kit uses null/empty for auto sometimes)
    // Actually media_kit's [VideoTrack.auto] is a static constant.
    
    for (final track in availableVideoTracks) {
      // Create a unique key based on what we display: title or height
      final label = track.title ?? (track.h != null && track.h! > 0 ? '${track.h}p' : 'Auto');
      if (!seen.contains(label)) {
        seen.add(label);
        unique.add(track);
      }
    }
    
    // Ensure Auto is first if present
    unique.sort((a, b) {
      final aIsAuto = a.title == null && (a.h == null || a.h == 0);
      final bIsAuto = b.title == null && (b.h == null || b.h == 0);
      if (aIsAuto) return -1;
      if (bIsAuto) return 1;
      // Sort resolutions descending
      return (b.h ?? 0).compareTo(a.h ?? 0);
    });

    return unique;
  }
}

class VideoPlayerNotifier extends Notifier<VideoState> {
  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription> _subscriptions = [];
  late WindowsSystemMediaService _windowsService;
  late DataUsageService _dataUsageService;
  Timer? _usageTimer;
  int _lastBytesRead = 0;

  Player? get player => _player;
  VideoController? get controller => _controller;

  @override
  VideoState build() {
    _windowsService = ref.read(windowsSystemMediaServiceProvider);
    _dataUsageService = ref.read(dataUsageServiceProvider);

    ref.onDispose(() {
      _stopUsageTimer();
      _disposePlayer();
    });
    return VideoState();
  }

  void _initPlayer() {
    if (_player != null) return;
    
    _player = Player();
    _controller = VideoController(_player!);
    
    _subscriptions.addAll([
      _player!.stream.playing.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
      _player!.stream.position.listen((pos) {
        state = state.copyWith(position: pos);
      }),
      _player!.stream.duration.listen((dur) {
        state = state.copyWith(duration: dur);
      }),
      _player!.stream.buffering.listen((buffering) {
        state = state.copyWith(isBuffering: buffering);
      }),
      _player!.stream.volume.listen((vol) {
        state = state.copyWith(volume: vol / 100.0);
      }),
      _player!.stream.error.listen((error) {
        debugPrint('MediaKit Video Error: $error');
        state = state.copyWith(error: error, isPlaying: false, isBuffering: false);
      }),
      _player!.stream.completed.listen((completed) {
        if (completed) {
          closeVideo();
        }
      }),
      _player!.stream.tracks.listen((tracks) {
        state = state.copyWith(
          availableVideoTracks: tracks.video,
        );
      }),
      _player!.stream.track.listen((track) {
        state = state.copyWith(
          selectedVideoTrack: track.video,
        );
      }),
      _player!.stream.playing.listen((playing) async {
        final focus = ref.read(mediaFocusProvider);
        if (focus == MediaFocus.video) {
          await _windowsService.updatePlaybackStatus(playing);
        }
      }),
      _player!.stream.position.listen((pos) async {
        final focus = ref.read(mediaFocusProvider);
        if (focus == MediaFocus.video) {
          await _windowsService.updateTimeline(pos, state.duration);
        }
      }),
    ]);
    
    _startUsageTimer();
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    _lastBytesRead = 0;
    _usageTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_player == null || !state.isPlaying) return;
      
      try {
        // media_kit's getProperty returns the raw value from mpv
        // It resides on the platform implementation
        final bytes = await (_player!.platform as dynamic).getProperty('bytes-read');
        if (bytes != null && (bytes is int || bytes is double)) {
          final intBytes = bytes.toInt();
          final delta = intBytes - _lastBytesRead;
          if (delta > 0) {
            _dataUsageService.addBytes(delta);
            _lastBytesRead = intBytes;
          }
        }
      } catch (e) {
        // Silently ignore if property isn't available yet or fails
      }
    });
  }

  void _stopUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  void _disposePlayer() {
    _stopUsageTimer();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
    _controller = null;
  }

  Future<void> playVideo(MediaItem item, {Map<String, String>? headers}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      debugPrint('Video playback is not supported on mobile.');
      return;
    }
    final effectiveHeaders = _getEffectiveHeaders(headers);

    // 1. Pause & Clear Audio (exclusive session)
    ref.read(audioProvider.notifier).stopAndClear();
    
    // 2. Set Focus
    ref.read(mediaFocusProvider.notifier).setVideoFocus();

    // 3. Init Player if needed
    _initPlayer();

    // 4. Open Video
    debugPrint('VideoPlayer: Opening ${item.path}');
    state = state.copyWith(
      currentVideo: item, 
      isPlaying: true, 
      isMiniPlayerActive: true, 
      error: null,
      currentHeaders: effectiveHeaders,
      activeViewType: VideoPlayerViewType.mini,
    );
    
    try {
      await _player?.open(
        Media(
          item.path,
          httpHeaders: effectiveHeaders,
        ),
        play: true,
      );
      
      // Update SMTC after successful open
      await _windowsService.updateMetadata(item, true);
      _windowsService.setCallbacks(
        onPlay: () => play(),
        onPause: () => pause(),
        onNext: () {}, // No next/prev for single video yet
        onPrevious: () {},
        onStop: () => closeVideo(),
      );
    } catch (e) {
      debugPrint('VideoPlayer: Exception during open: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void play() {
    _player?.play();
  }

  void pause() {
    _player?.pause();
  }

  void togglePlayPause() {
    _player?.playOrPause();
  }

  void closeVideo() {
    _player?.pause();
    state = VideoState(); // Reset state
    _disposePlayer();
    ref.read(mediaFocusProvider.notifier).setAudioFocus();
  }

  void seek(Duration position) {
    _player?.seek(position);
  }

  void jump(Duration offset) {
    if (_player == null) return;
    final newPosition = _player!.state.position + offset;
    final duration = _player!.state.duration;
    
    if (newPosition < Duration.zero) {
      _player!.seek(Duration.zero);
    } else if (newPosition > duration) {
      _player!.seek(duration);
    } else {
      _player!.seek(newPosition);
    }
  }

  void setVolume(double value) {
    _player?.setVolume(value * 100.0);
    state = state.copyWith(volume: value);
  }

  void setFullscreen(bool value) {
    state = state.copyWith(isFullscreen: value);
  }
  
  void setMiniPlayerActive(bool value) {
    state = state.copyWith(isMiniPlayerActive: value);
  }

  void setVideoTrack(VideoTrack track) {
    _player?.setVideoTrack(track);
    // Persist selection in state immediately for UI responsiveness
    state = state.copyWith(selectedVideoTrack: track);
  }

  void setActiveViewType(VideoPlayerViewType type) {
    state = state.copyWith(
      activeViewType: type,
      isFullscreen: type == VideoPlayerViewType.fullscreen,
    );
  }

  /// Special Fix: Reload URL if track selection fails or for specific sources
  Future<void> reloadWithHeaders() async {
    final currentVideo = state.currentVideo;
    final headers = state.currentHeaders;
    if (currentVideo == null) return;

    final currentPos = state.position;
    await _player?.open(
      Media(
        currentVideo.path,
        httpHeaders: headers,
      ),
      play: true,
    );
    await _player?.seek(currentPos);
  }

  Map<String, String> _getEffectiveHeaders(Map<String, String>? customHeaders) {
    final headers = Map<String, String>.from(customHeaders ?? {});
    
    // Default User-Agent if not provided
    if (!headers.containsKey('User-Agent')) {
      headers['User-Agent'] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    }

    // Standard browser headers to improve compatibility with strict sources
    headers.putIfAbsent('Accept', () => '*/*');
    headers.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    headers.putIfAbsent('Connection', () => 'keep-alive');
    headers.putIfAbsent('Sec-Fetch-Dest', () => 'video');
    headers.putIfAbsent('Sec-Fetch-Mode', () => 'cors');
    headers.putIfAbsent('Sec-Fetch-Site', () => 'cross-site');
    
    return headers;
  }
}

final videoPlayerProvider = NotifierProvider<VideoPlayerNotifier, VideoState>(() {
  return VideoPlayerNotifier();
});
