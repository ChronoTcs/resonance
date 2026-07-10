import 'package:flutter/foundation.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

@immutable
class Playlist {
  final String id;
  final String name;
  final String description;
  final List<MediaItem> tracks;

  const Playlist({
    required this.id,
    required this.name,
    this.description = '',
    required this.tracks,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<MediaItem>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tracks': tracks.map((t) => t.toJson(includeArt: false)).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      tracks: ((json['tracks'] as List?) ?? [])
          .map((t) => MediaItem.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}
