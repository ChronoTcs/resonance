import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/interfaces/i_platform_po_token_service.dart';
import '../../domain/interfaces/i_platform_stream_resolver.dart';
import 'windows_po_token_service.dart';
import 'windows_stream_resolver.dart';

// ── Windows Platform Providers ────────────────────────────────────────────────
// These providers are ONLY registered via platformStreamResolverProvider factory.
// Do NOT import these providers directly outside of platform_stream_provider.dart.

final windowsPoTokenServiceProvider = Provider<IPlatformPoTokenService>((ref) {
  final service = WindowsPoTokenService();
  ref.onDispose(() => service.stop());
  // Fire-and-forget warm-up: generate first token in background
  service.start();
  return service;
});

final windowsStreamResolverProvider = Provider<IPlatformStreamResolver>((ref) {
  return WindowsStreamResolver(ref);
});
