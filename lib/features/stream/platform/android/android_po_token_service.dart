import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/interfaces/i_platform_po_token_service.dart';
import '../../domain/models/po_token_pair.dart';

// ── Android-only PoToken Service ─────────────────────────────────────────────
// All methods route through MethodChannel to native Kotlin:
//   PoTokenGenerator (WebView BotGuard VM) for getPoToken
//   ZemerCipher for decipherSignature + decipherN + getSignatureTimestamp
// NO Windows / libmpv imports allowed in this file.
class AndroidPoTokenService implements IPlatformPoTokenService {
  static const _channel = MethodChannel('com.chronostudio.resonance/potoken');

  @override
  Future<PoTokenPair?> getPoToken(String visitorData, {String? videoId}) async {
    try {
      final dynamic result = await _channel.invokeMethod('generatePoToken', {
        'visitorData': visitorData,
        'videoId': videoId ?? '',
      });

      if (result is Map) {
        final playerToken = result['playerPoToken'] as String? ?? '';
        final streamToken = result['streamPoToken'] as String? ?? '';
        if (playerToken.isNotEmpty || streamToken.isNotEmpty) {
          return PoTokenPair(
            playerPoToken: playerToken.isNotEmpty ? playerToken : streamToken,
            streamPoToken: streamToken.isNotEmpty ? streamToken : playerToken,
          );
        }
      } else if (result is String && result.isNotEmpty) {
        return PoTokenPair(playerPoToken: result, streamPoToken: result);
      }
    } catch (e) {
      debugPrint('[AndroidPoTokenService] generatePoToken failed: $e');
    }
    return null;
  }

  @override
  Future<String?> decipherSignature(String signatureCipher, String videoId) async {
    try {
      return await _channel.invokeMethod<String>('decipherSignature', {
        'signatureCipher': signatureCipher,
        'videoId': videoId,
      });
    } catch (e) {
      debugPrint('[AndroidPoTokenService] decipherSignature failed: $e');
      return null;
    }
  }

  @override
  Future<String?> decipherN(String url) async {
    try {
      return await _channel.invokeMethod<String>('decipherN', {'url': url});
    } catch (e) {
      debugPrint('[AndroidPoTokenService] decipherN failed: $e');
      return null;
    }
  }

  @override
  Future<int?> getSignatureTimestamp() async {
    try {
      return await _channel.invokeMethod<int>('getSignatureTimestamp');
    } catch (e) {
      debugPrint('[AndroidPoTokenService] getSignatureTimestamp failed: $e');
      return null;
    }
  }
}
