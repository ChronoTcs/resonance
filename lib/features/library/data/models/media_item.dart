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
  final String? date;
  final String type; // 'audio' or 'video'
  
  bool get isLocal => !path.startsWith('http') && !path.startsWith('https');

  MediaItem({
    this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.albumArt,
    this.thumbnailUrl,
    this.duration,
    this.date,
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
    String? date,
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
      date: date ?? this.date,
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
      'date': date,
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
      date: json['date'],
      albumArt: json['albumArtBase64'] != null ? base64Decode(json['albumArtBase64'] as String) : null,
      type: json['type'] ?? 'audio',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.path == path &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.thumbnailUrl == thumbnailUrl &&
        other.duration == duration &&
        other.date == date &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      path,
      title,
      artist,
      album,
      thumbnailUrl,
      duration,
      date,
      type,
    );
  }

  @override
  String toString() {
    return 'MediaItem(id: $id, title: $title, path: $path, type: $type)';
  }
}
