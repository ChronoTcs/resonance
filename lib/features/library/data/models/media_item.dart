import 'dart:typed_data';
import 'dart:convert';

class MediaItem {
  final String? id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final Uint8List? albumArt;
  final String? thumbnailUrl;
  final Duration? duration;
  final String type; // 'audio' or 'video'

  MediaItem({
    this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.albumArt,
    this.thumbnailUrl,
    this.duration,
    required this.type,
  });

  MediaItem copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    Uint8List? albumArt,
    String? thumbnailUrl,
    Duration? duration,
    String? type,
    bool clearAlbumArt = false,
    bool clearThumbnailUrl = false,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: clearAlbumArt ? null : (albumArt ?? this.albumArt),
      thumbnailUrl: clearThumbnailUrl ? null : (thumbnailUrl ?? this.thumbnailUrl),
      duration: duration ?? this.duration,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson({bool includeArt = true}) {
    return {
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': duration?.inMilliseconds,
      'type': type,
      'albumArtBase64': (includeArt && albumArt != null) ? base64Encode(albumArt!) : null,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      path: json['path'] ?? '',
      title: json['title'] ?? 'Unknown',
      artist: json['artist'],
      album: json['album'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs']) : null,
      albumArt: json['albumArtBase64'] != null ? base64Decode(json['albumArtBase64'] as String) : null,
      type: json['type'] ?? 'audio',
    );
  }

  @override
  String toString() {
    return 'MediaItem(id: $id, title: $title, path: $path, type: $type)';
  }
}
