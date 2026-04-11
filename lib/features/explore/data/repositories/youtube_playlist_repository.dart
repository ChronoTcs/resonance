import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/explore_item.dart';
import '../models/explore_playlist.dart';
import '../services/youtube_innertube_client.dart';

final youtubePlaylistRepositoryProvider = Provider<YoutubePlaylistRepository>((ref) {
  final client = ref.watch(youtubeInnerTubeClientProvider);
  return YoutubePlaylistRepository(client);
});

class YoutubePlaylistRepository {
  final YoutubeInnerTubeClient _client;

  YoutubePlaylistRepository(this._client);

  Future<List<ExplorePlaylist>> fetchMyPlaylists() async {
    try {
      final data = await _client.post('browse', {"browseId": "FEmusic_liked_playlists"});
      final List<ExplorePlaylist> playlists = [];
      
      final contents = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']?[0]?['gridRenderer']?['items'] ?? [];
      
      for (var item in contents) {
        final renderer = item['musicTwoRowItemRenderer'];
        if (renderer == null) continue;
        
        final playlistId = renderer['navigationEndpoint']?['browseEndpoint']?['browseId'];
        if (playlistId != null) {
          playlists.add(ExplorePlaylist(
            id: playlistId,
            title: _client.getText(renderer['title']) ?? "Unknown",
            author: _client.getText(renderer['subtitle']) ?? "YouTube",
            thumbnailUrl: renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'] ?? "",
            videoCount: 0, // InnerTube doesn't always show count here
          ));
        }
      }
      return playlists;
    } catch (e) {
      debugPrint('YoutubePlaylistRepository: fetchMyPlaylists error: $e');
      return [];
    }
  }

  Future<List<ExploreItem>> fetchFullPlaylistContents(String playlistId) async {
    final List<ExploreItem> items = [];
    String? continuationToken;

    try {
      // First batch
      final data = await _client.post('browse', {"browseId": playlistId});
      continuationToken = _parsePlaylistBatch(data, items);

      // Recursive continuation for large playlists (>100 songs)
      int safetyLimit = 0;
      while (continuationToken != null && safetyLimit < 20) {
        final contData = await _client.post('browse', {
          "continuation": continuationToken,
        });
        continuationToken = _parsePlaylistBatch(contData, items);
        safetyLimit++;
      }
    } catch (e) {
      debugPrint('YoutubePlaylistRepository: Error fetching playlist contents: $e');
    }
    return items;
  }

  Future<bool> editYouTubePlaylist(String playlistId, String videoId, {required bool isAdd, String? setVideoId}) async {
    try {
      final endpoint = 'browse/edit_playlist';
      final payload = {
        "playlistId": playlistId,
        "actions": [
          isAdd 
            ? {"action": "ACTION_ADD_VIDEO", "addedVideoId": videoId}
            : {"action": "ACTION_REMOVE_VIDEO_BY_SET_VIDEO_ID", "setVideoId": setVideoId}
        ]
      };

      final data = await _client.post(endpoint, payload);
      return data['status'] == 'STATUS_SUCCEEDED';
    } catch (e) {
      debugPrint('YoutubePlaylistRepository: editYouTubePlaylist error: $e');
      return false;
    }
  }

  String? _parsePlaylistBatch(Map<String, dynamic> data, List<ExploreItem> items) {
    final contents = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['content']?['sectionListRenderer']?['contents']?[0]?['musicPlaylistShelfRenderer']?['contents'] ?? 
                    data['onResponseReceivedActions']?[0]?['appendContinuationItemsAction']?['continuationItems'] ?? [];
    
    for (var item in contents) {
      final renderer = item['musicResponsiveListItemRenderer'];
      if (renderer == null) continue;

      final videoId = renderer['playlistItemData']?['videoId'];
      final setVideoId = renderer['playlistItemData']?['setVideoId'];
      
      if (videoId != null) {
        items.add(ExploreItem(
          id: videoId,
          title: _client.getText(renderer['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ?? "Unknown",
          author: _client.getText(renderer['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ?? "Unknown",
          duration: "0:00", 
          thumbnailUrl: renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'] ?? "",
          url: "https://www.youtube.com/watch?v=$videoId",
          setVideoId: setVideoId,
          originalVideo: null,
        ));
      }
    }

    final contData = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['content']?['sectionListRenderer']?['contents']?[0]?['musicPlaylistShelfRenderer']?['continuations']?[0]?['nextContinuationData'] ??
                    data['onResponseReceivedActions']?[0]?['appendContinuationItemsAction']?['continuationItems']?.last?['continuationItemRenderer']?['continuationEndpoint']?['continuationCommand'];
    
    return contData?['token'];
  }
}
