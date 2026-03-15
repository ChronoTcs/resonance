import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/library/data/repositories/library_provider.dart';
import '../screens/now_playing_screen.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
import '../../../lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'equalizer_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    if (audioState.currentTrack == null) {
      return const SizedBox.shrink();
    }

    final track = audioState.currentTrack!;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
        );
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Seekbar
            SizedBox(
              height: 10,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: audioState.position.inSeconds.toDouble().clamp(
                    0.0,
                    audioState.duration.inSeconds.toDouble() > 0
                        ? audioState.duration.inSeconds.toDouble()
                        : (audioState.position.inSeconds.toDouble() > 0
                            ? audioState.position.inSeconds.toDouble()
                            : 1.0),
                  ),
                  max: audioState.duration.inSeconds.toDouble() > 0
                      ? audioState.duration.inSeconds.toDouble()
                      : (audioState.position.inSeconds.toDouble() > 0
                          ? audioState.position.inSeconds.toDouble()
                          : 1.0),
                  onChanged: (val) {
                    audioNotifier.seek(Duration(seconds: val.toInt()));
                  },
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth > 500;

                  return Row(
                    children: [
                      // Album Art
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: MediaArtworkWidget(
                          item: track,
                          width: 48,
                          height: 48,
                          borderRadius: 4,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track Info
                      Expanded(
                        flex: isDesktop ? 2 : 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isDesktop)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "${_formatDuration(audioState.position)} / ${_formatDuration(audioState.duration)}",
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Core Controls
                      if (isDesktop)
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Shuffle',
                                icon: Icon(
                                  Icons.shuffle,
                                  color: audioState.isShuffleEnabled
                                      ? Theme.of(context).primaryColor
                                      : Theme.of(context).iconTheme.color?.withOpacity(0.5),
                                  size: 20,
                                ),
                                onPressed: () => audioNotifier.toggleShuffle(),
                              ),
                              IconButton(
                                tooltip: 'Previous',
                                icon: const Icon(Icons.skip_previous, size: 24),
                                onPressed: () => audioNotifier.skipToPrevious(),
                              ),
                              audioState.isLoading
                                  ? SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: audioState.isPlaying ? 'Pause' : 'Play',
                                      icon: Icon(
                                        audioState.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled,
                                        size: 36,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      onPressed: () => audioNotifier.togglePlayPause(),
                                    ),
                              IconButton(
                                tooltip: 'Next',
                                icon: const Icon(Icons.skip_next, size: 24),
                                onPressed: () => audioNotifier.skipToNext(),
                              ),
                              IconButton(
                                tooltip: audioState.loopMode == LoopMode.off 
                                    ? 'Repeat Off' 
                                    : audioState.loopMode == LoopMode.one 
                                        ? 'Repeat One' 
                                        : 'Repeat All',
                                icon: Icon(
                                  audioState.loopMode == LoopMode.one
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                  color: audioState.loopMode == LoopMode.off
                                      ? Theme.of(context).iconTheme.color?.withOpacity(0.5)
                                      : Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                onPressed: () => audioNotifier.cycleLoopMode(),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            audioState.isLoading
                                ? SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: audioState.isPlaying ? 'Pause' : 'Play',
                                    icon: Icon(
                                      audioState.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      size: 36,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    onPressed: () => audioNotifier.togglePlayPause(),
                                  ),
                            IconButton(
                              tooltip: 'Next',
                              icon: const Icon(Icons.skip_next, size: 24),
                              onPressed: () => audioNotifier.skipToNext(),
                            ),
                          ],
                        ),

                      // Quick add-to-playlist button (always visible)
                      IconButton(
                        icon: const Icon(Icons.playlist_add, size: 20),
                        tooltip: 'Media actions',
                        onPressed: () => _showMediaActions(
                          context,
                          ref,
                          track,
                        ),
                      ),

                      // Extra actions - Only visible on wide screens
                      if (isDesktop)
                        Expanded(
                          flex: 3, // slightly bumped up flex to prevent too much scaling
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                              Text(
                                "${_formatDuration(audioState.position)} / ${_formatDuration(audioState.duration)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (buttonContext) {
                                  return IconButton(
                                    tooltip: 'Volume',
                                    icon: Icon(
                                      audioState.volume == 0
                                          ? Icons.volume_off
                                          : audioState.volume < 50
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                      color: Theme.of(context).iconTheme.color?.withOpacity(0.56),
                                    ),
                                    onPressed: () {
                                      final RenderBox renderBox =
                                          buttonContext.findRenderObject()
                                              as RenderBox;
                                      final offset = renderBox.localToGlobal(
                                        Offset.zero,
                                      );
                                      final buttonSize = renderBox.size;

                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        builder: (context) {
                                          const double dialogWidth = 300;
                                          const double dialogHeight = 64;

                                          double left =
                                              offset.dx -
                                              (dialogWidth / 2) +
                                              (buttonSize.width / 2);
                                          final screenWidth = MediaQuery.of(
                                            context,
                                          ).size.width;
                                          if (left < 16) left = 16;
                                          if (left + dialogWidth >
                                              screenWidth - 16) {
                                            left =
                                                screenWidth - dialogWidth - 16;
                                          }

                                          double top =
                                              offset.dy - dialogHeight - 16;

                                          return Stack(
                                            children: [
                                              Positioned(
                                                left: left,
                                                top: top,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    width: dialogWidth,
                                                    height: dialogHeight,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          blurRadius: 10,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16.0,
                                                          ),
                                                      child: Consumer(
                                                        builder: (context, ref, _) {
                                                          final state = ref
                                                              .watch(
                                                                audioProvider,
                                                              );
                                                          return Row(
                                                            children: [
                                                              Icon(
                                                                state.volume ==
                                                                        0
                                                                    ? Icons
                                                                          .volume_off
                                                                    : state.volume <
                                                                          50
                                                                    ? Icons
                                                                          .volume_down
                                                                    : Icons
                                                                          .volume_up,
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: SliderTheme(
                                                                  data: SliderTheme.of(context).copyWith(
                                                                    activeTrackColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).primaryColor,
                                                                    inactiveTrackColor: Colors
                                                                        .grey
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                    thumbColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).primaryColor,
                                                                    thumbShape:
                                                                        const RoundSliderThumbShape(
                                                                          enabledThumbRadius:
                                                                              6,
                                                                        ),
                                                                    trackHeight:
                                                                        4,
                                                                    overlayShape:
                                                                        SliderComponentShape
                                                                            .noOverlay,
                                                                  ),
                                                                  child: Slider(
                                                                    value: state
                                                                        .volume,
                                                                    min: 0.0,
                                                                    max: 100.0,
                                                                    onChanged: (val) => ref
                                                                        .read(
                                                                          audioProvider
                                                                              .notifier,
                                                                        )
                                                                        .setVolume(
                                                                          val,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              SizedBox(
                                                                width: 28,
                                                                child: Text(
                                                                  state.volume
                                                                      .toInt()
                                                                      .toString(),
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    fontSize: 13,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              Consumer(
                                builder: (context, consumerRef, child) {
                                  final isLyricsOpen = consumerRef.watch(
                                    lyricsOverlayProvider,
                                  );
                                  return IconButton(
                                    tooltip: "Lyrics",
                                    icon: Icon(
                                      Icons.lyrics_outlined,
                                      color: isLyricsOpen
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).iconTheme.color?.withOpacity(0.56),
                                    ),
                                    onPressed: () {
                                      consumerRef
                                          .read(lyricsOverlayProvider.notifier)
                                          .toggle();
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Theme.of(context).iconTheme.color?.withOpacity(0.56),
                                ),
                                tooltip: 'Audio Settings',
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 24.0,
                                          horizontal: 16.0,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Audio Settings',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              'Playback Speed',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    Text(
                                                      '0.5x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Slider(
                                                        value: state.speed,
                                                        min: 0.5,
                                                        max: 2.0,
                                                        divisions: 15,
                                                        label:
                                                            '${state.speed.toStringAsFixed(1)}x',
                                                        activeColor: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        onChanged: (val) => ref
                                                            .read(
                                                              audioProvider
                                                                  .notifier,
                                                            )
                                                            .setSpeed(val),
                                                      ),
                                                    ),
                                                    Text(
                                                      '2.0x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Pitch',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    Text(
                                                      '-12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Slider(
                                                        value: state.pitch,
                                                        min: -12.0,
                                                        max: 12.0,
                                                        divisions: 24,
                                                        label: state.pitch
                                                            .toStringAsFixed(1),
                                                        activeColor: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        onChanged: (val) => ref
                                                            .read(
                                                              audioProvider
                                                                  .notifier,
                                                            )
                                                            .setPitch(val),
                                                      ),
                                                    ),
                                                    Text(
                                                      '+12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            ListTile(
                                              leading: Icon(
                                                Icons.equalizer,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              title: const Text(
                                                'Equalizer Settings',
                                              ),
                                              trailing: Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                              ),
                                              onTap: () {
                                                Navigator.pop(context);
                                                showModalBottomSheet(
                                                  context: context,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  isScrollControlled: true,
                                                  builder: (context) =>
                                                      const EqualizerSheet(),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaActions(
    BuildContext context,
    WidgetRef ref,
    MediaItem track,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: track,
        onDelete: track.id == null
            ? () => _confirmDelete(context, ref, track)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Permanently delete "${item.title}" from your device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dlg);
              ref.read(libraryProvider.notifier).deleteTrack(item.path);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${item.title}" deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
