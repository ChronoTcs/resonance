import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../explore/data/services/youtube_service.dart';


class CachedStreamInfo {
  final String url;
  final DateTime fetchedAt;
  CachedStreamInfo(this.url, this.fetchedAt);

  bool get isExpired => 
    DateTime.now().difference(fetchedAt).inHours >= 2;
}

final playbackArchitectureServiceProvider = Provider<PlaybackArchitectureService>((ref) {
  final youtube = ref.watch(youtubeServiceProvider);
  return PlaybackArchitectureService(youtube);
});

class PlaybackArchitectureService {
  final YoutubeService _youtube;

  PlaybackArchitectureService(this._youtube);

  // In-memory cache for audio URLs
  final Map<String, CachedStreamInfo> _urlCache = {};
  
  // Track active fetches to prevent race conditions
  final Set<String> _activeFetches = {};

  // Track the current prefetch session ID to cancel older ones
  int _prefetchSessionId = 0;

  /// Gets the stream URL for a video ID.
  /// Uses cache first, then calls YoutubeExplode.
  Future<String?> getStreamUrl(String videoId, {bool forceRefresh = false}) async {
    // 0. Safety Guard: If it looks like a local path, don't even try
    if (videoId.contains('/') || videoId.contains('\\') || (videoId.contains(':') && videoId.length > 2)) {
      return null;
    }

    // 1. Check Cache
    if (!forceRefresh && _urlCache.containsKey(videoId)) {
      final cached = _urlCache[videoId]!;
      if (!cached.isExpired) {
        return cached.url;
      }
      _urlCache.remove(videoId);
    }

    // 2. Prevent Race Condition
    if (_activeFetches.contains(videoId)) {
      int retries = 0;
      while (_activeFetches.contains(videoId) && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }
      if (_urlCache.containsKey(videoId)) {
        return _urlCache[videoId]!.url;
      }
    }

    _activeFetches.add(videoId);

    try {
      // 3. Fetch from YoutubeExplode
      final String? url = await _youtube.getStreamUrl(videoId);

      if (url != null) {
        _urlCache[videoId] = CachedStreamInfo(url, DateTime.now());
        return url;
      }
      return null;
    } finally {
      _activeFetches.remove(videoId);
    }
  }

  /// Proactively fetches URLs for a list of video IDs (e.g. next 3 tracks).
  /// Hanya melakukan URL pre-warm (tidak mendownload full byte) agar hemat kuota.
  void predictiveFetch(List<String> videoIds) {
    if (videoIds.isEmpty) return;

    // Tingkatkan Session ID setiap kali fungsi dipanggil untuk membatalkan antrean lama
    _prefetchSessionId++;
    final currentSession = _prefetchSessionId;

    final toFetch = videoIds.take(3).toList();
    
    Future.microtask(() async {
      for (int i = 0; i < toFetch.length; i++) {
        // BATALKAN jika ada pencarian/perintah prefetch baru yang masuk
        if (_prefetchSessionId != currentSession) return;

        final id = toFetch[i];
        
        if (!_urlCache.containsKey(id) && !_activeFetches.contains(id)) {
          if (i > 0) {
            final jitter = (i * 1200) + (id.hashCode % 1500);
            await Future.delayed(Duration(milliseconds: jitter));
          }
          
          // Cek lagi setelah delay, siapa tahu sesi sudah berubah
          if (_prefetchSessionId != currentSession) return;
          
          // HANYA ambil URL (Pre-warm), JANGAN panggil getAudioPath yang akan mendownload full file
          final url = await getStreamUrl(id);
          if (url != null) {
            // URL sudah masuk ke _urlCache secara otomatis oleh getStreamUrl.
            // Kita tidak memanggil cacheService.getAudioPath agar kuota internet user aman.
            print('URL Pre-warmed for ID: $id');
          }
        }
      }
    });
  }

  void clearCache() {
    _urlCache.clear();
    _activeFetches.clear();
  }
}
