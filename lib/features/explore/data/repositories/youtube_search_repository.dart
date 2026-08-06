import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../library/data/models/media_item.dart';
import '../models/explore_item.dart';
import '../models/explore_playlist.dart';
import '../services/youtube_innertube_client.dart';
import '../models/explore_home.dart';
import '../../../../core/utils/thumbnail_utils.dart';

final youtubeSearchRepositoryProvider = Provider<YoutubeSearchRepository>((ref) {
  final client = ref.watch(youtubeInnerTubeClientProvider);
  final repo = YoutubeSearchRepository(client);
  ref.onDispose(() => repo.dispose());
  return repo;
});

class YoutubeSearchRepository {
  final YoutubeInnerTubeClient _client;
  YoutubeSearchRepository(this._client);

  /// Search for tracks using YT Music InnerTube (webRemix profile).
  /// Returns official YTM audio tracks only.
  Future<List<ExploreItem>> search(String query) async {
    try {
      final data = await _client.post(
        'search',
        {
          "query": query,
          "params": "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQ", // Songs filter
        },
        profile: YoutubeClientProfile.webRemix,
      );

      final List<ExploreItem> results = [];
      final contents =
          data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]
              ?['tabRenderer']?['content']?['sectionListRenderer']
              ?['contents'] as List? ?? [];

      for (var section in contents) {
        // ── Top Result card (musicCardShelfRenderer) ──
        final cardShelf = section['musicCardShelfRenderer'];
        if (cardShelf != null) {
          final videoId = cardShelf['navigationEndpoint']?['watchEndpoint']?['videoId'];
          if (videoId != null) {
            final subtitleRuns = cardShelf['subtitle']?['runs'] as List?;
            String author = 'Unknown Author';
            String duration = '0:00';
            String type = 'audio';

            if (subtitleRuns != null && subtitleRuns.isNotEmpty) {
              const typeLabels = {'Song', 'Video', 'EP', 'Single', 'Album'};
              final firstText = (subtitleRuns[0]['text'] as String? ?? '').trim();
              if (firstText == 'Video') type = 'video';

              for (var i = subtitleRuns.length - 1; i >= 0; i--) {
                final text = (subtitleRuns[i]['text'] as String? ?? '').trim();
                if (RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(text)) {
                  duration = text;
                  break;
                }
              }

              if (typeLabels.contains(firstText)) {
                if (subtitleRuns.length > 2) {
                  author = (subtitleRuns[2]['text'] as String? ?? 'Unknown Author').trim();
                }
              } else {
                if (firstText.isNotEmpty && firstText != '•' && firstText != '·') {
                  author = firstText;
                }
              }
            }

            results.add(ExploreItem(
              id: videoId,
              title: _client.getText(cardShelf['title']) ?? 'Unknown',
              author: author,
              duration: duration,
              type: type,
              thumbnailUrl: ThumbnailUtils.upgradeResolution(
                cardShelf['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'],
              ),
              url: 'https://www.youtube.com/watch?v=$videoId',
              originalVideo: null,
            ));
          }
          continue;
        }

        // ── Grouped shelf (musicShelfRenderer) — fallback layout ──
        final shelfItems = section['musicShelfRenderer']?['contents'] as List?;

        // ── Per-item sections (itemSectionRenderer) — Songs filter layout ──
        // Each track lives in its own itemSectionRenderer.contents[0]
        final itemSectionItems = section['itemSectionRenderer']?['contents'] as List?;

        final rowList = shelfItems ?? itemSectionItems ?? [];
        for (var item in rowList) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final videoId = renderer['playlistItemData']?['videoId'] ??
              renderer['navigationEndpoint']?['watchEndpoint']?['videoId'];
          if (videoId == null) continue;

          final metadata = _parseMetadataLine(renderer);
          results.add(ExploreItem(
            id: videoId,
            title: _client.getText(renderer['flexColumns']?[0]
                    ?['musicResponsiveListItemFlexColumnRenderer']?['text']) ??
                'Unknown',
            author: metadata.author,
            duration: metadata.duration,
            type: metadata.type,
            thumbnailUrl: ThumbnailUtils.upgradeResolution(
              renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'],
            ),
            url: 'https://www.youtube.com/watch?v=$videoId',
            originalVideo: null,
          ));
        }
      }

