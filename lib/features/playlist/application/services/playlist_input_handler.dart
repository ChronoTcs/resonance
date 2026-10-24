enum PlaylistInputType {
  playlist,
  singleTrack,
  searchQuery,
  invalid,
}

class PlaylistInputAnalysis {
  final String rawInput;
  final PlaylistInputType type;
  final String? playlistId;
  final String? videoId;
  final String? errorMessage;

  const PlaylistInputAnalysis({
    required this.rawInput,
    required this.type,
    this.playlistId,
    this.videoId,
    this.errorMessage,
  });

  bool get isPlaylist => type == PlaylistInputType.playlist;
  bool get isSingleTrack => type == PlaylistInputType.singleTrack;
  bool get isSearchQuery => type == PlaylistInputType.searchQuery;
}

/// Unified handler for classifying and extracting IDs from YouTube / YouTube Music links.
class PlaylistInputHandler {
  static final RegExp _videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final RegExp _playlistIdRegex = RegExp(r'^(PL|VL|RD|OLAK|UU|FL|LL)[a-zA-Z0-9_-]+$');

  /// Analyzes any user input (raw string or URL) and classifies its intent and extracted IDs.
  static PlaylistInputAnalysis analyze(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const PlaylistInputAnalysis(
        rawInput: '',
        type: PlaylistInputType.invalid,
        errorMessage: 'Input is empty',
      );
    }

    final isUrl = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');

    if (isUrl) {
      final normalized = trimmed.startsWith('www.') ? 'https://$trimmed' : trimmed;
      final uri = Uri.tryParse(normalized);

      if (uri == null) {
        return PlaylistInputAnalysis(
          rawInput: trimmed,
          type: PlaylistInputType.invalid,
          errorMessage: 'Malformed URL',
        );
      }

      final host = uri.host.toLowerCase();
      final isYouTube = host.contains('youtube.com') || host.contains('youtu.be');

      if (!isYouTube) {
        return PlaylistInputAnalysis(
          rawInput: trimmed,
          type: PlaylistInputType.invalid,
          errorMessage: 'Unsupported domain: ${uri.host}. Only YouTube and YouTube Music links are supported.',
        );
      }

      // 1. Check for playlist parameter `list=`
      final listParam = uri.queryParameters['list']?.trim();
      final hasList = listParam != null && listParam.isNotEmpty;

      // 2. Check for video ID in URL
      String? extractedVideoId;
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v']!.trim();
        if (_videoIdRegex.hasMatch(v)) extractedVideoId = v;
      } else if (host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        final firstSeg = uri.pathSegments.first.trim();
        if (_videoIdRegex.hasMatch(firstSeg)) extractedVideoId = firstSeg;
      } else if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
        final idx = uri.pathSegments.indexOf('shorts');
        if (idx + 1 < uri.pathSegments.length) {
          final sId = uri.pathSegments[idx + 1].trim();
          if (_videoIdRegex.hasMatch(sId)) extractedVideoId = sId;
        }
      }

      // If both playlist and video are in URL (e.g. watch?v=XYZ&list=PL123):
      // - If path is explicit playlist (e.g. /playlist?list=...), prioritize playlist.
      // - Otherwise, if list exists and user passed it in a playlist context, provide both.
      if (hasList) {
        return PlaylistInputAnalysis(
          rawInput: trimmed,
          type: PlaylistInputType.playlist,
          playlistId: listParam,
          videoId: extractedVideoId,
        );
      }

      // If only video was found:
      if (extractedVideoId != null) {
        return PlaylistInputAnalysis(
          rawInput: trimmed,
          type: PlaylistInputType.singleTrack,
          videoId: extractedVideoId,
        );
      }

      return PlaylistInputAnalysis(
        rawInput: trimmed,
        type: PlaylistInputType.invalid,
        errorMessage: 'No playlist or video ID could be found in the provided YouTube link.',
      );
    }

    // Direct ID input or plain text search
    // Check if it's a raw Playlist ID
    if (_playlistIdRegex.hasMatch(trimmed)) {
      return PlaylistInputAnalysis(
        rawInput: trimmed,
        type: PlaylistInputType.playlist,
        playlistId: trimmed,
      );
    }

    // Check if it's a raw 11-char Video ID
    if (_videoIdRegex.hasMatch(trimmed) && !trimmed.contains(' ')) {
      return PlaylistInputAnalysis(
        rawInput: trimmed,
        type: PlaylistInputType.singleTrack,
        videoId: trimmed,
      );
    }

    // Otherwise, treat as search query
    return PlaylistInputAnalysis(
      rawInput: trimmed,
      type: PlaylistInputType.searchQuery,
    );
  }
}
