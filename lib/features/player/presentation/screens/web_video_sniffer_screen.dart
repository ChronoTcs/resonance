import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../application/providers/video_player_notifier.dart';
import '../../application/providers/webview_provider.dart'; // GLOBAL PROVIDER
import '../../../library/data/models/media_item.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import 'dart:ui'; // For BackdropFilter

class WebVideoSnifferScreen extends ConsumerStatefulWidget {
  final String initialUrl;
  const WebVideoSnifferScreen({super.key, required this.initialUrl});

  @override
  ConsumerState<WebVideoSnifferScreen> createState() => _WebVideoSnifferScreenState();
}

class _WebVideoSnifferScreenState extends ConsumerState<WebVideoSnifferScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webviewProvider.notifier).init().then((_) {
        final state = ref.read(webviewProvider);
        if (state.currentUrl.isEmpty) {
          state.controller?.loadUrl(widget.initialUrl);
        }
        _urlController.text = state.currentUrl;
      });
    });
  }

  // Note: Adblocker logic moved to global provider (application/webview_provider.dart)

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _onSniffRequested() async {
    final webviewState = ref.read(webviewProvider);
    final controller = webviewState.controller;
    
    if (controller == null) {
      _showSnack('Webview not initialized!');
      return;
    }

    try {
      final urlToCheck = webviewState.currentUrl;
      if (urlToCheck.contains('youtube.com') || urlToCheck.contains('youtu.be')) {
        _showSnack('Gunakan fitur pencarian bawaan aplikasi untuk YouTube!');
        return;
      }

      _showSnack('Extracting video URLs...');
      
      final script = await rootBundle.loadString('assets/scripts/sniffer_scripts.js');
      final dynamic result = await controller.executeScript(script);
      
      if (result == null || result is! String) {
        _showSnack('No video URLs found on this page.');
        return;
      }

      final List<dynamic> decoded = jsonDecode(result);
      final List<Map<String, dynamic>> findings = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      if (findings.isEmpty) {
        _showSnack('No video URLs found. Try playing the video first.');
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) => ListView.builder(
          itemCount: findings.length,
          itemBuilder: (context, index) {
            final finding = findings[index];
            final type = finding['type'] as String;
            final url = finding['url'] as String;
            final title = finding['title'] as String? ?? (type == 'VIDEO' ? "Video Result" : "Player Host (Tap to Dive)");
            final site = finding['site'] as String? ?? "";
            final isVideo = type == 'VIDEO';

            return ListTile(
              leading: Icon(
                isVideo ? Icons.play_circle_fill : Icons.login,
                color: isVideo ? Colors.green : Colors.blue,
              ),
              title: Text(
                title,
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: isVideo ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text(
                site.isNotEmpty ? "$site • $url" : url, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis
              ),
              trailing: isVideo ? const Icon(Icons.play_arrow) : const Icon(Icons.arrow_forward),
              onTap: () async {
                if (isVideo) {
                  final ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
                  final item = MediaItem(
                    title: title,
                    artist: site.isNotEmpty ? site : "Web Sniffer",
                    path: url,
                    type: 'video',
                  );
                  
                  final referer = webviewState.currentUrl;
                  final host = url.contains('//') ? Uri.parse(url).host.toLowerCase() : '';
                  
                  final isHydrax = host.contains('iamtheking.tv') || host.contains('idocdn');
                  final isTurbo = host.contains('turbovip');
                  final isCast = host.contains('cast');
                  
                  ref.read(videoPlayerProvider.notifier).playVideo(item, headers: {
                    'User-Agent': ua,
                    'Referer': (isHydrax || isTurbo || isCast) ? url : referer, 
                    'Origin': referer.split('://').first == 'https' 
                        ? 'https://${Uri.parse(referer).host}' 
                        : 'http://${Uri.parse(referer).host}',
                  });
                  
                  // 1. Close bottom sheet
                  Navigator.of(context).pop();
                  
                  // 2. Minimize Sniffer (instead of destroying)
                  ref.read(webviewProvider.notifier).setMinimized(true);
                  Navigator.of(context).pop();
                  
                  _showSnack('Video mulai diputar! Klik Mini Player di bawah untuk kontrol penuh.');
                } else {
                  // IFRAME DIVING: Logic Branching (Focus Mode vs Normal Dive)
                  final isHydrax = url.contains('short.icu') || url.contains('abyss') || url.contains('hydrax');
                  
                  if (isHydrax) {
                    // FOCUS MODE (Anti-Framebusting: Isolate iframe inside existing page)
                    final focusJs = """
                      (function() {
                        const iframes = document.querySelectorAll('iframe');
                        let target = null;
                        iframes.forEach(i => { if(i.src === '$url') target = i; });
                        if(target) {
                           document.body.innerHTML = ''; 
                           document.body.style.background = 'black';
                           target.style = 'position:fixed;top:0;left:0;width:100vw;height:100vh;border:none;z-index:999999;';
                           document.body.appendChild(target);
                        }
                      })();
                    """;
                    await controller.executeScript(focusJs);
                    if (context.mounted) {
                      Navigator.pop(context); // Close sheet
                      _showSnack('Mode Fokus Aktif! (Video ini dienkripsi, tonton langsung di sini)');
                    }
                  } else {
                    // NORMAL DIVE (Untuk Turbovip, Cast, Doodstream, dll)
                    
                    // Tambahkan ke daftar putih agar tidak diblokir oleh Ad-Guard!
                    final targetHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
                    if (targetHost.isNotEmpty) {
                      ref.read(webviewProvider.notifier).addAllowedHost(targetHost);
                    }
                    
                    // Gunakan jsonEncode untuk mencegah XSS Injection
                    final safeUrl = jsonEncode(url); 
                    final diveJs = """
                      (function() {
                        const a = document.createElement('a');
                        a.href = $safeUrl; 
                        document.body.appendChild(a);
                        a.click();
                      })();
                    """;
                    await controller.executeScript(diveJs);
                    if (context.mounted) {
                      Navigator.pop(context); // Close sheet
                      _showSnack('Masuk ke Host Player. Tekan "Sniff Video" LAGI untuk mengambil videonya!');
                    }
                  }
                }
              },
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Sniff Error: $e');
      _showSnack('Error during extraction: $e');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webviewState = ref.watch(webviewProvider);
    final controller = webviewState.controller;    // Sinkronkan TextField jika URL berubah dari global
    ref.listen<WebviewState>(webviewProvider, (previous, next) {
      if (previous?.currentUrl != next.currentUrl) {
        _urlController.text = next.currentUrl;
      }
    });

    final interceptedUrl = webviewState.interceptedUrl;
    final hasInterception = interceptedUrl != null && interceptedUrl.isNotEmpty;
    final host = hasInterception ? (Uri.tryParse(interceptedUrl)?.host.toLowerCase() ?? '') : '';

    return Scaffold(
      appBar: AppBar(
        leading: ReusableHoverIconButton(
          icon: Icons.close,
          tooltip: 'Minimize Sniffer',
          onTap: () {
            ref.read(webviewProvider.notifier).setMinimized(true);
            Navigator.pop(context);
          },
        ),
        title: TextField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter URL (e.g., https://...)',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (value) async {
            String url = value.trim();
            if (url.isNotEmpty) {
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://$url';
              }
              await controller?.loadUrl(url);
            }
          },
        ),
        actions: [
          ReusableHoverIconButton(
            icon: Icons.arrow_back,
            iconSize: 24,
            tooltip: 'Browser Back',
            onTap: () async {
              await controller?.goBack();
            },
          ),
          ReusableHoverIconButton(
            icon: Icons.arrow_forward,
            iconSize: 24,
            tooltip: 'Browser Forward',
            onTap: () async {
              await controller?.goForward();
            },
          ),
          ReusableHoverIconButton(
            icon: Icons.refresh,
            tooltip: 'Reload',
            onTap: () => controller?.reload(),
          ),
          // Total Clean Exit
          ReusableHoverIconButton(
            icon: Icons.exit_to_app,
            color: Colors.redAccent,
            tooltip: 'Kill Sniffer Session',
            onTap: () {
              ref.read(webviewProvider.notifier).reset();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          webviewState.isInitialized && controller != null
              ? Webview(controller)
              : const Center(child: CircularProgressIndicator()),
          
          // PREMIUM REDIRECT GUARD NOTIFICATION
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            bottom: hasInterception ? 80 : -200, // Slide up/down
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: hasInterception ? 1.0 : 0.0,
              child: _InterceptionCard(
                host: host,
                interceptedUrl: interceptedUrl ?? '',
                onDismiss: () => ref.read(webviewProvider.notifier).clearInterceptedUrl(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onSniffRequested,
        label: const Text('Sniff Video'),
        icon: const Icon(Icons.search),
      ),
    );
  }
}

class _InterceptionCard extends ConsumerStatefulWidget {
  final String host;
  final String interceptedUrl;
  final VoidCallback onDismiss;

  const _InterceptionCard({
    required this.host,
    required this.interceptedUrl,
    required this.onDismiss,
  });

  @override
  ConsumerState<_InterceptionCard> createState() => _InterceptionCardState();
}

class _InterceptionCardState extends ConsumerState<_InterceptionCard> {
  Timer? _timer;

  @override
  void didUpdateWidget(_InterceptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interceptedUrl != oldWidget.interceptedUrl && widget.interceptedUrl.isNotEmpty) {
      _startTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.interceptedUrl.isNotEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Redirect Tertahan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Aplikasi mencegah navigasi otomatis ke:',
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
              ),
              Text(
                widget.host,
                style: TextStyle(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   TextButton(
                    onPressed: () {
                      ref.read(webviewProvider.notifier).addBlockedHost(widget.host);
                      widget.onDismiss();
                    },
                    child: Text('Selamanya', style: TextStyle(color: colorScheme.error)),
                  ),
                   TextButton(
                    onPressed: widget.onDismiss,
                    child: Text('Abaikan', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ref.read(webviewProvider.notifier).addAllowedHost(widget.host);
                      ref.read(webviewProvider).controller?.loadUrl(widget.interceptedUrl);
                      widget.onDismiss();
                    },
                    child: const Text('Izinkan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
