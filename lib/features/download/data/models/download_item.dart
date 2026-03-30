import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum DownloadStatus { queued, downloading, done, error, cancelled }

enum DownloadType { audio, video }

enum DownloadSource { ytmusic, youtube, auto }

class DownloadItem {
  final String id;
  final String url;
  final String displayTitle; // user-entered text or resolved title
  final DownloadType type;
  final DownloadSource source;
  final DownloadStatus status;
  final double progress; // 0.0 – 100.0
  final String? speed; // e.g. "1.2 MiB/s"
  final int? eta; // seconds
  final String? resolvedTitle;
  final String? outputPath;
  final String? statusMessage;
  final List<String> logs;
  final String? errorMessage;
  final String? songId; // The permanent Unified ID (Video ID)
  final Video? video; // Pre-fetched metadata to avoid rate limiting

  const DownloadItem({
    required this.id,
    required this.url,
    required this.displayTitle,
    this.type = DownloadType.audio,
    this.source = DownloadSource.ytmusic,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.speed,
    this.eta,
    this.resolvedTitle,
    this.outputPath,
    this.statusMessage,
    this.logs = const [],
    this.errorMessage,
    this.songId,
    this.video,
  });

  DownloadItem copyWith({
    String? id,
    String? url,
    String? displayTitle,
    DownloadType? type,
    DownloadSource? source,
    DownloadStatus? status,
    double? progress,
    String? speed,
    int? eta,
    String? resolvedTitle,
    String? outputPath,
    String? statusMessage,
    List<String>? logs,
    String? errorMessage,
    String? songId,
    Video? video,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      displayTitle: displayTitle ?? this.displayTitle,
      type: type ?? this.type,
      source: source ?? this.source,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      resolvedTitle: resolvedTitle ?? this.resolvedTitle,
      outputPath: outputPath ?? this.outputPath,
      statusMessage: statusMessage ?? this.statusMessage,
      logs: logs ?? this.logs,
      errorMessage: errorMessage ?? this.errorMessage,
      songId: songId ?? this.songId,
      video: video ?? this.video,
    );
  }

  String get effectiveTitle => resolvedTitle ?? displayTitle;
}
