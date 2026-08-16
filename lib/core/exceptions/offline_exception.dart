/// Thrown when a network operation is attempted while the device is offline
/// and no local/cached fallback is available.
class OfflinePlaybackException implements Exception {
  final String message;
  const OfflinePlaybackException([this.message = 'Device is offline and no cached audio is available.']);

  @override
  String toString() => 'OfflinePlaybackException: $message';
}
