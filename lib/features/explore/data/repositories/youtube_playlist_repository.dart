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
      debugPrint('[YoutubePlaylistRepo] fetchMyPlaylists error: $e');
      return [];
    }
  }

  Future<List<ExploreItem>> fetchFullPlaylistContents(String playlistId) async {
    final List<ExploreItem> items = [];
    String? continuationToken;

    try {
      final rawId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
      
      // Mix/radio playlists (RDAMVM..., RDCLAK..., VLRD..., RDAT..., OLAK...) use 'next' endpoint
      final isMix = rawId.startsWith('RD') ||
          rawId.startsWith('OLAK') ||
          rawId.startsWith('VLRD') ||
          playlistId.startsWith('VLRD');
      
      if (isMix) {
        debugPrint('[YoutubePlaylistRepo] Mix detected ($rawId), using next endpoint');
        final data = await _client.post('next', {"playlistId": rawId});
        final queueItems = data['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['musicQueueRenderer']?['content']?['playlistPanelRenderer']?['contents'] ?? [];
        
        debugPrint('[YoutubePlaylistRepo] Mix queue items count: ${queueItems.length}');
        
        for (var qItem in queueItems) {
          final renderer = qItem['playlistPanelVideoRenderer'];
          if (renderer == null) continue;
          final videoId = renderer['videoId'];
          if (videoId == null) continue;
          
          items.add(ExploreItem(
            id: videoId,
            title: _client.getText(renderer['title']) ?? 'Unknown',
            author: _client.getText(renderer['shortBylineText']) ?? 
                    _client.getText(renderer['longBylineText'])?.split('•').first.trim() ?? 'Unknown',
            duration: '0:00',
            thumbnailUrl: renderer['thumbnail']?['thumbnails']?.last?['url'] ?? '',
            url: 'https://www.youtube.com/watch?v=$videoId',
            setVideoId: null,
            originalVideo: null,
          ));
        }
        return items;
      }

      // Standard playlist vs Channel browse ID handling
      final String browseId;
      if (playlistId.startsWith('VL') || playlistId.startsWith('PL') || playlistId.startsWith('RDCLAK')) {
        browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      } else {
        browseId = playlistId;
      }

      debugPrint('[YoutubePlaylistRepo] Browse request ($browseId)');
      final data = await _client.post('browse', {"browseId": browseId});
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

      // Fallback failover: If browse returned 0 items (e.g. for a community mix ID), try the next endpoint
      if (items.isEmpty) {
        debugPrint('[YoutubePlaylistRepo] Browse returned 0 items for $browseId, attempting next endpoint failover');
        final nextData = await _client.post('next', {"playlistId": rawId});
        final queueItems = nextData['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['musicQueueRenderer']?['content']?['playlistPanelRenderer']?['contents'] ?? [];
        for (var qItem in queueItems) {
          final renderer = qItem['playlistPanelVideoRenderer'];
          if (renderer == null) continue;
          final videoId = renderer['videoId'];
          if (videoId == null) continue;
          
          items.add(ExploreItem(
            id: videoId,
            title: _client.getText(renderer['title']) ?? 'Unknown',
            author: _client.getText(renderer['shortBylineText']) ?? 
                    _client.getText(renderer['longBylineText'])?.split('•').first.trim() ?? 'Unknown',
            duration: '0:00',
            thumbnailUrl: renderer['thumbnail']?['thumbnails']?.last?['url'] ?? '',
            url: 'https://www.youtube.com/watch?v=$videoId',
            setVideoId: null,
            originalVideo: null,
          ));
        }
      }

      debugPrint('[YoutubePlaylistRepo] Playlist returned ${items.length} tracks');
    } catch (e) {
      debugPrint('[YoutubePlaylistRepo] Error fetching playlist contents: $e');
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
      debugPrint('[YoutubePlaylistRepo] editYouTubePlaylist error: $e');
      return false;
    }
  }

  String? _parsePlaylistBatch(Map<String, dynamic> data, List<ExploreItem> items) {
    List contents = [];
    final singleCol = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['content']?['sectionListRenderer']?['contents'] as List?;
    final twoColSecondary = data['contents']?['twoColumnBrowseResultsRenderer']?['secondaryContents']?['sectionListRenderer']?['contents'] as List?;
    final twoColTab = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;

    final sectionListContents = singleCol ?? twoColSecondary ?? twoColTab;
    
    // Extract header playlist / album / artist & thumbnail for fallbacks using safe null-aware checks
    final header = data['header']?['musicDetailHeaderRenderer'] ??
        data['header']?['musicResponsiveHeaderRenderer'] ??
        data['header']?['musicEditableHeaderRenderer']?['header']?['musicDetailHeaderRenderer'] ??
        data['header']?['musicHeaderRenderer'];

    final String? headerArtist = header != null
        ? (_client.getText(header['subtitle']) ?? _client.getText(header['straplineTextOne']))
        : null;

    final String? headerThumb = header != null
        ? (header['thumbnail']?['croppedSquareThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'] ??
            header['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'])
        : null;

    if (sectionListContents != null) {
      for (final section in sectionListContents) {
        final shelf = section['musicPlaylistShelfRenderer'] ?? section['musicShelfRenderer'] ?? section['musicCarouselShelfRenderer'];
        if (shelf != null && shelf['contents'] != null) {
          contents.addAll(shelf['contents'] as List);
        }
      }
    }

    if (contents.isEmpty) {
      contents = data['onResponseReceivedActions']?[0]?['appendContinuationItemsAction']?['continuationItems'] ?? [];
    }
    
    for (var item in contents) {
      final renderer = item['musicResponsiveListItemRenderer'];
      if (renderer == null) continue;

      final videoId = renderer['playlistItemData']?['videoId'];
      final setVideoId = renderer['playlistItemData']?['setVideoId'];
      
      if (videoId != null) {
        final title = _client.getText(renderer['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ??
            _client.getText(renderer['title']) ??
            "Unknown";

        // Extract Artist from runs array or headerArtist fallback
        String author = 'Unknown';
        final flexColumn1 = renderer['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text'];
        final runs1 = flexColumn1?['runs'] as List?;
        if (runs1 != null && runs1.isNotEmpty) {
          final runTexts = runs1
              .map((r) => (r['text'] as String? ?? '').trim())
              .where((t) => t.isNotEmpty && t != '•' && t != '·' && !RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(t))
              .toList();
          if (runTexts.isNotEmpty) {
            author = runTexts.first;
          }
        }

        if (author == 'Unknown' || author.isEmpty) {
          author = _client.getText(renderer['shortBylineText']) ??
              _client.getText(renderer['longBylineText']) ??
              headerArtist ??
              "Unknown Artist";
        }

        if (author.contains('•')) {
          author = author.split('•').first.trim();
        }

        // Duration extraction from fixedColumns[0] or flexColumns
        String duration = "0:00";
        final fixedText = _client.getText(renderer['fixedColumns']?[0]?['musicResponsiveListItemFixedColumnRenderer']?['text']);
        if (fixedText != null && RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(fixedText.trim())) {
          duration = fixedText.trim();
        }

        // Thumbnail extraction with headerThumb & HQ default YouTube fallback
        String thumbnailUrl = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'] ??
            renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'] ??
            headerThumb ??
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

        items.add(ExploreItem(
          id: videoId,
          title: title,
          author: author,
          duration: duration, 
          thumbnailUrl: thumbnailUrl,
          url: "https://www.youtube.com/watch?v=$videoId",
          setVideoId: setVideoId,
          originalVideo: null,
        ));
      }
    }

    String? contToken;
    if (sectionListContents != null) {
      for (final section in sectionListContents) {
        final shelf = section['musicPlaylistShelfRenderer'] ?? section['musicShelfRenderer'];
        if (shelf != null) {
          final conts = shelf['continuations'] as List?;
          if (conts != null && conts.isNotEmpty) {
            contToken = conts[0]?['nextContinuationData']?['continuation'];
            break;
          }
        }
      }
    }

    contToken ??= data['onResponseReceivedActions']?[0]?['appendContinuationItemsAction']?['continuationItems']?.last?['continuationItemRenderer']?['continuationEndpoint']?['continuationCommand']?['token'];
    
    return contToken;
  }
}
