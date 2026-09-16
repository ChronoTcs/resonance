import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_stream_repository.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_auto_cache_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/stream/application/platform_stream_provider.dart';

class _PendingCacheItem {
  final MediaItem track;
  final String? playlistId;

  _PendingCacheItem({required this.track, this.playlistId});
}

/// Idle-only background worker that auto-caches streaming tracks for playlists.
///
/// Guarantees:
/// 1. Playback Priority: strictly pauses when player is active (isPlaying or isLoading).
/// 2. Sequential Throttling: processes 1 track at a time with 2-second rate-limit cooldown.
/// 3. Per-Playlist Policy: batch imports and feed saves only cache if auto-cache is enabled for that playlist.
/// 4. Explicit Single Additions: single song additions auto-enqueue and download during idle.
class PlaylistStreamCacheHandler {
  final Ref _ref;
  static const _kPendingQueueKey = 'pending_playlist_cache_queue_v1';

  final List<_PendingCacheItem> _memoryQueue = [];
  bool _isWorkerRunning = false;
  bool _isPlaybackActive = false;
  bool _isProcessingOfflineQueue = false;
  Timer? _idleDebounceTimer;

  PlaylistStreamCacheHandler(this._ref) {
    _initListeners();
  }

  void _initListeners() {
    final audioState = _ref.read(audioProvider);
    _isPlaybackActive = audioState.isPlaying || audioState.isLoading;

    _ref.listen<bool>(
      audioProvider.select((s) => s.isPlaying || s.isLoading),
      (previous, isBusy) {
        _isPlaybackActive = isBusy;
        if (isBusy) {
          _idleDebounceTimer?.cancel();
          debugPrint('[PlaylistStreamCacheHandler] Playback busy. Background cache paused.');
        } else {
          _scheduleIdleWorker();
        }
      },
    );

    // Re-evaluate queue when track changes (e.g. active track skipped or finished)
    _ref.listen<String?>(
      audioProvider.select((s) => s.currentTrack?.id ?? s.currentTrack?.path),
      (previous, currentId) {
        if (!_isPlaybackActive) {
          _scheduleIdleWorker();
        }
      },
    );
  }

  void dispose() {
    _idleDebounceTimer?.cancel();
    _memoryQueue.clear();
  }

  /// Enqueue tracks to be cached.
  /// If [isExplicitSingle] is true (e.g. user added 1 track), enqueues for idle caching directly.
  /// If batch addition, checks if [playlistId] has auto-cache enabled.
  Future<void> enqueueTracks(
    List<MediaItem> tracks, {
    String? playlistId,
    bool isExplicitSingle = false,
  }) async {
    final streamTracks = tracks.where((t) => t.isStreaming).toList();
    if (streamTracks.isEmpty) return;

    // Batch policy check: only cache batch additions if playlist has auto-cache enabled
    if (!isExplicitSingle) {
      if (playlistId == null) return;
      final autoCacheEnabled = _ref.read(playlistAutoCacheProvider).contains(playlistId);
      if (!autoCacheEnabled) {
        debugPrint(
          '[PlaylistStreamCacheHandler] Skipping batch caching for playlist $playlistId (auto-cache disabled).',
        );
        return;
      }
    }

    final cacheService = _ref.read(mediaCacheServiceProvider);
    final List<MediaItem> uncached = [];

    for (final track in streamTracks) {
      final id = track.id ?? track.path;
      if (id.isEmpty) continue;
      final cachedPath = await cacheService.getCachedAudioPath(id);
      if (cachedPath == null && !_isAlreadyQueued(id)) {
        uncached.add(track);
      }
    }

    if (uncached.isEmpty) return;

    final isOnline = _ref.read(networkConnectivityProvider).isOnline;
    if (isOnline) {
      for (final track in uncached) {
        _memoryQueue.add(_PendingCacheItem(track: track, playlistId: playlistId));
      }
      debugPrint(
        '[PlaylistStreamCacheHandler] Enqueued ${uncached.length} tracks. Memory queue size: ${_memoryQueue.length}',
      );
      if (!_isPlaybackActive) {
        _scheduleIdleWorker();
      }
    } else {
      await _addToPendingOfflineQueue(uncached);
    }
  }

  /// Manually triggers caching of all uncached tracks in a playlist (e.g. when user enables auto-cache toggle).
  Future<void> cachePlaylistNow(String playlistId) async {
    final playlistsState = _ref.read(playlistProvider);
    final playlist = playlistsState.value?.getById(playlistId);
    if (playlist == null || playlist.tracks.isEmpty) return;

    await enqueueTracks(
      playlist.tracks,
      playlistId: playlistId,
      isExplicitSingle: true, // bypass batch block since user explicitly turned on auto-cache
    );
  }

  /// Removes pending cache tasks for a playlist when user disables auto-cache toggle.
  void cancelPlaylistCache(String playlistId) {
    _memoryQueue.removeWhere((item) => item.playlistId == playlistId);
    if (playlistId.isNotEmpty) {
      _ref.invalidate(playlistUncachedCountProvider(playlistId));
    }
    debugPrint('[PlaylistStreamCacheHandler] Canceled pending cache for playlist $playlistId');
  }

  bool _isAlreadyQueued(String trackId) {
    return _memoryQueue.any((item) => (item.track.id ?? item.track.path) == trackId);
  }

