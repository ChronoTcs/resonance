import 'stream_resolution_result.dart';

/// Transient session object that lives ONLY during active playback of one track.
/// Disposed when the next track starts or playback stops.
/// INVARIANT: MediaItem.path is NEVER set to PlaybackSession.streamUrl.
class PlaybackSession {
  final String videoId; // canonical ID (always clean)
  final String? localFilePath; // non-null if served from disk cache
  final StreamResolutionResult? resolved; // non-null if served from network

  const PlaybackSession({
    required this.videoId,
    this.localFilePath,
    this.resolved,
  });

  /// The final URI to feed the audio player
  String get uri => localFilePath ?? resolved!.streamUrl;

  /// Is this session served entirely from disk?
  bool get isLocal => localFilePath != null;

  Map<String, String> get headers =>
      isLocal ? const {} : (resolved?.playbackHeaders ?? const {});
}
