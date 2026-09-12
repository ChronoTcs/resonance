import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

void main() {
  group('Recent Searches Data Model & Serialization', () {
    test('serializes and deserializes stream search items without album art bytes', () {
      final item = MediaItem(
        id: 'yt_track_123',
        path: 'https://youtube.com/watch?v=yt_track_123',
        title: 'Cyberpunk Theme',
        artist: 'Various Artists',
        thumbnailUrl: 'https://img.youtube.com/vi/yt_track_123/hqdefault.jpg',
        duration: const Duration(minutes: 3, seconds: 45),
        type: 'audio',
      );

      final jsonMap = item.toJson(includeArt: false);
      expect(jsonMap['albumArt'], isNull);
      expect(jsonMap['id'], 'yt_track_123');
      expect(jsonMap['title'], 'Cyberpunk Theme');

      final encoded = jsonEncode([jsonMap]);
      final decodedList = (jsonDecode(encoded) as List)
          .map((j) => MediaItem.fromJson(j as Map<String, dynamic>))
          .toList();

      expect(decodedList.length, 1);
      expect(decodedList.first.id, 'yt_track_123');
      expect(decodedList.first.title, 'Cyberpunk Theme');
      expect(decodedList.first.thumbnailUrl, 'https://img.youtube.com/vi/yt_track_123/hqdefault.jpg');
    });

    test('deduplicates tracks when adding new item with same id', () {
      final list = <MediaItem>[
        MediaItem(id: 'song1', path: 'path1', title: 'Song 1', artist: 'Artist 1', type: 'audio'),
        MediaItem(id: 'song2', path: 'path2', title: 'Song 2', artist: 'Artist 2', type: 'audio'),
      ];

      final newItem = MediaItem(id: 'song2', path: 'path2_alt', title: 'Song 2 Updated', artist: 'Artist 2', type: 'audio');
      list.removeWhere((i) => (i.id ?? i.path) == (newItem.id ?? newItem.path));
      list.insert(0, newItem);

      expect(list.length, 2);
      expect(list.first.id, 'song2');
      expect(list.first.title, 'Song 2 Updated');
      expect(list[1].id, 'song1');
    });
  });
}
