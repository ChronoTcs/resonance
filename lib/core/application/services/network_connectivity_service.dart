import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/features/stream/platform/windows/windows_po_token_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_stream_repository.dart';
import 'package:resonance/features/download/application/download_service.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/settings/application/startup_service.dart';
import 'package:resonance/features/playlist/application/services/playlist_stream_cache_handler.dart';

/// Global connectivity state for Resonance.
class NetworkConnectivityState {
  final bool isOnline;
  final bool isProbing;
  final DateTime? lastChecked;

  const NetworkConnectivityState({
    this.isOnline = true,
    this.isProbing = false,
    this.lastChecked,
  });

  NetworkConnectivityState copyWith({
    bool? isOnline,
    bool? isProbing,
    DateTime? lastChecked,
  }) {
    return NetworkConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      isProbing: isProbing ?? this.isProbing,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

/// Global service monitoring network connectivity via zero-dependency DNS/Socket probe.
/// Automatically handles offline fallback and broadcasts on-reconnected lifecycle events.
class NetworkConnectivityNotifier extends Notifier<NetworkConnectivityState> {
  // TEST: Set to true to simulate offline mode without disabling internet
  static const bool _forceOfflineForTesting = false;

  Timer? _heartbeatTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _previousOnline = !_forceOfflineForTesting;

  @override
  NetworkConnectivityState build() {
    _startMonitoring();
    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: () => _startMonitoring(),
        onPause: () => _stopHeartbeat(),
        onHide: () => _stopHeartbeat(),
      );
    } catch (_) {}

    ref.onDispose(() {
      _stopHeartbeat();
      _lifecycleListener?.dispose();
    });
    return NetworkConnectivityState(isOnline: !_forceOfflineForTesting);
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startMonitoring() {
    // Initial immediate probe
    Future.microtask(() => checkConnectivity());

    // Periodic heartbeat (every 60s when active in foreground)
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkConnectivity();
    });
  }

  /// Probes DNS resolution to determine real internet reachability.
  Future<bool> checkConnectivity() async {
    if (_forceOfflineForTesting) {
      state = state.copyWith(
        isOnline: false,
        isProbing: false,
        lastChecked: DateTime.now(),
      );
      debugPrint('[NetworkConnectivity] 📴 [TEST MODE] Device forced to Offline.');
      return false;
    }

    state = state.copyWith(isProbing: true);
    bool online = false;

    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        online = true;
      }
    } catch (_) {
      // Fallback secondary probe
      try {
        final fallback = await InternetAddress.lookup('github.com')
            .timeout(const Duration(seconds: 4));
        if (fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty) {
          online = true;
        }
      } catch (_) {
        online = false;
      }
    }

    final wasOffline = !_previousOnline;
    _previousOnline = online;

    state = state.copyWith(
      isOnline: online,
      isProbing: false,
      lastChecked: DateTime.now(),
    );

    if (wasOffline && online) {
      debugPrint('[NetworkConnectivity] 🌐 Network connection restored (Online). Triggering global sync...');
      Future.microtask(() => _onReconnected());
    } else if (!online) {
      debugPrint('[NetworkConnectivity] 📴 Device is currently Offline.');
    }

    return online;
  }

  /// Manually force offline state for testing.
  @visibleForTesting
  void simulateOfflineForTesting() {
    _previousOnline = false;
    state = state.copyWith(
      isOnline: false,
      isProbing: false,
      lastChecked: DateTime.now(),
    );
  }

  /// Manually force reconnection for testing, properly dispatching deferred _onReconnected microtask.
  @visibleForTesting
  void simulateReconnectionForTesting() {
    final wasOffline = !_previousOnline;
    _previousOnline = true;
    state = state.copyWith(
      isOnline: true,
      isProbing: false,
      lastChecked: DateTime.now(),
    );

    if (wasOffline) {
      Future.microtask(() => _onReconnected());
    }
  }

  /// Global trigger executed whenever the app reconnects to the internet.
  void _onReconnected() {
    try {
      // 1. Re-run startup update & auto-update checks
      runStartupChecks(ref, isOnline: true);

      // 2. Refresh remote configuration
      unawaited(ref.read(appConfigProvider.notifier).fetchRemoteConfig());

      // 3. Refresh PoToken & YouTube auth session
      if (Platform.isWindows) {
        unawaited(WindowsPoTokenService().generateFreshToken());
      } else if (Platform.isAndroid) {
        ref.read(youtubeStreamRepositoryProvider).warmUpSession();
      }

      // 4. Resume queued downloads if any
      final downloadQueue = ref.read(downloadProvider);
      if (downloadQueue.any((i) => i.status == DownloadStatus.queued)) {
        ref.read(downloadServiceProvider).scheduleNext(downloadQueue);
      }

      // 5. Feed providers (homeFeed, quickPicks, dailyDiscover, similarArtists, speedDial, searchResults)
      // already watch networkConnectivityProvider.select((s) => s.isOnline) and automatically refresh.
      // Manual ref.invalidate calls removed to prevent CircularDependencyError and wasteful double-fetches.

      // 6. Process pending playlist stream cache queue
      unawaited(ref.read(playlistStreamCacheHandlerProvider).processPendingQueue());
    } catch (e) {
      debugPrint('[NetworkConnectivity] Reconnection handler exception: $e');
    }
  }
}

final networkConnectivityProvider =
    NotifierProvider<NetworkConnectivityNotifier, NetworkConnectivityState>(() {
  return NetworkConnectivityNotifier();
});
