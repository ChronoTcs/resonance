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
  final String? setVideoId; // [V20.7 SOTA] For YouTube Playlist Operations
  
  bool get isLocal {
    // 1. Identitas Mutlak: Jika ID diawali 'loc_', ini pasti file lokal
    if (id != null && id!.startsWith('loc_')) return true;
    
    // 2. Identitas Mutlak: Jika Path adalah URL http/https
    if (path.startsWith('http')) return false;

    // 3. Cek apakah path mengandung pemisah folder (Slashing)
    // Jika TIDAK ada slash sama sekali (hanya ID murni), maka ini adalah streaming ID
    final hasSlash = path.contains('/') || path.contains('\\');
    if (!hasSlash) return false;

    // 4. Jika ada slash, cek apakah ini berada di folder cache/stream
    final normalizedPath = path.replaceAll('\\', '/');
    if (normalizedPath.contains('/cache/stream/') || normalizedPath.contains('/stream/audio/')) {
      return false;
    }

    // 5. Jika ada slash dan bukan di folder stream, anggap sebagai file lokal fisik
    return true;
  }

  bool get isStreaming => !isLocal;

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
    this.setVideoId,
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
    String? setVideoId,
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
      setVideoId: setVideoId ?? this.setVideoId,
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
      'setVideoId': setVideoId,
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
      setVideoId: json['setVideoId'],
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
