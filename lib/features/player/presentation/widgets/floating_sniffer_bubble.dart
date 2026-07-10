import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../../application/providers/webview_provider.dart';
import '../screens/web_video_sniffer_screen.dart';
import '../../../../main.dart';
import '../../../../core/routing/route_provider.dart';
import '../../application/providers/video_player_notifier.dart' as v;
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';

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
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isLoading ? Colors.blueAccent : Colors.white24,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLoading ? Colors.blue : Colors.black).withValues(alpha: 0.5),
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
                        UIcons.regular.globe,
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
                  ReusableHoverIconButton(
                    tooltip: 'Restore Sniffer',
                    icon: UIcons.regular.expand,
                    iconSize: 16,
                    color: Colors.greenAccent,
                    label: "Restore",
                    labelStyle: const TextStyle(
                      color: Colors.greenAccent, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                    onTap: () {
                      ref.read(webviewProvider.notifier).setMinimized(false);
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/sniffer'),
                          builder: (context) => const WebVideoSnifferScreen(initialUrl: ''),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // "Kill" Button
                  ReusableHoverIconButton(
                    tooltip: 'Close Sniffer',
                    icon: UIcons.regular.cross_small,
                    iconSize: 20,
                    color: Colors.redAccent,
                    onTap: () {
                      ref.read(webviewProvider.notifier).reset();
                    },
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
