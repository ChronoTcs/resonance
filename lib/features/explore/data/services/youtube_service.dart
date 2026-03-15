import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
    return ExplorePlaylist(
      id: playlist.id.value,
      title: playlist.title,
      author: playlist.author,
      thumbnailUrl: playlist.thumbnails.highResUrl,
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

  const ExploreItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.url,
  });

  factory ExploreItem.fromVideo(Video video) {
    return ExploreItem(
      id: video.id.value,
      title: video.title,
      author: video.author,
      duration: video.duration?.toString().split('.').first ?? '00:00',
      thumbnailUrl: video.thumbnails.highResUrl,
      url: video.url,
    );
  }
}

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

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
      
      return searchList.map((video) => ExploreItem.fromVideo(video)).toList();
    } catch (e) {
      print('YouTube Search Error: $e');
      return [];
    }
  }

  Future<List<ExploreItem>> getFeaturedPlaylists() async {
    try {
      // Fallback: Fetch highly popular music videos and treat them as "featured" items
      final results = await search('global top music hits 2024');
      return results.take(10).toList();
    } catch (e) {
      print('YouTube Featured Playlists Error: $e');
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
