import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/i_platform_po_token_service.dart';
import '../../domain/interfaces/i_platform_stream_resolver.dart';
import 'android_po_token_service.dart';
import 'android_stream_resolver.dart';

// ── Android Platform Providers ───────────────────────────────────────────────
// These providers are ONLY registered via platformStreamResolverProvider factory.
// Do NOT import these providers directly outside of platform_stream_provider.dart.

final androidPoTokenServiceProvider = Provider<IPlatformPoTokenService>((ref) {
  return AndroidPoTokenService();
});

final androidStreamResolverProvider = Provider<IPlatformStreamResolver>((ref) {
  final poTokenService = ref.watch(androidPoTokenServiceProvider);
  final httpClient = http.Client();
  ref.onDispose(() => httpClient.close());
  return AndroidStreamResolver(ref, poTokenService, httpClient);
});
