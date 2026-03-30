import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/data_usage_service.dart';

class ExplorePlaylist {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int videoCount;

  const ExplorePlaylist({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.videoCount,
  });

  factory ExplorePlaylist.fromPlaylist(Playlist playlist) {
    String thumb = playlist.thumbnails.highResUrl;
    if (playlist.thumbnails.maxResUrl.isNotEmpty) thumb = playlist.thumbnails.maxResUrl;
    else if (playlist.thumbnails.standardResUrl.isNotEmpty) thumb = playlist.thumbnails.standardResUrl;
    else if (playlist.thumbnails.highResUrl.isNotEmpty) thumb = playlist.thumbnails.highResUrl;
    else if (playlist.thumbnails.mediumResUrl.isNotEmpty) thumb = playlist.thumbnails.mediumResUrl;

    return ExplorePlaylist(
      id: playlist.id.value,
      title: playlist.title,
      author: playlist.author,
      thumbnailUrl: thumb,
      videoCount: playlist.videoCount ?? 0,
    );
  }
}

class ExploreItem {
  final String id;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;
  final String url;
  final Video? originalVideo; // Reusable metadata

  const ExploreItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.url,
    this.originalVideo,
  });

  factory ExploreItem.fromVideo(Video video) {
    String thumb = video.thumbnails.highResUrl;
    if (video.thumbnails.maxResUrl.isNotEmpty) thumb = video.thumbnails.maxResUrl;
    else if (video.thumbnails.standardResUrl.isNotEmpty) thumb = video.thumbnails.standardResUrl;
    else if (video.thumbnails.highResUrl.isNotEmpty) thumb = video.thumbnails.highResUrl;
    else if (video.thumbnails.mediumResUrl.isNotEmpty) thumb = video.thumbnails.mediumResUrl;

    return ExploreItem(
      id: video.id.value,
      title: video.title,
      author: video.author,
      duration: video.duration?.toString().split('.').first ?? '00:00',
      thumbnailUrl: thumb,
      url: video.url,
      originalVideo: video,
    );
  }
}

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  final DataUsageService? _dataUsageService;

  YoutubeService([this._dataUsageService]);

  Future<List<ExploreItem>> search(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      
      // If user is intentionally searching for "live", "cover", or "audio", use original query.
      // Otherwise, append "official audio" to favor high-quality studio versions (YouTube Music data).
      final optimizedQuery = (lowerQuery.contains('audio') || 
                              lowerQuery.contains('live') || 
                              lowerQuery.contains('cover')) 
          ? query 
          : '$query official audio';
      
      final searchList = await _yt.search.search(optimizedQuery);
      
      // Track metadata usage (est. 10KB for 20 results)
      _dataUsageService?.addBytes(1024 * 10);
      
      return searchList.map((video) => ExploreItem.fromVideo(video)).toList();
    } catch (e) {
      print('YouTube Search Error: $e');
      return [];
    }
  }

  Future<List<ExploreItem>> getFeaturedMusic() async {
    try {
      // Use a more reliable trending music query
      const query = 'trending official music audio';
      print('DEBUG: Fetching featured music with query: $query');
      
      final results = await search(query);
      print('DEBUG: Search returned ${results.length} results');
      
      // Filter out long videos (> 10 mins)
      final filteredHits = results.where((item) {
        // Duration format from ExploreItem: HH:MM:SS or MM:SS
        final parts = item.duration.split(':');
        
        int totalMinutes = 0;
        if (parts.length == 3) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final mins = int.tryParse(parts[1]) ?? 0;
          totalMinutes = (hours * 60) + mins;
        } else if (parts.length == 2) {
          totalMinutes = int.tryParse(parts[0]) ?? 0;
        }
        
        if (totalMinutes > 10 || totalMinutes == 0) {
          print('DEBUG: Rejecting "${item.title}" - duration: ${item.duration}');
          return false;
        }

        return true; 
      }).toList();

      print('DEBUG: ${filteredHits.length} results passed filter');
      return filteredHits.take(15).toList();
    } catch (e) {
      print('YouTube Featured Music Error: $e');
      return [];
    }
  }

  Future<List<ExplorePlaylist>> searchPlaylists(String query) async {
    try {
      final searchList = await _yt.search.searchContent(query, filter: TypeFilters.playlist);
      final playlists = <ExplorePlaylist>[];
      
      for (final result in searchList) {
        if (result is SearchPlaylist) {
          // Fetch full playlist metadata to get reliable thumbnails and info
          final playlist = await _yt.playlists.get(result.playlistId);
          playlists.add(ExplorePlaylist.fromPlaylist(playlist));
        }
      }
      // Track metadata usage (est. 15KB for playlist search + get calls)
      _dataUsageService?.addBytes(1024 * 15);

      return playlists.take(10).toList();
    } catch (e) {
      print('YouTube Playlist Search Error: $e');
      return [];
    }
  }

  Future<List<ExploreItem>> getPlaylistVideos(String playlistId) async {
    try {
      final videos = await _yt.playlists.getVideos(PlaylistId(playlistId)).toList();
      return videos.map((v) => ExploreItem.fromVideo(v)).toList();
    } catch (e) {
      print('YouTube Playlist Videos Error: $e');
      return [];
    }
  }

  Future<String?> getStreamUrl(String videoId) => getAudioStreamUrl(videoId);

  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      // final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.ios],
      );
      final audioStreams = manifest.audioOnly;
      
      // Prefer M4A (mp4) container which is significantly more stable for Windows native playback
      // compared to WebM (Opus) streams that can hang the demuxer over HTTP.
      final mp4Streams = audioStreams.where((e) => e.container.name.toLowerCase() == 'mp4' || e.container.name.toLowerCase() == 'm4a');
      
      final audioInfo = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : audioStreams.withHighestBitrate();
          
      // Track metadata usage (est. 3KB for extraction)
      _dataUsageService?.addBytes(1024 * 3);

      return audioInfo.url.toString();
    } catch (e) {
      print('YouTube Stream Extraction Error: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}

final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final dataUsageService = ref.watch(dataUsageServiceProvider);
  final service = YoutubeService(dataUsageService);
  ref.onDispose(() => service.dispose());
  return service;
});
