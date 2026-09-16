import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/interfaces/i_platform_stream_resolver.dart';
import 'linux_stream_resolver.dart';

// ── Linux Platform Providers ────────────────────────────────────────────────
// Registered via platformStreamResolverProvider factory.
// Do NOT import directly outside of platform_stream_provider.dart.

final linuxStreamResolverProvider = Provider<IPlatformStreamResolver>((ref) {
  return LinuxStreamResolver(ref);
});
