import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audio_provider.dart';
import '../screens/now_playing_screen.dart';
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
                  value: audioState.position.inSeconds.toDouble(),
                  max: audioState.duration.inSeconds.toDouble() > 0
                      ? audioState.duration.inSeconds.toDouble()
                      : 1.0,
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
                      track.albumArt != null
                          ? Container(
                              width: 48,
                              height: 48,
                              margin: const EdgeInsets.only(left: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  track.albumArt!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                      const SizedBox(width: 12),

                      // Track Info
                      Expanded(
                        flex: isDesktop ? 2 : 3,
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
                                color: Colors.grey[400],
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
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Core Controls
                      Expanded(
                        flex: isDesktop ? 3 : 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isDesktop)
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: audioState.isShuffleEnabled
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => audioNotifier.toggleShuffle(),
                              ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous, size: 24),
                              onPressed: () => audioNotifier.skipToPrevious(),
                            ),
                            IconButton(
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
                              icon: const Icon(Icons.skip_next, size: 24),
                              onPressed: () => audioNotifier.skipToNext(),
                            ),
                            if (isDesktop)
                              IconButton(
                                icon: Icon(
                                  audioState.loopMode == LoopMode.one
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                  color: audioState.loopMode == LoopMode.off
                                      ? Colors.grey
                                      : Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                onPressed: () => audioNotifier.cycleLoopMode(),
                              ),
                          ],
                        ),
                      ),

                      // Extra actions - Only visible on wide screens
                      if (isDesktop)
                        Expanded(
                          flex: 2,
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
                                      color: Colors.white54,
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
                                                                color:
                                                                    Colors.grey,
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
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        13,
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
                                          : Colors.white54,
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
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white54,
                                ),
                                tooltip: 'Audio Settings',
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.grey[900],
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
                                            const Text(
                                              'Playback Speed',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    const Text(
                                                      '0.5x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white54,
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
                                                    const Text(
                                                      '2.0x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Pitch',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    const Text(
                                                      '-12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white54,
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
                                                    const Text(
                                                      '+12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.equalizer,
                                                color: Colors.white,
                                              ),
                                              title: const Text(
                                                'Equalizer Settings',
                                              ),
                                              trailing: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.white54,
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
}
