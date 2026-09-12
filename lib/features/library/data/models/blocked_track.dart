class BlockedTrack {
  final String id;
  final String title;
  final String? artist;
  final String? thumbnailUrl;
  final DateTime blockedAt;

  const BlockedTrack({
    required this.id,
    required this.title,
    this.artist,
    this.thumbnailUrl,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'blockedAt': blockedAt.toIso8601String(),
      };

  factory BlockedTrack.fromJson(Map<String, dynamic> json) {
    return BlockedTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      blockedAt: json['blockedAt'] != null
          ? DateTime.tryParse(json['blockedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
