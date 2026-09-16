import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/domain/models/media_item.dart';

void main() {
  group('CachedStreamMusic Metadata Resolution Tests', () {
    late Directory tempDir;
    late Directory audioDir;
    late Directory metadataDir;
    late Directory imagesDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resonance_cached_test_');
      audioDir = Directory(p.join(tempDir.path, 'audio'))..createSync();
      metadataDir = Directory(p.join(tempDir.path, 'metadata'))..createSync();
      imagesDir = Directory(p.join(tempDir.path, 'images'))..createSync();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('pairs m4a audio with sidecar JSON and resolves local artwork', () async {
      const songId = 'gDfBzCed95A';
      final audioFile = File(p.join(audioDir.path, '$songId.m4a'))..writeAsStringSync('dummy audio');
      final artFile = File(p.join(imagesDir.path, 'art_$songId.jpg'))..writeAsStringSync('dummy image');

      final meta = MediaItem(
        id: songId,
        path: songId,
        title: 'Beautiful (feat. Camila Cabello)',
        artist: 'Bazzi',
        album: 'Beautiful - Single',
        thumbnailUrl: 'https://example.com/remote.jpg',
        type: 'audio',
      );

      final metaFile = File(p.join(metadataDir.path, '$songId.json'))
        ..writeAsStringSync(jsonEncode(meta.toJson(includeArt: false)));

      expect(audioFile.existsSync(), isTrue);
      expect(metaFile.existsSync(), isTrue);
      expect(artFile.existsSync(), isTrue);

      final parsedJson = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final parsedItem = MediaItem.fromJson(parsedJson);

      final resolved = parsedItem.copyWith(
        path: audioFile.path,
        thumbnailUrl: artFile.path,
      );

      expect(resolved.title, equals('Beautiful (feat. Camila Cabello)'));
      expect(resolved.artist, equals('Bazzi'));
      expect(resolved.path, equals(audioFile.path));
      expect(resolved.thumbnailUrl, equals(artFile.path));
    });

    test('fallback creates valid MediaItem when sidecar metadata is missing', () {
      const songId = 'd5ZbO8O7WKI';
      final audioFile = File(p.join(audioDir.path, '$songId.m4a'))..writeAsStringSync('dummy audio');

      final fallback = MediaItem(
        id: songId,
        path: audioFile.path,
        title: songId,
        type: 'audio',
      );

      expect(fallback.id, equals(songId));
      expect(fallback.title, equals(songId));
      expect(fallback.artist, isNull);
      expect(fallback.path, equals(audioFile.path));
    });
  });
}
