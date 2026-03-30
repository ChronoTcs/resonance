import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

class WebviewState {
  final WebviewController? controller;
  final String currentUrl;
  final LoadingState loadingState;
  final Set<String> userAllowedHosts;
  final Set<String> userBlockedHosts;
  final String? interceptedUrl;
  final bool isInitialized;
  final bool isMinimized;

  WebviewState({
    this.controller,
    this.currentUrl = '',
    this.loadingState = LoadingState.none,
    this.userAllowedHosts = const {},
    this.userBlockedHosts = const {},
    this.interceptedUrl,
    this.isInitialized = false,
    this.isMinimized = false,
  });

  WebviewState copyWith({
    WebviewController? controller,
    String? currentUrl,
    LoadingState? loadingState,
    Set<String>? userAllowedHosts,
    Set<String>? userBlockedHosts,
    String?
    interceptedUrl, // If null is passed, it should be null in the new state
    bool allowClearInterceptedUrl = false, // Helper to force clear
    bool? isInitialized,
    bool? isMinimized,
  }) {
    return WebviewState(
      controller: controller ?? this.controller,
      currentUrl: currentUrl ?? this.currentUrl,
      loadingState: loadingState ?? this.loadingState,
      userAllowedHosts: userAllowedHosts ?? this.userAllowedHosts,
      userBlockedHosts: userBlockedHosts ?? this.userBlockedHosts,
      interceptedUrl: allowClearInterceptedUrl
          ? null
          : (interceptedUrl ?? this.interceptedUrl),
      isInitialized: isInitialized ?? this.isInitialized,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

class WebviewNotifier extends Notifier<WebviewState> {
  StreamSubscription? _loadingSub;
  StreamSubscription? _urlSub;

  @override
  WebviewState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return WebviewState();
  }

  Future<void> init() async {
    if (state.isInitialized) return;

    final controller = WebviewController();
    try {
      await controller.initialize();

      await controller.setBackgroundColor(const Color(0x00000000));
      await controller.setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      );

      // Kunci mati semua percobaan membuka jendela/tab baru dari situs manapun (Hard-Deny Policy)
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      _loadingSub = controller.loadingState.listen((loadState) {
        state = state.copyWith(loadingState: loadState);
        if (loadState == LoadingState.navigationCompleted) {
          _injectAdblocker();
        }
      });

      _urlSub = controller.url.listen((url) async {
        // GLOBAL GUARD: Redirection Interceptor (Anti-Popunder/Top-Frame Hijacking)
        final uri = Uri.tryParse(url);
        final currentHost = uri?.host.toLowerCase() ?? '';
        final isUserAllowed = state.userAllowedHosts.any(
          (host) => currentHost.contains(host),
        );

        final isHostPlayer =
            currentHost.contains('iamtheking') ||
            currentHost.contains('idocdn') ||
            currentHost.contains('turbovip') ||
            currentHost.contains('turbovid') ||
            currentHost.contains('emturbovid') ||
            currentHost.contains('playeriframe') ||
            currentHost.contains('short.icu') ||
            currentHost.contains('abyss') ||
            currentHost.contains('cast') ||
            currentHost.contains('dood') ||
            isUserAllowed;

        final isAllowedDomain =
            currentHost.contains('lk21') ||
            currentHost.contains('google.com') ||
            isHostPlayer;

        if (!isAllowedDomain) {
          debugPrint('Resonance: Global Guard Blocked Same-Tab Ad to $url');

          // 1. Hard Stop: Hentikan pemuatan skrip pembajak riwayat
          await controller.executeScript("window.stop();");

          // 2. Mundur secara aman
          await controller.goBack();

          final isBlockedForever = state.userBlockedHosts.any(
            (host) => currentHost.contains(host),
          );
          if (!isBlockedForever) {
            state = state.copyWith(interceptedUrl: url);
          }
        }
      });

      state = state.copyWith(controller: controller, isInitialized: true);
    } catch (e) {
      debugPrint('Resonance: Webview Global Init Error: $e');
    }
  }

  void addAllowedHost(String host) {
    state = state.copyWith(
      userAllowedHosts: {...state.userAllowedHosts, host.toLowerCase()},
    );
  }

  void addBlockedHost(String host) {
    state = state.copyWith(
      userBlockedHosts: {...state.userBlockedHosts, host.toLowerCase()},
    );
  }

  void setMinimized(bool minimized) {
    state = state.copyWith(isMinimized: minimized);
    if (minimized) {
      pauseMedia();
    }
  }

  Future<void> pauseMedia() async {
    final controller = state.controller;
    if (controller == null) return;

    const pauseJs = """
      (function() {
        try {
          const pauseAll = (win) => {
            try {
              win.document.querySelectorAll('video, audio').forEach(m => {
                if (!m.paused) m.pause();
              });
            } catch (e) {}
            
            for (let i = 0; i < win.frames.length; i++) {
              try { pauseAll(win.frames[i]); } catch(e) {}
            }
          };
          pauseAll(window);
        } catch (e) {}
        window.stop();
      })();
    """;
    await controller.executeScript(pauseJs);
  }

  void clearInterceptedUrl() {
    state = state.copyWith(allowClearInterceptedUrl: true);
  }

  Future<void> _injectAdblocker() async {
    final controller = state.controller;
    if (controller == null) return;

    final currentHost =
        Uri.tryParse(state.currentUrl)?.host.toLowerCase() ?? '';
    final isUserAllowed = state.userAllowedHosts.any(
      (host) => currentHost.contains(host),
    );

    final isHostPlayer =
        currentHost.contains('iamtheking') ||
        currentHost.contains('idocdn') ||
        currentHost.contains('turbovip') ||
        currentHost.contains('turbovid') ||
        currentHost.contains('emturbovid') ||
        currentHost.contains('playeriframe') ||
        currentHost.contains('short.icu') ||
        currentHost.contains('abyss') ||
        currentHost.contains('cast') ||
        currentHost.contains('dood') ||
        isUserAllowed;

    if (isHostPlayer) {
      const popUpDefuserJs = """
        (function() {
          window.open = function() { return { closed: false, close: function(){} }; };
          document.addEventListener('click', function(e) {
            const a = e.target.closest('a');
            if (a && a.getAttribute('target') === '_blank') a.removeAttribute('target');
          }, true);
          window.adsbygoogle = window.adsbygoogle || [];
          window.adsbygoogle.push = function() { return Array.prototype.push.apply(this, arguments); };
        })();
      """;
      await controller.executeScript(popUpDefuserJs);
    } else {
      const adKillerJs = """
        (function() {
          window.open = function() { return { closed: false, close: function(){} }; };
          const style = document.createElement('style');
          style.innerHTML = `
            iframe[src*="ads"], div[id*="google_ads"], div[class*="ad-"], 
            div[style*="z-index: 9999999"], div[style*="z-index:9999999"],
            div[style*="position: fixed; top: 0px; left: 0px; width: 100%; height: 100%;"] {
              display: none !important; pointer-events: none !important;
            }
          `;
          document.head.appendChild(style);
          
          const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
              mutation.addedNodes.forEach((node) => {
                if (node.nodeType === 1) {
                  const zIndex = window.getComputedStyle(node).zIndex;
                  const opacity = window.getComputedStyle(node).opacity;
                  if (parseInt(zIndex) > 1000 && opacity == "0") {
                    node.remove();
                  }
                }
              });
            });
          });
          observer.observe(document.body, { childList: true, subtree: true });
        })();
      """;
      await controller.executeScript(adKillerJs);
    }
  }

  void _cleanup() {
    _loadingSub?.cancel();
    _urlSub?.cancel();
    state.controller?.clearCache();
    state.controller?.clearCookies();
    state.controller?.dispose();
  }

  void reset() {
    _cleanup();
    state = WebviewState();
  }
}

final webviewProvider = NotifierProvider<WebviewNotifier, WebviewState>(() {
  return WebviewNotifier();
});