  void _scheduleIdleWorker() {
    _idleDebounceTimer?.cancel();
    _idleDebounceTimer = Timer(const Duration(seconds: 3), () {
      if (!_isPlaybackActive && !_isWorkerRunning && _memoryQueue.isNotEmpty) {
        _processMemoryQueue();
      }
    });
  }

  Future<void> _processMemoryQueue() async {
    if (_isWorkerRunning) return;
    _isWorkerRunning = true;

    try {
      while (_memoryQueue.isNotEmpty) {
        // Strict guard: pause immediately if music starts playing or buffering
        if (_isPlaybackActive) {
          debugPrint('[PlaylistStreamCacheHandler] Worker paused: playback became active.');
          break;
        }

        final isOnline = _ref.read(networkConnectivityProvider).isOnline;
        if (!isOnline) {
          debugPrint('[PlaylistStreamCacheHandler] Worker paused: device offline.');
          break;
        }

        final item = _memoryQueue.removeAt(0);
        final trackId = item.track.id ?? item.track.path;

        // Collision guard: if currently active in player, defer to back of queue so it isn't lost if skipped
        final currentTrack = _ref.read(audioProvider).currentTrack;
        final currentId = currentTrack?.id ?? currentTrack?.path;
        if (currentId != null && currentId == trackId) {
          debugPrint('[PlaylistStreamCacheHandler] Deferring track $trackId — currently active in player');
          _memoryQueue.add(item);
          break;
        }

        final cacheService = _ref.read(mediaCacheServiceProvider);
        final cachedPath = await cacheService.getCachedAudioPath(trackId);
        if (cachedPath == null) {
          await _cacheSingleTrack(item.track);
          if (item.playlistId != null) {
            _ref.invalidate(playlistUncachedCountProvider(item.playlistId!));
          }
          // Rate-limiting delay: 2 seconds cooldown between tracks to protect network and avoid 429
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint('[PlaylistStreamCacheHandler] Worker error: $e');
    } finally {
      _isWorkerRunning = false;
    }
  }

  /// Process pending offline queue when connection is restored.
  Future<void> processPendingQueue() async {
    if (_isProcessingOfflineQueue) return;
    _isProcessingOfflineQueue = true;

    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final raw = prefs.getString(_kPendingQueueKey);
      if (raw == null || raw.isEmpty) {
        _isProcessingOfflineQueue = false;
        return;
      }

      final List<dynamic> jsonList = jsonDecode(raw);
      final pendingTracks = jsonList
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (pendingTracks.isEmpty) {
        _isProcessingOfflineQueue = false;
        return;
      }

      debugPrint('[PlaylistStreamCacheHandler] Migrating ${pendingTracks.length} offline pending tracks to memory queue');
      await prefs.remove(_kPendingQueueKey);

      for (final track in pendingTracks) {
        final id = track.id ?? track.path;
        if (!_isAlreadyQueued(id)) {
          _memoryQueue.add(_PendingCacheItem(track: track));
        }
      }

      if (!_isPlaybackActive) {
        _scheduleIdleWorker();
      }
    } catch (e) {
      debugPrint('[PlaylistStreamCacheHandler] Error processing offline queue: $e');
    } finally {
      _isProcessingOfflineQueue = false;
    }
  }

  Future<void> _cacheSingleTrack(MediaItem track) async {
    final id = track.id ?? track.path;
    if (id.isEmpty) return;

    try {
      final cacheService = _ref.read(mediaCacheServiceProvider);
      // 1. Cache metadata sidecar
      await cacheService.saveMetadata(id, track);

      // 2. Cache artwork thumbnail if available
      if (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty) {
        unawaited(cacheService.cacheArtwork(id, track.thumbnailUrl));
      }

      // 3. Initiate background audio caching via stream resolver
      final streamRepo = _ref.read(youtubeStreamRepositoryProvider);
      final streamUrl = await streamRepo.getStreamUrl(id);
      if (streamUrl != null && streamUrl.startsWith('http')) {
        final resolver = _ref.read(platformStreamResolverProvider);
        await cacheService.getAudioPath(
          id,
          streamUrl,
          headers: resolver.getPlaybackHeaders(streamUrl),
        );
        // Await the active download so batch items are processed strictly sequentially
        final activeFuture = cacheService.getActiveDownload(id);
        if (activeFuture != null) {
          await activeFuture;
        }
      }
      debugPrint('[PlaylistStreamCacheHandler] Successfully cached for $id (${track.title})');
    } catch (e) {
      debugPrint('[PlaylistStreamCacheHandler] Failed to auto-cache track $id: $e');
    }
  }

  Future<void> _addToPendingOfflineQueue(List<MediaItem> tracks) async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final raw = prefs.getString(_kPendingQueueKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        list = jsonDecode(raw) as List<dynamic>;
      }

      final existingIds = list.map((e) => e['id'] as String?).toSet();
      for (final track in tracks) {
        final id = track.id ?? track.path;
        if (!existingIds.contains(id)) {
          list.add(track.toJson());
          existingIds.add(id);
        }
      }

      await prefs.setString(_kPendingQueueKey, jsonEncode(list));
      debugPrint('[PlaylistStreamCacheHandler] Stored ${tracks.length} tracks to pending offline cache queue');
    } catch (e) {
      debugPrint('[PlaylistStreamCacheHandler] Failed to store pending queue: $e');
    }
  }
}

final playlistStreamCacheHandlerProvider = Provider<PlaylistStreamCacheHandler>((ref) {
  final handler = PlaylistStreamCacheHandler(ref);
  ref.onDispose(() => handler.dispose());
  return handler;
});
