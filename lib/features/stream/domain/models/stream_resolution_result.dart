/// Encapsulates a successfully resolved audio stream — immutable value object.
///
/// INVARIANT: This is NEVER stored in [MediaItem.path] or any persistent state.
/// It is a transient resolution result consumed immediately by the player.
class StreamResolutionResult {
  final String streamUrl;
  final Map<String, String> playbackHeaders;
  final DateTime expiresAt;

  const StreamResolutionResult({
    required this.streamUrl,
    required this.playbackHeaders,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
