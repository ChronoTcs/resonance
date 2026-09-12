import 'package:path/path.dart' as p;

/// Single authoritative registry of supported audio file formats across Resonance.
abstract class AppAudioFormats {
  /// Raw file extensions without leading dot (suitable for FilePicker allowedExtensions).
  static const List<String> rawExtensions = [
    'mp3',
    'm4a',
    'wav',
    'flac',
    'ogg',
    'opus',
    'aac',
    'wma',
  ];

  /// Canonical dotted extensions in lowercase for O(1) set-lookup.
  static const Set<String> dotExtensions = {
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.ogg',
    '.opus',
    '.aac',
    '.wma',
  };

  /// Human-readable label displaying supported formats.
  static const String formatListLabel = 'MP3, FLAC, M4A, WAV, OGG, OPUS, AAC, WMA';

  /// Returns true if [filePath] or [extension] represents a supported audio format.
  static bool isSupported(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return dotExtensions.contains(ext);
  }
}
