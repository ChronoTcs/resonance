import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  /// Generates the mandatory SAPISIDHASH for YouTube InnerTube Auth.
  /// Format: [timestamp]_[sha1_hash]
  static String generateSapiSidHash(String sapiSid, String origin) {
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String data = '$timestamp $sapiSid $origin';
    final String hash = sha1.convert(utf8.encode(data)).toString();
    return '${timestamp}_$hash';
  }

  /// Optional: Helper for other hashing needs
  static String sha1Hash(String input) {
    return sha1.convert(utf8.encode(input)).toString();
  }
}
