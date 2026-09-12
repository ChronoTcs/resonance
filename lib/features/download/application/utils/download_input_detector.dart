import '../../data/models/download_item.dart';

/// Classification of user input in the Download Manager.
enum DownloadInputType {
  empty,
  youtubeMusic,
  youtubeVideo,
  youtubePlaylist,
  songSearch,
  unsupportedUrl,
}

/// Analysis result of a single input line.
class SingleInputAnalysis {
  final String raw;
  final DownloadInputType type;
  final DownloadSource resolvedSource;
  final String? videoId;
  final String? playlistId;
  final String? errorMessage;

  const SingleInputAnalysis({
    required this.raw,
    required this.type,
    required this.resolvedSource,
    this.videoId,
    this.playlistId,
    this.errorMessage,
  });

  bool get isValid =>
      type != DownloadInputType.empty &&
      type != DownloadInputType.unsupportedUrl;
}

/// Aggregated analysis of user input (supporting multi-line batch).
class DownloadInputAnalysis {
  final List<SingleInputAnalysis> items;
  final DownloadInputType primaryType;
  final DownloadSource resolvedSource;
  final bool isValid;
  final bool hasPlaylist;
  final bool hasUnsupportedUrl;
  final String? statusMessage;
  final String? warningMessage;

  const DownloadInputAnalysis({
    required this.items,
    required this.primaryType,
    required this.resolvedSource,
    required this.isValid,
    required this.hasPlaylist,
    required this.hasUnsupportedUrl,
    this.statusMessage,
    this.warningMessage,
  });

  int get totalCount => items.where((i) => i.type != DownloadInputType.empty).length;
  int get validCount => items.where((i) => i.isValid).length;
  int get invalidCount => items.where((i) => i.type == DownloadInputType.unsupportedUrl).length;
}

/// Pure-Dart detector for user input in the Download Manager.
class DownloadInputDetector {
  static final RegExp _videoIdRegex = RegExp(r'[a-zA-Z0-9_-]{11}');

  /// Analyzes a single or multi-line string input.
  static DownloadInputAnalysis analyze(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const DownloadInputAnalysis(
        items: [],
        primaryType: DownloadInputType.empty,
        resolvedSource: DownloadSource.auto,
        isValid: false,
        hasPlaylist: false,
        hasUnsupportedUrl: false,
      );
    }

    final parsedItems = lines.map(_analyzeSingle).toList();
    final hasUnsupported = parsedItems.any((i) => i.type == DownloadInputType.unsupportedUrl);
    final hasPlaylist = parsedItems.any((i) => i.type == DownloadInputType.youtubePlaylist);
    final allValid = parsedItems.every((i) => i.isValid);

    // Determine primary display type
    DownloadInputType primaryType;
    if (parsedItems.length == 1) {
      primaryType = parsedItems.first.type;
    } else {
      if (hasUnsupported) {
        primaryType = DownloadInputType.unsupportedUrl;
      } else if (parsedItems.every((i) => i.type == DownloadInputType.youtubeMusic)) {
        primaryType = DownloadInputType.youtubeMusic;
      } else if (parsedItems.every((i) => i.type == DownloadInputType.youtubeVideo)) {
        primaryType = DownloadInputType.youtubeVideo;
      } else if (parsedItems.every((i) => i.type == DownloadInputType.songSearch)) {
        primaryType = DownloadInputType.songSearch;
      } else {
        primaryType = DownloadInputType.youtubeVideo;
      }
    }

    // Resolve optimal DownloadSource
    DownloadSource source;
    if (parsedItems.any((i) => i.resolvedSource == DownloadSource.ytmusic)) {
      source = DownloadSource.ytmusic;
    } else if (parsedItems.any((i) => i.resolvedSource == DownloadSource.youtube)) {
      source = DownloadSource.youtube;
    } else {
      source = DownloadSource.auto;
    }

