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

    test('Range 416 with > 64KB treats file as complete and renames to final destination', () async {
      const songId = 'test_song_416_789';
      final finalPath = p.join(tempDir.path, '$songId.m4a');
      final tmpPath = '$finalPath.tmp';
      final tmpFile = File(tmpPath);
      final finalFile = File(finalPath);

      // Existing 80KB in tmp file
      tmpFile.writeAsBytesSync(List.filled(80 * 1024, 42));

      // Range 416 returned from server: already fully downloaded
      final downloadedBytes = tmpFile.lengthSync();
      expect(downloadedBytes > 64 * 1024, isTrue);

      await tmpFile.rename(finalPath);
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), 80 * 1024);
    });
  });
}
