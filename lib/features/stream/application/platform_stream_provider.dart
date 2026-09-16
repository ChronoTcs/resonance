import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/interfaces/i_platform_po_token_service.dart';
import '../domain/interfaces/i_platform_stream_resolver.dart';
import '../domain/models/po_token_pair.dart';
import '../platform/android/android_stream_provider.dart';
import '../platform/linux/linux_stream_provider.dart';
import '../platform/windows/windows_stream_provider.dart';

// ── No-Op Fallback for Web / Linux / macOS ────────────────────────────────────
class _NoOpPoTokenService implements IPlatformPoTokenService {
  @override
  Future<PoTokenPair?> getPoToken(String visitorData, {String? videoId}) async => null;
  @override
  Future<String?> decipherSignature(String signatureCipher, String videoId) async => null;
  @override
  Future<String?> decipherN(String url) async => null;
  @override
  Future<int?> getSignatureTimestamp() async => null;
}

// ── Platform Factory Providers ────────────────────────────────────────────────
// THIS FILE IS THE ONLY PLACE IN THE ENTIRE STREAM LAYER
// THAT IS ALLOWED TO BRANCH ON Platform.isX.

final platformPoTokenServiceProvider = Provider<IPlatformPoTokenService>((ref) {
  if (Platform.isWindows) return ref.watch(windowsPoTokenServiceProvider);
  if (Platform.isAndroid) return ref.watch(androidPoTokenServiceProvider);
  return _NoOpPoTokenService();
});

final platformStreamResolverProvider = Provider<IPlatformStreamResolver>((ref) {
  if (Platform.isWindows) {
    return ref.watch(windowsStreamResolverProvider);
  }
  if (Platform.isAndroid) {
    return ref.watch(androidStreamResolverProvider);
  }
  if (Platform.isLinux) {
    return ref.watch(linuxStreamResolverProvider);
  }
  throw UnsupportedError('Platform ${Platform.operatingSystem} not yet supported');
});

