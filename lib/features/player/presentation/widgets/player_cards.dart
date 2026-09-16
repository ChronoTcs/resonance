import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_retry_button.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_offset_control.dart';
import 'package:resonance/core/utils/formatters.dart';

import 'package:resonance/features/player/data/models/player_enums.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_translation_toggle.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_list_view.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

class MetadataCard extends StatelessWidget {
  final dynamic track;
  final double? height;
  const MetadataCard({super.key, required this.track, this.height});

  @override
  Widget build(BuildContext context) {
    if (track == null) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          _InfoLine(label: 'Year', value: _formatYear(track.date)),
      ],
    );

    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight.isFinite) {
              return isMobile
                  ? SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: content,
                    )
                  : SilkySingleChildScrollView(child: content);
            }
            return content;
          },
        ),
      ),
    );
  }

  String _formatYear(String rawDate) {
    final trimmed = rawDate.trim();
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
    }
    return trimmed;
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
  final UniqueKey _silkyLockKey = UniqueKey();

  @override
  void dispose() {
    SilkyScrollGlobalManager.instance.detachKey(_silkyLockKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final translationState = ref.watch(lyricsTranslationProvider);
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => SilkyScrollGlobalManager.instance.enteredKey(_silkyLockKey),
        onExit: (_) => SilkyScrollGlobalManager.instance.exitKey(_silkyLockKey),
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
                _MiniLyricsCardHeader(
                  lyricsState: lyricsState,
                  translationState: translationState,
                  onExpandTap: () =>
                      ref.read(lyricsOverlayProvider.notifier).toggle(),
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: LyricsListView(compact: true),
                ),
              ],
            ),

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
    final next = ref.watch(audioProvider.select((s) =>
        s.nextTrack ??
        ((s.currentIndex >= 0 && s.currentIndex < s.queue.length - 1)
            ? s.queue[s.currentIndex + 1]
            : null)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => ref.read(queueOverlayProvider.notifier).toggle(),
          onSecondaryTapDown: next != null
              ? (details) => MediaActionUtils.showTrackContextMenu(
                    context: context,
                    ref: ref,
                    item: next,
                    position: details.globalPosition,
                  )
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    Flexible(
                      child: Text(
                        'Next in queue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () => ref.read(queueOverlayProvider.notifier).toggle(),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open queue',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              UIcons.regular.angle_small_right,
                              size: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
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
                            ResonanceMarqueeText(
                              text: next.title,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              next.artist ?? 'Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationControlCard extends ConsumerStatefulWidget {
  /// When true, shows seek slider + timestamps instead of volume slider.
  /// Intended for the Android Now Playing full-screen view.
  final bool showSeekSlider;
  const NavigationControlCard({super.key, this.showSeekSlider = false});
  @override
  ConsumerState<NavigationControlCard> createState() =>
      _NavigationControlCardState();
}

class _NavigationControlCardState extends ConsumerState<NavigationControlCard> {
  double _prevVolume = 100.0;
  @override
  Widget build(BuildContext context) {
    final volume = ref.watch(audioProvider.select((s) => s.volume));
    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));
    final isShuffleEnabled =
        ref.watch(audioProvider.select((s) => s.isShuffleEnabled));
    final loopMode = ref.watch(audioProvider.select((s) => s.loopMode));
    final isPreviousDisabled =
        ref.watch(audioProvider.select((s) => s.currentIndex <= 0));
    final isNextDisabled = ref.watch(audioProvider.select(
      (s) => s.currentIndex >= s.queue.length - 1 && s.loopMode == LoopMode.off,
    ));

    final audioNotifier = ref.read(audioProvider.notifier);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isLight
              ? Colors.white.withValues(alpha: 0.65)
              : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showSeekSlider) const _SeekSliderRow(),
            if (widget.showSeekSlider) const SizedBox(height: 12),
            _PlaybackActionButtonsRow(
              isShuffleEnabled: isShuffleEnabled,
              isPreviousDisabled: isPreviousDisabled,
              isPlaying: isPlaying,
              isLoading: isLoading,
              isNextDisabled: isNextDisabled,
              loopMode: loopMode,
              audioNotifier: audioNotifier,
            ),
            const SizedBox(height: 20),
            _VolumeSliderRow(
              volume: volume,
              onVolumeChanged: (v) {
                audioNotifier.setVolume(v);
                if (v > 0) _prevVolume = v;
              },
              onMuteToggle: () {
                if (volume > 0) {
                  _prevVolume = volume;
                  audioNotifier.setVolume(0);
                } else {
                  audioNotifier.setVolume(
                    _prevVolume > 0 ? _prevVolume : 100,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Seek slider row with position / duration timestamps.
/// Consumes [audioProvider] directly so it rebuilds every tick,
/// keeping it isolated from the rest of the card.
class _SeekSliderRow extends ConsumerWidget {
  const _SeekSliderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(audioProvider.select((s) => s.position));
    final dur = ref.watch(audioProvider.select((s) => s.duration));
    final audioNotifier = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface.withValues(alpha: 0.5),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReusableSeekSlider(
          value: pos.inMilliseconds.toDouble(),
          max: dur.inMilliseconds.toDouble() > 0
              ? dur.inMilliseconds.toDouble()
              : 1.0,
          trackHeight: 4,
          height: 28,
          onChanged: (_) {},
          onChangeEnd: (val) {
            audioNotifier.seek(Duration(milliseconds: val.toInt()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppFormatters.formatDuration(pos), style: labelStyle),
              Text(AppFormatters.formatDuration(dur), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniLyricsCardHeader extends StatelessWidget {
  final LyricsState lyricsState;
  final LyricsTranslationState translationState;
  final VoidCallback onExpandTap;

  const _MiniLyricsCardHeader({
    required this.lyricsState,
    required this.translationState,
    required this.onExpandTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                  modeLabel: translationState.mode ==
                          LyricsTranslationMode.translated
                      ? 'Translation'
                      : 'Romanization',
                ),
              ],
            ],
          ],
        ),
        const Spacer(),
        const LyricsOffsetControl(compact: true),
        const SizedBox(width: 12),
        ReusableHoverIconButton(
          icon: UIcons.regular.expand,
          tooltip: 'Show Full Lyrics',
          iconSize: 16,
          onTap: onExpandTap,
        ),
      ],
    );
  }
}

class _PlaybackActionButtonsRow extends StatelessWidget {
  final bool isShuffleEnabled;
  final bool isPreviousDisabled;
  final bool isPlaying;
  final bool isLoading;
  final bool isNextDisabled;
  final LoopMode loopMode;
  final AudioNotifier audioNotifier;

  const _PlaybackActionButtonsRow({
    required this.isShuffleEnabled,
    required this.isPreviousDisabled,
    required this.isPlaying,
    required this.isLoading,
    required this.isNextDisabled,
    required this.loopMode,
    required this.audioNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ReusableHoverIconButton(
          tooltip: 'Shuffle',
          icon: UIcons.regular.shuffle,
          iconSize: 20,
          isSelected: false,
          color: isShuffleEnabled
              ? theme.primaryColor
              : colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: audioNotifier.toggleShuffle,
        ),
        ReusableHoverIconButton(
          tooltip: 'Previous',
          icon: UIcons.regular.step_backward,
          iconSize: 32,
          isDisabled: isPreviousDisabled,
          onTap: audioNotifier.skipToPrevious,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        PlayPauseButton(
          isPlaying: isPlaying,
          isLoading: isLoading,
          size: PlayPauseSize.medium,
          color: theme.primaryColor,
          onTap: audioNotifier.togglePlayPause,
        ),
        ReusableHoverIconButton(
          tooltip: 'Next',
          icon: UIcons.regular.step_forward,
          iconSize: 32,
          isDisabled: isNextDisabled,
          onTap: audioNotifier.skipToNext,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        ReusableHoverIconButton(
          tooltip: loopMode == LoopMode.one
              ? 'Repeat One'
              : loopMode == LoopMode.all
              ? 'Repeat All'
              : 'Repeat Off',
          icon: loopMode == LoopMode.one
              ? UIcons.regular.arrows_repeat_1
              : UIcons.regular.arrows_repeat,
          iconSize: 20,
          isSelected: false,
          color: loopMode != LoopMode.off
              ? theme.primaryColor
              : colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: audioNotifier.cycleLoopMode,
        ),
      ],
    );
  }
}

class _VolumeSliderRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggle;

  const _VolumeSliderRow({
    required this.volume,
    required this.onVolumeChanged,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          ReusableHoverIconButton(
            tooltip: 'Volume',
            icon: volume == 0
                ? UIcons.regular.volume_off
                : volume < 50
                ? UIcons.regular.volume_down
                : UIcons.regular.volume,
            iconSize: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            onTap: onMuteToggle,
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
                inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.2),
                thumbColor: colorScheme.primary,
              ),
              child: Slider(
                value: volume,
                min: 0,
                max: 100,
                onChanged: onVolumeChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${volume.toInt()}%',
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
    );
  }
}

