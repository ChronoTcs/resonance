import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathUtils {
  static Future<String> getMusicDefault() async {
    if (Platform.isAndroid) {
      // Sub-folder Music di dalam Master Folder Resonance
      return '/storage/emulated/0/Resonance/Music';
    } else {
      final docDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      // On Windows, getDownloadsDirectory often returns user's Downloads. 
      // But usually Music is preferred.
      final home = Platform.environment['USERPROFILE'] ?? '';
      if (home.isNotEmpty) {
        return p.join(home, 'Music', 'Resonance Downloads');
      }
      return p.join(docDir.path, 'Resonance Music');
    }
  }

  static Future<String> getVideoDefault() async {
    if (Platform.isAndroid) {
      // Sub-folder Video di dalam Master Folder Resonance
      return '/storage/emulated/0/Resonance/Video';
    } else {
      final home = Platform.environment['USERPROFILE'] ?? '';
      if (home.isNotEmpty) {
        return p.join(home, 'Videos', 'Resonance Downloads');
      }
      final docDir = await getApplicationDocumentsDirectory();
      return p.join(docDir.path, 'Resonance Videos');
    }
  }

  static Future<String> getLyricsDefault() async {
    if (Platform.isAndroid) {
      // Sub-folder Lyrics di dalam Master Folder Resonance
      return '/storage/emulated/0/Resonance/Lyrics';
    } else {
      final music = await getMusicDefault();
      return p.join(music, 'Lyrics');
    }
  }

  static Future<String> getCacheDefault() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return p.join(userProfile, 'resonance_cache');
      }
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
