import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:resonance_app/features/player/application/audio_provider.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance_app/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';
import 'package:resonance_app/features/player/data/models/player_enums.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';
import 'dart:ui';
class MetadataCard extends StatelessWidget {
  final dynamic track;
  final double? height;
  const MetadataCard({super.key, required this.track, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withOpacity(0.4)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white)
              .withOpacity(0.1),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track Info', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, 
              fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _InfoLine(label: 'Title', value: track.title),
            _InfoLine(label: 'Artist', value: track.artist ?? 'Unknown Artist'),
            _InfoLine(label: 'Album', value: track.album ?? 'Unknown Album'),
            if (track.date != null && track.date.isNotEmpty) _InfoLine(label: 'Date', value: track.date),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label, value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), 
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface, 
            fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class MiniLyricsCard extends ConsumerStatefulWidget {
  final double? height;
  const MiniLyricsCard({super.key, this.height});

  @override
  ConsumerState<MiniLyricsCard> createState() => _MiniLyricsCardState();
}

class _MiniLyricsCardState extends ConsumerState<MiniLyricsCard> {
  final ItemScrollController _itemScrollController = ItemScrollController();

  void _scrollToActiveLyric(int index) {
    if (!mounted) return;

    // GUARD: Don't attempt to scroll if lyrics are empty
    final lyrics = ref.read(displayLyricsProvider);
    if (lyrics.isEmpty) return;

    // Use post-frame callback to ensure the list is fully attached and laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_itemScrollController.isAttached && index >= 0) {
        try {
          _itemScrollController.scrollTo(
            index: index + 1, // +1 for top spacer
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastOutSlowIn,
            alignment: 0.45,
          );
        } catch (e) {
          // Catch all Objects (including Errors/Assertions) to prevent crashes
          debugPrint('MiniLyricsCard: Scroll suppressed - $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final translationState = ref.watch(lyricsTranslationProvider);
    final lyrics = ref.watch(displayLyricsProvider);
    final activeIndex = ref.watch(activeLyricIndexProvider);

    ref.listen<int>(activeLyricIndexProvider, (prev, next) {
      if (next != -1 && next != prev) {
        _scrollToActiveLyric(next);
      }
    });

    return GestureDetector(
      onTap: () {
        ref.read(lyricsOverlayProvider.notifier).toggle();
      },
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white)
                .withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Lyrics', style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface, 
                      fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    if (translationState.isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (lyricsState.lyrics.isNotEmpty && translationState.isSystemEnabled)
                      _buildTranslationToggle(context, translationState),
                  ],
                ),
                ModernIconButton(
                  icon: const Icon(Icons.open_in_full),
                  iconSize: 14,
                  onPressed: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: lyrics.isNotEmpty
                  ? ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent, 
                            Colors.white, 
                            Colors.white, 
                            Colors.transparent
                          ],
                          stops: const [0.0, 0.1, 0.85, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: lyrics.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) return const SizedBox(height: 150);
                          if (index == lyrics.length + 1) return const SizedBox(height: 150);
                          
                          final line = lyrics[index - 1];
                          final isActive = (index - 1) == activeIndex;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                color: isActive 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                fontSize: isActive ? 18 : 15,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                height: 1.4,
                              ),
                              child: Text(line.text),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        'No lyrics available',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationToggle(BuildContext context, LyricsTranslationState state) {
    final bool isActive = state.mode != LyricsTranslationMode.original;
    String label = state.targetLanguage.toUpperCase();
    if (state.mode == LyricsTranslationMode.romanized) {
      label = 'ROM';
    } else if (state.mode == LyricsTranslationMode.translated) {
      label = 'TRN';
    }

    return HoverWrapper(
      onTap: () => ref.read(lyricsTranslationProvider.notifier).cycleMode(),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive 
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Theme.of(context).colorScheme.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive 
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive 
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

class NextInQueueCard extends ConsumerWidget {
  final double? height;
  const NextInQueueCard({super.key, this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(audioProvider.select((s) => s.nextTrack));
    
    return GestureDetector(
      onTap: () {}, // Make tooltip or tap action if needed
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white)
                .withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Next in queue', style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, 
                  fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Open queue', style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            // Stable structure: Always show a builder or a fixed child
            Builder(
              builder: (context) {
                if (next == null) {
                  return Text('No tracks in queue', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)));
                }
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: MediaArtworkWidget(item: next),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(next.title, style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface, 
                            fontWeight: FontWeight.bold), maxLines: 1),
                          Text(next.artist ?? 'Artist', style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationControlCard extends ConsumerStatefulWidget {
  const NavigationControlCard({super.key});

  @override
  ConsumerState<NavigationControlCard> createState() => _NavigationControlCardState();
}

class _NavigationControlCardState extends ConsumerState<NavigationControlCard> {
  double _prevVolume = 100.0;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    Widget buildActionButton({
      required IconData icon,
      required bool isActive,
      required VoidCallback onPressed,
      double size = 24,
    }) {
      return GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
            color: isActive ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: size,
            color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isLight 
            ? Colors.white.withOpacity(0.4) 
            : Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight 
              ? Colors.white.withOpacity(0.5) 
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Main Playback Controls (Now on TOP)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildActionButton(
                      icon: Icons.shuffle,
                      isActive: audioState.isShuffleEnabled,
                      onPressed: audioNotifier.toggleShuffle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 36),
                      onPressed: audioNotifier.skipToPrevious,
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                    GestureDetector(
                      onTap: audioNotifier.togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          audioState.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 36,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 36),
                      onPressed: audioNotifier.skipToNext,
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                    buildActionButton(
                      icon: audioState.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                      isActive: audioState.loopMode != LoopMode.off,
                      onPressed: audioNotifier.cycleLoopMode,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 2. Volume Slider Row (Now on BOTTOM)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (audioState.volume > 0) {
                            _prevVolume = audioState.volume;
                            audioNotifier.setVolume(0);
                          } else {
                            audioNotifier.setVolume(_prevVolume > 0 ? _prevVolume : 100);
                          }
                        },
                        child: Icon(
                          audioState.volume == 0 
                              ? Icons.volume_off 
                              : audioState.volume < 50 
                                  ? Icons.volume_down 
                                  : Icons.volume_up,
                          size: 20,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: colorScheme.primary,
                            inactiveTrackColor: colorScheme.primary.withOpacity(0.2),
                            thumbColor: colorScheme.primary,
                          ),
                          child: Slider(
                            value: audioState.volume,
                            min: 0,
                            max: 100,
                            onChanged: (v) {
                              audioNotifier.setVolume(v);
                              if (v > 0) _prevVolume = v;
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${audioState.volume.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
