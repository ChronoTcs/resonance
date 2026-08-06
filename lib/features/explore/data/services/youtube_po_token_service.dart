import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/services/po_token_provider_service.dart';

final youtubePoTokenServiceProvider = Provider<YoutubePoTokenService>((ref) {
  return YoutubePoTokenService();
});

class YoutubePoTokenService {
  static const _channel = MethodChannel('com.chronostudio.resonance/potoken');

  Future<String?> generatePoToken(String visitorData) async {
    if (Platform.isAndroid) {
      try {
        final String? token = await _channel.invokeMethod<String>('generatePoToken', {
          'visitorData': visitorData,
        });
        return token;
      } catch (e) {
        debugPrint('[YoutubePoTokenService] Android zemer-cipher MethodChannel failed: $e');
      }
    } else if (Platform.isWindows) {
      final activeToken = poTokenProviderService.activePoToken;
      if (activeToken != null && activeToken.isNotEmpty) {
        return activeToken;
      }
      return await poTokenProviderService.generateFreshToken();
    }

    // Fallback to local XOR mock token generator if platform-specific methods fail
    return _generateMockPoToken(visitorData);
  }

  Future<String?> decipherSignature(String signatureCipher, String videoId) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('decipherSignature', {
        'signatureCipher': signatureCipher,
        'videoId': videoId,
      });
    } catch (e) {
      debugPrint('[YoutubePoTokenService] Android decipherSignature failed: $e');
      return null;
    }
  }

  Future<String?> decipherN(String url) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('decipherN', {
        'url': url,
      });
    } catch (e) {
      debugPrint('[YoutubePoTokenService] Android decipherN failed: $e');
      return null;
    }
  }

  String _generateMockPoToken(String visitorData) {
    try {
      String decodedVisitorData = Uri.decodeComponent(visitorData);
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
      
      final visitorBytes = utf8.encode(decodedVisitorData);
      final encryptedBytes = Uint8List(visitorBytes.length);
      for (int i = 0; i < visitorBytes.length; i++) {
        encryptedBytes[i] = visitorBytes[i] ^ keyBytes[i % keyBytes.length];
      }
      
      final byteData = BytesBuilder();
      
      byteData.addByte(0x0A);
      _writeVarInt(byteData, keyBytes.length);
      byteData.add(keyBytes);
      
      byteData.addByte(0x12);
      _writeVarInt(byteData, encryptedBytes.length);
      byteData.add(encryptedBytes);
      
      byteData.addByte(0x22);
      final metadataConfig = <int>[8, 2, 24, 0];
      _writeVarInt(byteData, metadataConfig.length);
      byteData.add(metadataConfig);
      
      return base64Url.encode(byteData.toBytes()).replaceAll('=', '');
    } catch (_) {
      return '';
    }
  }

  void _writeVarInt(BytesBuilder builder, int value) {
    while (true) {
      if ((value & ~0x7F) == 0) {
        builder.addByte(value);
        return;
      } else {
        builder.addByte((value & 0x7F) | 0x80);
        value >>>= 7;
      }
    }
  }
}
