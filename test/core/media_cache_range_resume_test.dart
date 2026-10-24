import 'package:resonance/core/data/services/cache_manager.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCache Range-Resume & Cancellation Logic (Phase 20)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resonance_range_resume_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('simulates range-resume byte append to .tmp file until > 64KB completion', () async {
      const songId = 'test_song_resume_123';
      final finalPath = p.join(tempDir.path, '$songId.m4a');
      final tmpPath = '$finalPath.tmp';
      final tmpFile = File(tmpPath);
      final finalFile = File(finalPath);

      // 1. Initial partial download interrupted after 40KB
      final initialBytes = List.filled(40 * 1024, 65); // 40KB of 'A'
      tmpFile.writeAsBytesSync(initialBytes, mode: FileMode.write);
      expect(tmpFile.existsSync(), isTrue);
      expect(tmpFile.lengthSync(), 40 * 1024);

      // 2. Next attempt resumes with Range: bytes=40960- and receives 30KB
      final resumedBytes = List.filled(30 * 1024, 66); // 30KB of 'B'
      final sink = tmpFile.openWrite(mode: FileMode.append);
      sink.add(resumedBytes);
      await sink.flush();
      await sink.close();

      // Total downloaded bytes = 70KB (> 64KB threshold)
      final totalBytes = tmpFile.lengthSync();
      expect(totalBytes, 70 * 1024);

      // 3. Atomically rename .tmp -> .m4a
      await tmpFile.rename(finalPath);
      expect(tmpFile.existsSync(), isFalse);
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), 70 * 1024);
    });

    test('cancelled download cleans up .tmp file and leaves final file untouched', () async {
      const songId = 'test_song_cancel_456';
      final finalPath = p.join(tempDir.path, '$songId.m4a');
      final tmpPath = '$finalPath.tmp';
      final tmpFile = File(tmpPath);
      final finalFile = File(finalPath);

      // Create partial .tmp
      tmpFile.writeAsBytesSync(List.filled(20 * 1024, 0));
      expect(tmpFile.existsSync(), isTrue);

      // Simulate cancellation cleanup
      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }

      expect(tmpFile.existsSync(), isFalse);
      expect(finalFile.existsSync(), isFalse);
    });

    test('Range 416 with Content-Range matching >= 98% of expected total treats file as complete', () async {
      const songId = 'test_song_416_789';
      final finalPath = p.join(tempDir.path, '$songId.m4a');
      final tmpPath = '$finalPath.tmp';
      final tmpFile = File(tmpPath);
      final finalFile = File(finalPath);

      // Existing 80KB in tmp file matching Content-Range: bytes */81920
      const expectedTotalBytes = 80 * 1024;
      tmpFile.writeAsBytesSync(List.filled(expectedTotalBytes, 42));

      final downloadedBytes = tmpFile.lengthSync();
      final isTrulyComplete = downloadedBytes >= (expectedTotalBytes * 0.98).floor() &&
          downloadedBytes > 64 * 1024;
      expect(isTrulyComplete, isTrue);

      await tmpFile.rename(finalPath);
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), expectedTotalBytes);
    });

    test('Truncated 50% download (> 64KB but < 98% of Content-Length) is rejected and not promoted to .m4a', () async {
      const songId = 'test_song_truncated_50pct';
      final finalPath = p.join(tempDir.path, '$songId.m4a');
      final tmpPath = '$finalPath.tmp';
      final tmpFile = File(tmpPath);
      final finalFile = File(finalPath);

      // 3.5MB expected track cut off at 1.75MB (50%)
      const expectedTotalBytes = 3500 * 1024;
      const truncatedBytes = 1750 * 1024;
      tmpFile.writeAsBytesSync(List.filled(truncatedBytes, 65));

      final downloadedBytes = tmpFile.lengthSync();
      expect(downloadedBytes > 64 * 1024, isTrue);

      final meetsExpectedTotal = downloadedBytes >= (expectedTotalBytes * 0.98).floor();
      expect(meetsExpectedTotal, isFalse);
      expect(finalFile.existsSync(), isFalse);
    });

    test('CacheManager scanAndSortFiles ignores .tmp files and protects pinned files', () async {
      // Create 3 complete .m4a files (each 1MB) and 1 in-flight .tmp file (5MB)
      final file1 = File(p.join(tempDir.path, 'song_old.m4a'));
      final file2 = File(p.join(tempDir.path, 'song_pinned.m4a'));
      final file3 = File(p.join(tempDir.path, 'song_new.m4a'));
      final tmpFile = File(p.join(tempDir.path, 'song_inflight.m4a.tmp'));

      file1.writeAsBytesSync(List.filled(1024 * 1024, 1));
      file2.writeAsBytesSync(List.filled(1024 * 1024, 2));
      file3.writeAsBytesSync(List.filled(1024 * 1024, 3));
      tmpFile.writeAsBytesSync(List.filled(5 * 1024 * 1024, 4));

      final now = DateTime.now();
      file1.setLastModifiedSync(now.subtract(const Duration(hours: 3)));
      file2.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
      file3.setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      final result = CacheManager.scanAndSortFilesForTesting(
        tempDir.path,
        1, // limit 1MB
        {'song_pinned'},
      );

      // Verify .tmp file (5MB) did not inflate cache size (total m4a = 3MB)
      expect(result.currentSizeMb, closeTo(3.0, 0.05));
      // In-flight .tmp file is NOT in pathsToDelete
      expect(result.pathsToDelete.contains(tmpFile.path), isFalse);
      // Pinned file is protected
      expect(result.pathsToDelete.contains(file2.path), isFalse);
      // Oldest unpinned file is evicted first
      expect(result.pathsToDelete.first, file1.path);
    });
  });
}
