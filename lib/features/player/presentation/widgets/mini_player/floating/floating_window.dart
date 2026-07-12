import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/widgets/blur_transition_overlay.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_bottom_bar.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_overlay_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_lyrics_view.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_translation_toggle.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';

class FloatingWindow extends ConsumerStatefulWidget {
  const FloatingWindow({super.key});

  @override
  ConsumerState<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends ConsumerState<FloatingWindow> {
  Future<void> _handleAddToLibrary() async {
    final track = ref.read(currentTrackProvider);
    if (track == null) return;

    final playlistState = ref.read(playlistProvider).value;
    if (playlistState == null) return;
    
    final List<Playlist> localPlaylists = (playlistState.local as List).cast<Playlist>();
    final notifier = ref.read(playlistProvider.notifier);
    
    String likedId;
    try {
      likedId = localPlaylists.firstWhere((p) => p.name == 'Liked Songs').id;
    } catch (_) {
      await notifier.createPlaylist('Liked Songs');
      await Future.delayed(const Duration(milliseconds: 200));
      final updatedState = ref.read(playlistProvider).value;
      likedId = updatedState?.local.firstWhere((p) => p.name == 'Liked Songs').id ?? '';
    }

    if (likedId.isNotEmpty) {
      await notifier.addTrackToPlaylist(likedId, track);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.title}" to Liked Songs', style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final popState = ref.watch(miniPlayerPopProvider);
    final popNotifier = ref.read(miniPlayerPopProvider.notifier);
    final track = ref.watch(currentTrackProvider);

    if (track == null) return const SizedBox.shrink();

    final viewState = popState.viewState;
    final bool isHeaderVisible = viewState != MiniPlayerViewState.idle && 
                               viewState != MiniPlayerViewState.idleLyrics;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: MouseRegion(
                onEnter: (_) {
                  Future.microtask(() => popNotifier.setViewState(MiniPlayerViewState.hover));
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

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      top: isHeaderVisible ? 0 : -32,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 32,
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        child: Stack(
                          children: [
                            // 1. Icon Drag
                            Center(
                              child: Icon(UIcons.regular.grip_lines, color: Colors.white38, size: 16),
                            ),
                            // 2. Wrap Drag functionality
                            const Positioned.fill(child: DragToMoveArea(child: SizedBox())),
                            
                            Positioned(
                              left: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: ReusableHoverIconButton(
                                  icon: UIcons.regular.add,
                                  onTap: _handleAddToLibrary,
                                  tooltip: 'Add to Library',
                                  iconSize: 16,
                                  padding: 4,
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
                                    const LyricsTranslationToggle(
                                      fontSize: 10,
                                      padding: 4,
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
