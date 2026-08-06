import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathUtils {
  static String get _windowsBaseDir {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return p.join(localAppData, 'ChronoTech', 'Resonance');
    }
    final home = Platform.environment['USERPROFILE'] ?? '';
    return p.join(home, 'AppData', 'Local', 'ChronoTech', 'Resonance');
  }

  static Future<String> getMusicDefault() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        return p.join(dirs.first.path, 'Resonance', 'local', 'music');
      }
      final docDir = await getApplicationDocumentsDirectory();
      return p.join(docDir.path, 'local', 'music');
    }
    return p.join(_windowsBaseDir, 'local', 'music');
  }

  static Future<String> getLyricsDefault() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        return p.join(dirs.first.path, 'Resonance', 'local', 'lyrics');
      }
      final docDir = await getApplicationDocumentsDirectory();
      return p.join(docDir.path, 'local', 'lyrics');
    }
    return p.join(_windowsBaseDir, 'local', 'lyrics');
  }

  /// Local downloaded thumbnails/art — separate from stream/system cache.
  static Future<String> getLocalImagesDefault() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        return p.join(dirs.first.path, 'Resonance', 'local', 'images');
      }
      final docDir = await getApplicationDocumentsDirectory();
      return p.join(docDir.path, 'local', 'images');
    }
    return p.join(_windowsBaseDir, 'local', 'images');
  }

  static Future<String> getCacheDefault() async {
    if (Platform.isWindows) {
      return p.join(_windowsBaseDir, 'cache');
    }
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'resonance_cache');
  }

  static Future<String> getStreamDefault() async {
    if (Platform.isWindows) {
      return p.join(_windowsBaseDir, 'stream');
    }
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'stream');
  }

  /// Generates a stable unified ID matching the Python script perfectly:
  /// `loc_` + `sha256(videoId).hexdigest()[:10]`
  static String generateLocId(String videoId) {
    if (videoId.isEmpty) return 'loc_unknown';
    // Ignore any pre-existing loc_ prefixes to prevent double-hashing
    if (videoId.startsWith('loc_')) return videoId;
    
    final bytes = utf8.encode(videoId);
    final digest = sha256.convert(bytes);
    final hashHex = digest.toString().substring(0, 10);
    return 'loc_$hashHex';
  }
}
