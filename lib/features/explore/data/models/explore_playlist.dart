import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

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

  factory ExplorePlaylist.fromPlaylist(yt.Playlist playlist) {
    String thumb = playlist.thumbnails.highResUrl;
    if (playlist.thumbnails.maxResUrl.isNotEmpty) {
      thumb = playlist.thumbnails.maxResUrl;
    } else if (playlist.thumbnails.standardResUrl.isNotEmpty) {
      thumb = playlist.thumbnails.standardResUrl;
    } else if (playlist.thumbnails.highResUrl.isNotEmpty) {
      thumb = playlist.thumbnails.highResUrl;
    } else if (playlist.thumbnails.mediumResUrl.isNotEmpty) {
      thumb = playlist.thumbnails.mediumResUrl;
    }

    return ExplorePlaylist(
      id: playlist.id.value,
      title: playlist.title,
      author: playlist.author,
      thumbnailUrl: thumb,
      videoCount: playlist.videoCount ?? 0,
    );
  }
}
