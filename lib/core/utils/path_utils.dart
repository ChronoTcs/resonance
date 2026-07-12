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
      return '/storage/emulated/0/Resonance/Music';
    } else {
      return p.join(_windowsBaseDir, 'Music');
    }
  }

  static Future<String> getLyricsDefault() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Resonance/Lyrics';
    } else {
      return p.join(_windowsBaseDir, 'Lyrics');
    }
  }

  static Future<String> getCacheDefault() async {
    if (Platform.isWindows) {
      return p.join(_windowsBaseDir, 'cache');
    }
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'resonance_cache');
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
