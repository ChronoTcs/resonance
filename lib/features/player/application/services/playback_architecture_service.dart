import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../explore/data/repositories/youtube_stream_repository.dart';
import '../../../library/application/library_provider.dart';
import '../../../../core/data/services/media_cache_service.dart';


class CachedStreamInfo {
  final String url;
  final DateTime fetchedAt;
  CachedStreamInfo(this.url, this.fetchedAt);

  bool get isExpired => 
    DateTime.now().difference(fetchedAt).inHours >= 2;
}

final playbackArchitectureServiceProvider = Provider<PlaybackArchitectureService>((ref) {
  final youtubeRepo = ref.watch(youtubeStreamRepositoryProvider);
  return PlaybackArchitectureService(youtubeRepo, ref);
});

class PlaybackArchitectureService {
  final YoutubeStreamRepository _repository;
  final Ref _ref;

  PlaybackArchitectureService(this._repository, this._ref);

  // In-memory cache for audio URLs
  final Map<String, CachedStreamInfo> _urlCache = {};
  
  // [V20.16 SOTA Patch] Atomic Request Map (Future tracking)
  // Ensures only 1 network request is ever active for a specific ID.
  final Map<String, Future<String?>> _activeRequests = {};

  // Prefetch Debouncer (15s to prevent Bot Detection)
  Timer? _prefetchTimer;

  // Track the current prefetch session ID to cancel older ones
  int _prefetchSessionId = 0;

  /// Gets the stream URL for a video ID.
  /// Uses cache first, then calls the repository with atomic synchronization.
  Future<String?> getStreamUrl(String videoId, {bool forceRefresh = false}) async {
    // 0. MANDATORY CACHE-FIRST: Cek file lokal sebelum internet
    final localPath = await _checkLocalFile(videoId);
    if (localPath != null) {
      debugPrint('RateLimit Defender: Local Cache Hit for $videoId');
      return localPath;
    }

    // 0.5 Safety Guard: If it looks like a local path, don't even try
    if (videoId.contains('/') || videoId.contains('\\') || (videoId.contains(':') && videoId.length > 2)) {
      return null;
    }

    // 1. Check Memory Cache
    if (!forceRefresh && _urlCache.containsKey(videoId)) {
      final cached = _urlCache[videoId]!;
      if (!cached.isExpired) {
        return cached.url;
      }
      _urlCache.remove(videoId);
    }

    // 2. [V20.16 SOTA] Atomic Concurrency Control
    // If there is an active request (prefetch or user action), join it.
    final existingRequest = _activeRequests[videoId];
    if (existingRequest != null) {
      debugPrint('RateLimit Defender: Joining existing active request for $videoId');
      return existingRequest;
    }

    // 3. Initiate New Atomic Request
    final requestFuture = _performFetch(videoId);
    _activeRequests[videoId] = requestFuture;
    
    try {
      return await requestFuture;
    } finally {
      _activeRequests.remove(videoId);
    }
  }

  Future<String?> _performFetch(String videoId) async {
    try {
      // 3. Fetch from specialized repository (SOTA Deciphering)
      final String? url = await _repository.getStreamUrl(videoId);

      if (url != null) {
        _urlCache[videoId] = CachedStreamInfo(url, DateTime.now());
        return url;
      }
      return null;
    } catch (e) {
      debugPrint('RateLimit Defender: Fetch ERROR for $videoId: $e');
      return null;
    }
  }

  Future<String?> _checkLocalFile(String videoId) async {
    try {
      // 1. Cek folder permanent (music)
      final libraryState = _ref.read(libraryProvider);
      if (libraryState.musicFolderPath != null) {
        final dir = Directory(libraryState.musicFolderPath!);
        if (await dir.exists()) {
          final files = dir.listSync();
          for (var f in files) {
            if (f is File && f.path.contains(videoId)) {
              if (f.existsSync()) {
                debugPrint('PlaybackArchitecture: Physical file found for $videoId at ${f.path}');
                return f.path;
              }
            }
          }
        }
      }

      // 2. Cek folder stream cache (m4a)
      final cacheService = _ref.read(mediaCacheServiceProvider);
      final cachePath = await cacheService.getCachedAudioPath(videoId);
      if (cachePath != null) return cachePath;
    } catch (_) {}
    return null;
  }

  /// Proactively fetches URLs for a list of video IDs (e.g. next 3 tracks).
  /// Hanya melakukan URL pre-warm (tidak mendownload full byte) agar hemat kuota.
  void predictiveFetch(List<String> videoIds) {
    // 1. BATALKAN penjadwalan sebelumnya segera
    _prefetchTimer?.cancel();

    if (videoIds.isEmpty) return;

    // 2. Tingkatkan Session ID untuk mengabaikan fetch yang sedang 'terbang' (jika ada)
    _prefetchSessionId++;
    final currentSession = _prefetchSessionId;

    // 3. Hanya ambil 1 lagu berikutnya
    final nextId = videoIds.first;
    
    // 4. DEBOUNCE WAJIB 15 DETIK: 
    // Jika user pindah sebelum 15 detik, timer dibatalkan dan 
    // network request getStreamUrl TIDAK PERNAH dikirim.
    debugPrint('RateLimit Defender: Scheduling prefetch for $nextId in 15 seconds...');
    _prefetchTimer = Timer(const Duration(seconds: 15), () async {
      // Cek apakah sesi masih valid setelah 15 detik (User tidak skip lagu)
      if (_prefetchSessionId != currentSession) {
        debugPrint('RateLimit Defender: Aborted ghost prefetch for SESSION $currentSession');
        return;
      }
      
      if (!_urlCache.containsKey(nextId) && !_activeRequests.containsKey(nextId)) {
        // Cek file lokal dulu (tanpa internet)
        final localPath = await _checkLocalFile(nextId);
        if (localPath != null) {
          _urlCache[nextId] = CachedStreamInfo(localPath, DateTime.now());
          debugPrint('RateLimit Defender: Next track found in local. No internet request needed.');
          return;
        }

        // Jika tidak ada di lokal, baru jemput URL (Request Jaringan)
        debugPrint('RateLimit Defender: [NETWORK] Prefetching next track URL from YouTube for SESSION $currentSession...');
        final url = await getStreamUrl(nextId);
        if (url != null) {
          debugPrint('RateLimit Defender: URL Pre-warmed for ID: $nextId');
        }
      }
    });
  }

  void clearCache() {
    _prefetchTimer?.cancel();
    _urlCache.clear();
    _activeRequests.clear();
  }
}
