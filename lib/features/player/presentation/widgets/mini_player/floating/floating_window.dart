import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';

import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_bottom_bar.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_overlay_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_lyrics_view.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_translation_toggle.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/mini_player_add_to_playlist_dialog.dart';

class FloatingWindow extends ConsumerStatefulWidget {
  const FloatingWindow({super.key});

  @override
  ConsumerState<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends ConsumerState<FloatingWindow> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      child: Navigator(
        key: _navKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (context) => _FloatingWindowContent(navKey: _navKey),
        ),
      ),
    );
  }
}

class _FloatingWindowContent extends ConsumerWidget {
  final GlobalKey<NavigatorState> navKey;
  const _FloatingWindowContent({required this.navKey});

  void _handleAddToPlaylist(BuildContext context, WidgetRef ref) {
    final track = ref.read(currentTrackProvider);
    if (track == null) return;
    showMiniplayerAddToPlaylistDialog(context, ref, track);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popState = ref.watch(miniPlayerPopProvider);
    final popNotifier = ref.read(miniPlayerPopProvider.notifier);
    final track = ref.watch(currentTrackProvider);

    if (track == null) return const SizedBox.shrink();

    final viewState = popState.viewState;
    final bool isHeaderVisible = viewState != MiniPlayerViewState.idle && 
                               viewState != MiniPlayerViewState.idleLyrics;

    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surface.withValues(alpha: 0.9);
    final headerIconColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: MouseRegion(
                onEnter: (_) {
                  if (popState.viewState != MiniPlayerViewState.lyrics && 
                      popState.viewState != MiniPlayerViewState.idleLyrics) {
                    Future.microtask(() => popNotifier.setViewState(MiniPlayerViewState.hover));
                  }
                },
                onExit: (_) {
                  if (popState.viewState != MiniPlayerViewState.lyrics && 
                      popState.viewState != MiniPlayerViewState.idleLyrics) {
                    Future.microtask(() => popNotifier.setViewState(MiniPlayerViewState.normal));
                  }
                },
                onHover: (_) => Future.microtask(() => popNotifier.resetIdleTimer()),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // A. Background Blurred
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                        child: MediaArtworkWidget(
                          item: track,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                        ),
                      ),
                    ),
                    // Background darkening overlay
                    Positioned.fill(
                      child: Container(color: Colors.black.withValues(alpha: 0.3)),
                    ),

                    // B. Main Artwork (1:1 Ratio)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: MediaArtworkWidget(
                              item: track,
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 8,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // C. Interactive Overlay Controls (Tengah)
                    if (viewState != MiniPlayerViewState.lyrics && viewState != MiniPlayerViewState.idleLyrics)
                      const Positioned.fill(
                        child: FloatingOverlayControls(),
                      ),

                    // D. Lyrics View overlay
                    if (viewState == MiniPlayerViewState.lyrics || viewState == MiniPlayerViewState.idleLyrics)
                      const Positioned.fill(
                        child: FloatingLyricsView(),
                      ),

                    // E. Top Drag Header Bar
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      top: isHeaderVisible ? 0 : -32,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 32,
                        color: headerColor,
                        child: Stack(
                          children: [
                            // 1. Icon Drag
                            Center(
                              child: Icon(UIcons.regular.grip_lines, color: headerIconColor.withValues(alpha: 0.4), size: 16),
                            ),
                            // 2. Wrap Drag functionality (without double-tap maximize)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanStart: (_) => windowManager.startDragging(),
                                child: const SizedBox(),
                              ),
                            ),
                            
                            Positioned(
                              left: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: ReusableHoverIconButton(
                                  icon: UIcons.regular.add,
                                  onTap: () => _handleAddToPlaylist(context, ref),
                                  tooltip: 'Add to Playlist',
                                  iconSize: 16,
                                  padding: 4,
                                  color: headerIconColor,
                                ),
                              ),
                            ),

                            // 4. Right Controls (Translation & Close)
                            Positioned(
                              right: 4,
                              top: 0,
                              bottom: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (viewState == MiniPlayerViewState.lyrics || viewState == MiniPlayerViewState.idleLyrics)
                                    LyricsTranslationToggle(
                                      fontSize: 10,
                                      padding: 4,
                                      color: headerIconColor,
                                    ),
                                  ReusableHoverIconButton(
                                    icon: UIcons.regular.cross_small,
                                    onTap: (viewState == MiniPlayerViewState.lyrics || viewState == MiniPlayerViewState.idleLyrics)
                                        ? () => Future.microtask(() => popNotifier.setViewState(MiniPlayerViewState.normal))
                                        : () => BlurTransitionOverlay.run(
                                            ref,
                                            () async => popNotifier.togglePop(),
                                          ),
                                    tooltip: (viewState == MiniPlayerViewState.lyrics || viewState == MiniPlayerViewState.idleLyrics) ? 'Close Lyrics' : 'Close Miniplayer',
                                    iconSize: 16,
                                    padding: 4,
                                    color: headerIconColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AREA 2: INFO & NAV BAR (Bottom)
            if (viewState != MiniPlayerViewState.lyrics && viewState != MiniPlayerViewState.idleLyrics)
              const FloatingBottomBar(),
          ],
        ),
      ),
    );
  }
}