    String? warningMsg;
    if (hasUnsupported) {
      final invalid = parsedItems.where((i) => i.type == DownloadInputType.unsupportedUrl);
      final sample = invalid.first.raw;
      final domain = _extractDomain(sample);
      warningMsg = domain != null
          ? 'Unsupported link ($domain). Only YouTube links or song titles are supported.'
          : 'Unsupported URL. Only YouTube links or song titles are supported.';
    } else if (hasPlaylist) {
      warningMsg = 'Playlist link detected. For background auto-caching of full playlists, use Library > Playlists > Import.';
    }

    return DownloadInputAnalysis(
      items: parsedItems,
      primaryType: primaryType,
      resolvedSource: source,
      isValid: allValid && lines.isNotEmpty,
      hasPlaylist: hasPlaylist,
      hasUnsupportedUrl: hasUnsupported,
      warningMessage: warningMsg,
    );
  }

  static SingleInputAnalysis _analyzeSingle(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const SingleInputAnalysis(
        raw: '',
        type: DownloadInputType.empty,
        resolvedSource: DownloadSource.auto,
      );
    }

    // Check if input is a URL
    final isUrl = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');

    if (isUrl) {
      final normalized = trimmed.startsWith('www.') ? 'https://$trimmed' : trimmed;
      final uri = Uri.tryParse(normalized);

      if (uri != null) {
        final host = uri.host.toLowerCase();
        final isYouTube = host.contains('youtube.com') || host.contains('youtu.be');

        if (isYouTube) {
          final isMusic = host.contains('music.youtube.com');
          final hasList = uri.queryParameters.containsKey('list');
          final isPlaylistPath = uri.path.contains('playlist');
          final hasVideo = uri.queryParameters.containsKey('v') ||
              (host.contains('youtu.be') && uri.pathSegments.isNotEmpty);

          // Pure playlist (no specific video selected)
          if ((hasList && !hasVideo) || (isPlaylistPath && !hasVideo)) {
            return SingleInputAnalysis(
              raw: trimmed,
              type: DownloadInputType.youtubePlaylist,
              resolvedSource: isMusic ? DownloadSource.ytmusic : DownloadSource.youtube,
              playlistId: uri.queryParameters['list'],
            );
          }

          final videoId = _extractVideoId(uri);

          if (isMusic) {
            return SingleInputAnalysis(
              raw: trimmed,
              type: DownloadInputType.youtubeMusic,
              resolvedSource: DownloadSource.ytmusic,
              videoId: videoId,
            );
          }

          return SingleInputAnalysis(
            raw: trimmed,
            type: DownloadInputType.youtubeVideo,
            resolvedSource: DownloadSource.youtube,
            videoId: videoId,
          );
        }

        // URL from non-YouTube domain (Spotify, SoundCloud, etc.)
        return SingleInputAnalysis(
          raw: trimmed,
          type: DownloadInputType.unsupportedUrl,
          resolvedSource: DownloadSource.auto,
          errorMessage: 'Unsupported URL: ${uri.host}',
        );
      }
    }

    // Plain text search query
    return SingleInputAnalysis(
      raw: trimmed,
      type: DownloadInputType.songSearch,
      resolvedSource: DownloadSource.auto,
    );
  }

  static String? _extractVideoId(Uri uri) {
    if (uri.queryParameters.containsKey('v')) {
      final v = uri.queryParameters['v']!;
      if (_videoIdRegex.hasMatch(v)) return v;
    }
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first;
      if (_videoIdRegex.hasMatch(id)) return id;
    }
    if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
      final idx = uri.pathSegments.indexOf('shorts');
      if (idx + 1 < uri.pathSegments.length) {
        final id = uri.pathSegments[idx + 1];
        if (_videoIdRegex.hasMatch(id)) return id;
      }
    }
    return null;
  }

  static String? _extractDomain(String raw) {
    try {
      final uri = Uri.tryParse(raw.startsWith('www.') ? 'https://$raw' : raw);
      return uri?.host;
    } catch (_) {
      return null;
    }
  }
}
