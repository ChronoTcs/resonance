import '../models/po_token_pair.dart';

/// Contract every platform PoToken provider must fulfill.
/// No Platform.isX allowed inside any implementation of this interface.
abstract interface class IPlatformPoTokenService {
  /// Generates a PoToken pair (playerPoToken + streamPoToken) for [visitorData].
  /// Returns null if the platform does not support PoTokens or if generation fails.
  Future<PoTokenPair?> getPoToken(String visitorData, {String? videoId});

  /// Deciphers a YouTube signatureCipher for [videoId].
  /// Returns null if the platform handles cipher via another mechanism (e.g. yt-dlp on Windows).
  Future<String?> decipherSignature(String signatureCipher, String videoId);

  /// Transforms the n-parameter in [url] to unthrottle the stream.
  /// Returns null if the platform handles n-param via another mechanism.
  Future<String?> decipherN(String url);

  /// Returns the current signatureTimestamp (sts) for this platform.
  /// Returns null if not applicable.
  Future<int?> getSignatureTimestamp();
}