      debugPrint('[SearchRepo] search: found ${results.length} YTM tracks for "$query"');
      return results;
    } catch (e) {
      debugPrint('YoutubeSearchRepository: Search error: $e');
      return [];
    }
  }

  /// Search for playlists using YT Music InnerTube (webRemix profile).
  Future<List<ExplorePlaylist>> searchPlaylists(String query) async {
    try {
      final data = await _client.post(
        'search',
        {
          "query": query,
          "params": "EgWKAQIBAAw%3D%3D", // Strict YTM Playlists filter
        },
        profile: YoutubeClientProfile.webRemix,
      );

      final List<ExplorePlaylist> results = [];
      final contents =
          data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]
              ?['tabRenderer']?['content']?['sectionListRenderer']
              ?['contents'] as List? ?? [];

      for (var section in contents) {
        final shelf = section['musicShelfRenderer'];
        final shelfItems = shelf?['contents'] as List?;
        final itemSectionItems = section['itemSectionRenderer']?['contents'] as List?;
        final rowList = shelfItems ?? itemSectionItems ?? [];

        for (var item in rowList) {
          final renderer = item['musicResponsiveListItemRenderer'] ?? item['musicTwoRowItemRenderer'];
          if (renderer == null) continue;

          final playlistId = renderer['navigationEndpoint']?['browseEndpoint']?['browseId'] ??
              renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                  ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                  ?['watchPlaylistEndpoint']?['playlistId'];
          if (playlistId == null) continue;

          // Exclude Channel IDs ('UC...') and non-playlist browse IDs
          final pageType = renderer['navigationEndpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextConfig']?['pageType'];
          if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' || playlistId.startsWith('UC')) {
            continue;
          }

          final title = _client.getText(renderer['flexColumns']?[0]
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']) ??
              _client.getText(renderer['title']) ??
              'Unknown Playlist';
          final author = _client.getText(renderer['flexColumns']?[1]
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']) ??
              _client.getText(renderer['subtitle']) ??
              'YouTube';

          // Skip items where author line explicitly indicates Artist or Channel
          if (author.startsWith('Artist') || author.contains('subscribers') || author.contains('monthly audience')) {
            continue;
          }

          final rawThumbUrl = renderer['thumbnail']?['musicThumbnailRenderer']
                  ?['thumbnail']?['thumbnails']?.last?['url'] ??
              renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']
                  ?['thumbnails']?.last?['url'];
          final thumbUrl = ThumbnailUtils.upgradeResolution(rawThumbUrl);

          results.add(ExplorePlaylist(
            id: playlistId,
            title: title,
            author: author,
            thumbnailUrl: thumbUrl,
            videoCount: 0,
          ));
        }
      }

      debugPrint('[SearchRepo] searchPlaylists: found ${results.length} playlists for "$query"');
      return results;
    } catch (e) {
      debugPrint('YoutubeSearchRepository: searchPlaylists error: $e');
      return [];
    }
  }



  /// Fetches Spotify-like radio recommendations seeded from [videoId].

  /// Uses YT Music /next endpoint with RDAMVM prefix (same as Metrolist).
  /// Returns up to [limit] tracks, excluding the seed track itself.
  Future<List<MediaItem>> getRadioRecommendations(
    String videoId, {
    int limit = 20,
  }) async {
    try {
      final data = await _client.post(
        'next',
        {
          'videoId': videoId,
          'playlistId': 'RDAMVM$videoId', // AutoMix radio seed
          'isAudioOnly': true,
        },
        profile: YoutubeClientProfile.webRemix,
      );

      // Navigate to the autoMix queue items
      final List<dynamic> queueItems = data['contents']
              ?['singleColumnMusicWatchNextResultsRenderer']
              ?['tabbedRenderer']
              ?['watchNextTabbedResultsRenderer']
              ?['tabs']?[0]
              ?['tabRenderer']
              ?['content']
              ?['musicQueueRenderer']
              ?['content']
              ?['playlistPanelRenderer']
              ?['contents'] ??
          [];

      final List<MediaItem> recommendations = [];
      for (final entry in queueItems) {
        final renderer = entry['playlistPanelVideoRenderer'];
        if (renderer == null) continue;

        final id = renderer['videoId'] as String?;
        if (id == null || id == videoId) continue; // skip seed

        final title = _client.getText(renderer['title']) ?? 'Unknown';
        final thumbnail =
            renderer['thumbnail']?['thumbnails']?.last?['url'] as String? ?? '';

        // Secondary-line text: artist • duration
        final runs = renderer['longBylineText']?['runs'] as List?;
        final artist = runs != null && runs.isNotEmpty
            ? (runs[0]['text'] as String? ?? 'Unknown Artist')
            : 'Unknown Artist';

        final durationText = renderer['lengthText']?['runs']?[0]?['text']
            as String?;
        Duration? duration;
        if (durationText != null) {
          final parts = durationText.split(':').map(int.parse).toList();
          duration = parts.length == 2
              ? Duration(minutes: parts[0], seconds: parts[1])
              : Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
        }

        recommendations.add(MediaItem(
          id: id,
          path: id, // streaming — resolved on play
          title: title,
          artist: artist,
          thumbnailUrl: thumbnail,
          duration: duration,
          type: 'audio',
        ));

        if (recommendations.length >= limit) break;
      }

      debugPrint(
          '[RadioRec] Got ${recommendations.length} recommendations for $videoId');
      return recommendations;
    } catch (e) {
      debugPrint('[RadioRec] Failed for $videoId: $e');
      return [];
    }
  }

  /// Extracts Artist, Album, Duration, and Type from flexColumns[1].
  /// YouTube Music includes a type label ("Song", "Video", etc.) as the
  /// first run — we skip that to get the real artist & album name.
  ({String author, String? album, String duration, String type}) _parseMetadataLine(Map<String, dynamic> renderer) {
    final runs = renderer['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
    if (runs == null || runs.isEmpty) return (author: "Unknown Author", album: null, duration: "0:00", type: "audio");

    const typeLabels = {'Song', 'Video', 'EP', 'Single', 'Album'};

    // 1. Extract Duration (usually the last run in flexColumns[1])
    String duration = "0:00";
    for (var i = runs.length - 1; i >= 0; i--) {
      final text = (runs[i]['text'] as String? ?? '').trim();
      if (RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(text)) {
        duration = text;
        break;
      }
    }

    // 2. Determine track type ('video' or 'audio')
    String type = 'audio';
    final firstRunText = (runs[0]['text'] as String? ?? '').trim();
    if (firstRunText == 'Video') {
      type = 'video';
    }

    // Filter meaningful non-separator runs
    final validRuns = runs
        .map((r) => (r['text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty && t != '•' && t != '·' && !RegExp(r'^\d+:\d+(?::\d+)?$').hasMatch(t))
        .toList();

    String author = 'Unknown Author';
    String? album;

    if (validRuns.isNotEmpty) {
      if (typeLabels.contains(validRuns.first)) {
        if (validRuns.length > 1) author = validRuns[1];
        if (validRuns.length > 2) album = validRuns[2];
      } else {
        author = validRuns.first;
        if (validRuns.length > 1) album = validRuns[1];
      }
    }

    return (author: author, album: album, duration: duration, type: type);
  }

  Future<List<ExploreItem>> getFeaturedMusic() async {
    try {
      await _client.post('browse', {"browseId": "FEmusic_explore"});
      // Simplified: Just an example of InnerTube parse
      // In a real app, you'd navigate the deep JSON tree
      return []; // Implementation detail omitted for brevity, but same logic as search
    } catch (e) {
      debugPrint('YoutubeSearchRepository: Featured music error: $e');
      return [];
    }
  }

  Future<List<ExploreHomeSection>> getHomeFeed() async {
    try {
      // Use auth so we get the logged-in user's personalized sections (Listen Again, Mixed for You, etc.)
      final data = await _client.post('browse', {"browseId": "FEmusic_home"}, useAuth: true);
      final List<ExploreHomeSection> sections = [];
      
      // WEB_REMIX returns tabbedSingleColumn; fallback to singleColumn
      final rawContents = 
        data['contents']?['tabbedSingleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] ??
        data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] ?? [];
      
      debugPrint('[HomeFeed] Total raw sections: ${rawContents.length}');

      for (var section in rawContents) {
        // Log what renderer types each section has
        final rendererKeys = (section as Map<String, dynamic>).keys.toList();
        
        // Support carousel shelves, flat shelves, and tastebuilder shelves
        final carousel = section['musicCarouselShelfRenderer'];
        final shelfRenderer = section['musicShelfRenderer'];
        final tastebuilder = section['musicTastebuilderShelfRenderer'];
        
        String title = "";
        List<dynamic> contentList = [];
        
        if (carousel != null) {
          title = _client.getText(carousel['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']) ?? "";
          contentList = carousel['contents'] ?? [];
        } else if (shelfRenderer != null) {
          title = _client.getText(shelfRenderer['title']) ?? "";
          contentList = shelfRenderer['contents'] ?? [];
        } else if (tastebuilder != null) {
          // Tastebuilder shelves (e.g. initial setup artist choices or personalized quick setups)
          title = _client.getText(tastebuilder['primaryText']) ?? _client.getText(tastebuilder['heading']) ?? "Personalize Your Feed";
          contentList = tastebuilder['contents'] ?? [];
        } else {
          debugPrint('[HomeFeed] SKIP section — unknown renderer: $rendererKeys');
          continue;
        }
        
        if (title.isEmpty) {
          debugPrint('[HomeFeed] SKIP section — empty title, renderer: $rendererKeys');
          continue;
        }
        
        final List<ExploreHomeItem> items = [];
        int skippedItems = 0;
        for (var item in contentList) {
          // musicTwoRowItemRenderer: playlists, albums
          // musicResponsiveListItemRenderer: quick picks tracks
          final twoRow = item['musicTwoRowItemRenderer'];
          final responsiveRow = item['musicResponsiveListItemRenderer'];
          
          if (twoRow != null) {
            final titleText = _client.getText(twoRow['title']) ?? "Unknown";
            final subtitleText = _client.getText(twoRow['subtitle']) ?? "";
            final rawThumbnailUrl = twoRow['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'];
            final thumbnailUrl = ThumbnailUtils.upgradeResolution(rawThumbnailUrl);
            
            // Direct nav endpoint OR nested in overlay for some items
            final directNav = twoRow['navigationEndpoint'];
            final overlayNav = twoRow['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
            final nav = directNav ?? overlayNav;
            
            final browseId = nav?['browseEndpoint']?['browseId'];
            final videoId = nav?['watchEndpoint']?['videoId'] ?? nav?['watchPlaylistEndpoint']?['playlistId'];
            
            if (browseId != null) {
              items.add(ExploreHomeItem(
                id: browseId,
                title: titleText,
                subtitle: subtitleText,
                thumbnailUrl: thumbnailUrl,
                isPlaylist: true,
              ));
            } else if (videoId != null) {
              items.add(ExploreHomeItem(
                id: videoId,
                title: titleText,
                subtitle: subtitleText,
                thumbnailUrl: thumbnailUrl,
                isPlaylist: false,
              ));
            } else {
              skippedItems++;
              debugPrint('[HomeFeed] SKIP item in "$title" — no browseId/videoId. nav keys: ${nav?.keys?.toList()}');
            }
          } else if (responsiveRow != null) {
            // Quick Picks — flat track rows
            final videoId = responsiveRow['playlistItemData']?['videoId'] ??
                responsiveRow['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
            if (videoId == null) { skippedItems++; continue; }
            
            final titleText = _client.getText(responsiveRow['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ?? "Unknown";
            final subtitleText = _client.getText(responsiveRow['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ?? "";
            final rawThumbnailUrl = responsiveRow['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?.last?['url'];
            final thumbnailUrl = ThumbnailUtils.upgradeResolution(rawThumbnailUrl);
            
            items.add(ExploreHomeItem(
              id: videoId,
              title: titleText,
              subtitle: subtitleText,
              thumbnailUrl: thumbnailUrl,
              isPlaylist: false,
            ));
          } else {
            skippedItems++;
          }
        }
        
        debugPrint('[HomeFeed] Section "$title": ${items.length} items, $skippedItems skipped');
        
        if (items.isNotEmpty) {
          sections.add(ExploreHomeSection(title: title, items: items));
        }
      }
      debugPrint('[HomeFeed] Final sections returned: ${sections.length}');
      return sections;
    } catch (e, stack) {
      debugPrint('YoutubeSearchRepository: getHomeFeed error: $e\n$stack');
      return [];
    }
  }


  void dispose() {}
}
