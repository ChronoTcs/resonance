import '../models/stream_resolution_result.dart';

/// Contract every platform stream resolver must fulfill.
/// No Platform.isX allowed inside any implementation of this interface.
/// The [platformStreamResolverProvider] factory is the ONLY allowed place
/// that branches on Platform.isX to select an implementation.
abstract interface class IPlatformStreamResolver {
  /// Identifier for this resolver (e.g. 'windows', 'android').
  String get platformName;

  /// The canonical User-Agent this resolver's streams are signed for.
  /// Single source of truth — no UA strings anywhere else in the stream layer.
  String get userAgent;

  /// Resolves a playable network stream for [videoId].
  /// Throws if resolution fails on all available engines.
  Future<StreamResolutionResult> resolveStream(String videoId);

  /// Returns the full HTTP headers required to play or cache [streamUrl].
  /// Callers must use these headers for both playback and background caching.
  Map<String, String> getPlaybackHeaders(String streamUrl);
}
