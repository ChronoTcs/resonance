import 'dart:typed_data';

class MediaItem {
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final Uint8List? albumArt;
  final Duration? duration;
  final String type; // 'audio' or 'video'

  MediaItem({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.albumArt,
    this.duration,
    required this.type,
  });

  @override
  String toString() {
    return 'MediaItem(title: $title, path: $path, type: $type)';
  }
}
