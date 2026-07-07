import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:resonance_app/features/player/application/providers/audio_provider.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance_app/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance_app/features/lyrics/presentation/widgets/lyrics_retry_button.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';
import 'package:resonance_app/features/player/data/models/player_enums.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance_app/core/widgets/play_pause_button.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:resonance_app/features/lyrics/presentation/widgets/lyrics_translation_toggle.dart';

class MetadataCard extends StatelessWidget {
  final dynamic track;
  final double? height;
  const MetadataCard({super.key, required this.track, this.height});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                (Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white)
                    .withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track Info',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _InfoLine(label: 'Title', value: track.title),
              _InfoLine(
                label: 'Artist',
                value: track.artist ?? 'Unknown Artist',
              ),
              _InfoLine(label: 'Album', value: track.album ?? 'Unknown Album'),
              if (track.date != null && track.date.isNotEmpty)
                _InfoLine(label: 'Date', value: track.date),
            ],
          ),
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
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
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
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  void _scrollToActiveLyric(int index) {
    if (!mounted) return;
    final lyrics = ref.read(displayLyricsProvider);
    if (lyrics.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_itemScrollController.isAttached && index >= 0) {
        try {
          _itemScrollController.scrollTo(
            index: index + 3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastOutSlowIn,
            alignment: 0.45,
          );
        } catch (e) {
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

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  (Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white)
                      .withValues(alpha: 0.12),
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
                      Text(
                        'LYRICS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (translationState.isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (lyricsState.lyrics.isNotEmpty &&
                          translationState.isSystemEnabled) ...[
                        const LyricsTranslationToggle(fontSize: 10, padding: 4),
                        if (translationState.error != null) ...[
                          const SizedBox(width: 4),
                          LyricsRetryButton(
                            modeLabel:
                                translationState.mode ==
                                    LyricsTranslationMode.translated
                                ? 'Terjemahan'
                                : 'Romanisasi',
                          ),
                        ],
                      ],
                    ],
                  ),
                  ReusableHoverIconButton(
                    icon: UIcons.regular.expand,
                    tooltip: 'Tampilkan Lirik Penuh',
                    iconSize: 16,
                    onTap: () =>
                        ref.read(lyricsOverlayProvider.notifier).toggle(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.1, 0.9, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: lyricsState.error != null && lyrics.isEmpty
                      ? Center(
                          child: Text(
                            'Gagal memuat lirik',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : lyrics.isEmpty && !lyricsState.isLoading
                      ? const Center(
                          child: Text(
                            'Lirik tidak ditemukan',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          initialScrollIndex: activeIndex != -1
                              ? activeIndex + 3
                              : 0,
                          initialAlignment: 0.45,
                          itemCount: lyrics.length + 6,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            if (index < 3 || index >= lyrics.length + 3) {
                              return const SizedBox(height: 48);
                            }

                            final lineIndex = index - 3;
                            final line = lyrics[lineIndex];
                            final isActive = lineIndex == activeIndex;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontSize: isActive ? 18 : 14,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.32),
                                ),
                                child: Text(line.text),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
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
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.12),
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
              Text(
                'Next in queue',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Open queue',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (next == null)
            Text(
              'No tracks in queue',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          else
            Row(
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
                      Text(
                        next.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        // SOTA V13.13: Removed maxLines to allow vertical expansion
                      ),
                      Text(
                        next.artist ?? 'Artist',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        // SOTA V13.13: Removed maxLines to allow vertical expansion
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class NavigationControlCard extends ConsumerStatefulWidget {
  const NavigationControlCard({super.key});
  @override
  ConsumerState<NavigationControlCard> createState() =>
      _NavigationControlCardState();
}

class _NavigationControlCardState extends ConsumerState<NavigationControlCard> {
  double _prevVolume = 100.0;
  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isLight
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ReusableHoverIconButton(
                        tooltip: 'Shuffle',
                        icon: UIcons.regular.shuffle,
                        // SOTA V3.2: Disabled selection background box
                        isSelected: false,
                        color: audioState.isShuffleEnabled
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                        onTap: audioNotifier.toggleShuffle,
                      ),
                      ReusableHoverIconButton(
                        tooltip: 'Previous',
                        icon: UIcons.regular.step_backward,
                        iconSize: 32,
                        isDisabled: audioState.currentIndex <= 0,
                        onTap: audioNotifier.skipToPrevious,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      PlayPauseButton(
                        isPlaying: audioState.isPlaying,
                        isLoading: audioState.isLoading,
                        size: PlayPauseSize.medium,
                        color: Theme.of(context).primaryColor,
                        onTap: audioNotifier.togglePlayPause,
                      ),
                      ReusableHoverIconButton(
                        tooltip: 'Next',
                        icon: UIcons.regular.step_forward,
                        iconSize: 32,
                        isDisabled:
                            audioState.currentIndex >=
                                audioState.queue.length - 1 &&
                            audioState.loopMode == LoopMode.off,
                        onTap: audioNotifier.skipToNext,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      ReusableHoverIconButton(
                        tooltip: audioState.loopMode == LoopMode.one
                            ? 'Repeat One'
                            : audioState.loopMode == LoopMode.all
                            ? 'Repeat All'
                            : 'Repeat Off',
                        icon: audioState.loopMode == LoopMode.one
                            ? UIcons.regular.arrows_repeat_1
                            : UIcons.regular.arrows_repeat,
                        // SOTA V3.2: Disabled selection background box
                        isSelected: false,
                        color: audioState.loopMode != LoopMode.off
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                        onTap: audioNotifier.cycleLoopMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        ReusableHoverIconButton(
                          tooltip: 'Volume',
                          icon: audioState.volume == 0
                              ? UIcons.regular.volume_off
                              : audioState.volume < 50
                              ? UIcons.regular.volume_down
                              : UIcons.regular.volume,
                          iconSize: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          onTap: () {
                            if (audioState.volume > 0) {
                              _prevVolume = audioState.volume;
                              audioNotifier.setVolume(0);
                            } else {
                              audioNotifier.setVolume(
                                _prevVolume > 0 ? _prevVolume : 100,
                              );
                            }
                          },
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.primary
                                  .withValues(alpha: 0.2),
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
                          width: 44,
                          child: Text(
                            '${audioState.volume.toInt()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
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
      ),
    );
  }
}
