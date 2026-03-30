import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../application/webview_provider.dart';
import '../screens/web_video_sniffer_screen.dart';
import '../../../../main.dart';
import '../../../../core/services/route_provider.dart';
import '../../application/video_player_notifier.dart' as v;
import 'package:resonance_app/core/widgets/hover_widgets.dart';

class FloatingSnifferBubble extends ConsumerStatefulWidget {
  const FloatingSnifferBubble({super.key});

  @override
  ConsumerState<FloatingSnifferBubble> createState() => _FloatingSnifferBubbleState();
}

class _FloatingSnifferBubbleState extends ConsumerState<FloatingSnifferBubble> {
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    final webviewState = ref.watch(webviewProvider);
    final currentRoute = ref.watch(routeProvider);
    final isFullscreen = ref.watch(v.videoPlayerProvider.select((s) => s.isFullscreen));
    
    // Suppressed routes where bubble should not appear
    final suppressedRoutes = [
      '/video_player',
      '/fullscreen_video',
      '/fullscreen_player',
      '/now_playing',
    ];

    bool shouldHide = !webviewState.isMinimized || 
                     !webviewState.isInitialized || 
                     isFullscreen ||
                     suppressedRoutes.contains(currentRoute);
    
    final isLoading = webviewState.loadingState == LoadingState.loading;

    return Positioned(
      left: _offset?.dx ?? (MediaQuery.of(context).size.width - 80),
      top: _offset?.dy ?? 100,
      child: Visibility(
        visible: !shouldHide,
        maintainState: true,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _offset = (_offset ?? Offset(MediaQuery.of(context).size.width - 80, 100)) + details.delta;
            });
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isLoading ? Colors.blueAccent : Colors.white24,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLoading ? Colors.blue : Colors.black).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon / Status
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.language,
                        color: isLoading ? Colors.blue : Colors.white,
                        size: 24,
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // "Restore" Button
                  HoverWrapper(
                    onTap: () {
                      ref.read(webviewProvider.notifier).setMinimized(false);
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/sniffer'),
                          builder: (context) => const WebVideoSnifferScreen(initialUrl: ''),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    hoverColor: Colors.white.withOpacity(0.1),
                    child: const Row(
                      children: [
                        Icon(Icons.open_in_full, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Restore",
                          style: TextStyle(
                            color: Colors.greenAccent, 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // "Kill" Button (No tooltip for stability)
                  ModernIconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      ref.read(webviewProvider.notifier).reset();
                    },
                    padding: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
