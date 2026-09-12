import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/exceptions/offline_exception.dart';
import '../services/youtube_innertube_client.dart';
import '../../application/services/youtube_auth_service.dart';
import '../../../stream/application/platform_stream_provider.dart';

final youtubeStreamRepositoryProvider = Provider<YoutubeStreamRepository>((
  ref,
) {
  final client = ref.watch(youtubeInnerTubeClientProvider);
  final cacheService = ref.watch(mediaCacheServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  final repo = YoutubeStreamRepository(ref, client, cacheService, prefs);
  ref.onDispose(() => repo.dispose());
  // Warm-up visitorData on both Android and Windows at boot to eliminate cold-start lag
  if (Platform.isAndroid || Platform.isWindows) repo.warmUpSession();
  return repo;
});

enum YoutubeEngine { explodeDart, innerTube }

class YoutubeStreamRepository {
  final Ref _ref;
  final YoutubeInnerTubeClient _client;
  final MediaCacheService _cacheService;

  YoutubeStreamRepository(
    this._ref,
    this._client,
    this._cacheService, [
    SharedPreferences? prefs,
  ]);

  /// Resolves the final playable audio URL with Cache-First strategy
  Future<String?> getStreamUrl(String videoId) async {
    // [GUARDRAIL 2] MANDATORY CACHE-FIRST
    try {
      final cachedPath = await _cacheService.getCachedAudioPath(videoId);
      if (cachedPath != null) {
        debugPrint(
          '[YoutubeStreamRepo][CACHE HIT] Using local file for $videoId',
        );
        return cachedPath;
      }
    } catch (e) {
      debugPrint('[YoutubeStreamRepo] Cache check error: $e');
    }

    // [OFFLINE GUARD] No cache hit — abort immediately if device is offline
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      debugPrint(
        '[YoutubeStreamRepo] Offline — skipping stream resolution for $videoId',
      );
      throw const OfflinePlaybackException();
    }

    // ── Delegate to Platform Stream Resolver (Platform Strategy Pattern) ──
    try {
      final resolver = _ref.read(platformStreamResolverProvider);
      final resolution = await resolver.resolveStream(videoId);
      return await _cacheService.getAudioPath(
        videoId,
        resolution.streamUrl,
        headers: resolution.playbackHeaders,
      );
    } catch (e) {
      debugPrint(
        '[YoutubeStreamRepo] Platform resolver failed for $videoId: $e',
      );
    }

    return null;
  }

  /// [Android Cold-Start Warm-Up] Fires background initialization for STS and visitorData
  /// so tokens and visitor session are fresh before the user plays songs.
  Future<void> warmUpSession() async {
    // Refresh STS in background
    unawaited(_ref.read(youtubeAuthServiceProvider).refreshSignatureTimestamp());

    // Skip visitorData if already cached from a previous session
    if (_ref.read(youtubeAuthServiceProvider).visitorData != null) return;
    try {
      debugPrint(
        '[YoutubeStreamRepo][WARM-UP] Fetching real visitorData from YouTube...',
      );
      final data = await _client.post(
        'browse',
        <String, dynamic>{'browseId': 'FEmusic_home'},
        profile: YoutubeClientProfile.webRemix,
        useAuth: false,
      );
      final String? vd = data['responseContext']?['visitorData'] as String?;
      if (vd != null && vd.isNotEmpty) {
        await _ref.read(youtubeAuthServiceProvider).cacheVisitorData(vd);
        debugPrint(
          '[YoutubeStreamRepo][WARM-UP] visitorData cached: ${vd.substring(0, 10)}...',
        );
      }
    } catch (e) {
      debugPrint('[YoutubeStreamRepo][WARM-UP] Failed (non-critical): $e');
    }
  }

  void dispose() {}
}
