import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class ExploreItem {
  final String id;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;
  final String url;
  final String? setVideoId;
  final yt.Video? originalVideo; // Reusable metadata

  const ExploreItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.url,
    this.setVideoId,
    this.originalVideo,
  });

  factory ExploreItem.fromVideo(yt.Video video) {
    String thumb = video.thumbnails.highResUrl;
    if (video.thumbnails.maxResUrl.isNotEmpty) {
      thumb = video.thumbnails.maxResUrl;
    } else if (video.thumbnails.standardResUrl.isNotEmpty) {
      thumb = video.thumbnails.standardResUrl;
    } else if (video.thumbnails.highResUrl.isNotEmpty) {
      thumb = video.thumbnails.highResUrl;
    } else if (video.thumbnails.mediumResUrl.isNotEmpty) {
      thumb = video.thumbnails.mediumResUrl;
    }

    return ExploreItem(
      id: video.id.value,
      title: video.title,
      author: video.author,
      duration: video.duration?.toString().split('.').first ?? '00:00',
      thumbnailUrl: thumb,
      url: video.url,
      setVideoId: null,
      originalVideo: video,
    );
  }
}
