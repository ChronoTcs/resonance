import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audio_provider.dart';
import '../../../lyrics/presentation/widgets/lyrics_screen.dart';
import '../widgets/equalizer_sheet.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showLyrics = false;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final track = audioState.currentTrack;

    if (track == null) {
      return const Scaffold(body: Center(child: Text('No media playing')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 36),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
            color: Colors.white70,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

                        // Speed Control
                        const Text(
                          'Playback Speed',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final currentAudioState = ref.watch(audioProvider);
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
                                    value: currentAudioState.speed,
                                    min: 0.5,
                                    max: 2.0,
                                    divisions: 15,
                                    label:
                                        currentAudioState.speed.toStringAsFixed(
                                          1,
                                        ) +
                                        'x',
                                    activeColor: Theme.of(context).primaryColor,
                                    onChanged: (val) {
                                      ref
                                          .read(audioProvider.notifier)
                                          .setSpeed(val);
                                    },
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

                        // Pitch Control
                        const Text(
                          'Pitch',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final currentAudioState = ref.watch(audioProvider);
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
                                    value: currentAudioState.pitch,
                                    min: -12.0,
                                    max: 12.0,
                                    divisions: 24,
                                    label: currentAudioState.pitch
                                        .toStringAsFixed(1),
                                    activeColor: Theme.of(context).primaryColor,
                                    onChanged: (val) {
                                      ref
                                          .read(audioProvider.notifier)
                                          .setPitch(val);
                                    },
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

                        // Equalizer Placeholder Button
                        const SizedBox(height: 10),
                        ListTile(
                          leading: const Icon(
                            Icons.equalizer,
                            color: Colors.white,
                          ),
                          title: const Text('Equalizer Settings'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.white54,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => const EqualizerSheet(),
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
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.4),
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Album Art
                  Expanded(
                    flex: 5,
                    child: _showLyrics
                        ? const LyricsScreen(isEmbedded: true)
                        : Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                              image: track.albumArt != null
                                  ? DecorationImage(
                                      image: MemoryImage(track.albumArt!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: track.albumArt == null
                                ? const Icon(
                                    Icons.music_note,
                                    size: 150,
                                    color: Colors.white24,
                                  )
                                : null,
                          ),
                  ),
                  const SizedBox(height: 40),

                  // Song Info
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          track.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Seekbar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
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

                  // Timers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(audioState.position),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatDuration(audioState.duration),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compact Controls Layout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Volume Button
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
                              size: 22,
                            ),
                            onPressed: () {
                              final RenderBox renderBox =
                                  buttonContext.findRenderObject() as RenderBox;
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
                                  if (left + dialogWidth > screenWidth - 16) {
                                    left = screenWidth - dialogWidth - 16;
                                  }

                                  double top = offset.dy - dialogHeight - 16;

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
                                                  BorderRadius.circular(12),
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
                                                  final currentAudioState = ref
                                                      .watch(audioProvider);
                                                  return Row(
                                                    children: [
                                                      Icon(
                                                        currentAudioState
                                                                    .volume ==
                                                                0
                                                            ? Icons.volume_off
                                                            : currentAudioState
                                                                      .volume <
                                                                  50
                                                            ? Icons.volume_down
                                                            : Icons.volume_up,
                                                        color: Colors.grey,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: SliderTheme(
                                                          data: SliderTheme.of(context).copyWith(
                                                            activeTrackColor:
                                                                Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                            inactiveTrackColor:
                                                                Colors.grey
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
                                                            trackHeight: 4,
                                                            overlayShape:
                                                                SliderComponentShape
                                                                    .noOverlay,
                                                          ),
                                                          child: Slider(
                                                            value:
                                                                currentAudioState
                                                                    .volume,
                                                            min: 0.0,
                                                            max: 100.0,
                                                            onChanged: (val) => ref
                                                                .read(
                                                                  audioProvider
                                                                      .notifier,
                                                                )
                                                                .setVolume(val),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 28,
                                                        child: Text(
                                                          currentAudioState
                                                              .volume
                                                              .toInt()
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 13,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
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
                      // Shuffle
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: audioState.isShuffleEnabled
                              ? Theme.of(context).primaryColor
                              : Colors.white54,
                          size: 22,
                        ),
                        onPressed: () => audioNotifier.toggleShuffle(),
                      ),
                      // Previous
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 28),
                        onPressed: () => audioNotifier.skipToPrevious(),
                      ),
                      // Play/Pause
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            audioState.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 32,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          onPressed: () => audioNotifier.togglePlayPause(),
                        ),
                      ),
                      // Next
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 28),
                        onPressed: () => audioNotifier.skipToNext(),
                      ),
                      // Repeat
                      IconButton(
                        icon: Icon(
                          audioState.loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: audioState.loopMode == LoopMode.off
                              ? Colors.white54
                              : Theme.of(context).primaryColor,
                          size: 22,
                        ),
                        onPressed: () => audioNotifier.cycleLoopMode(),
                      ),
                      // Lyrics Toggle
                      IconButton(
                        icon: Icon(
                          Icons.lyrics_outlined,
                          color: _showLyrics
                              ? Theme.of(context).primaryColor
                              : Colors.white54,
                          size: 22,
                        ),
                        tooltip: 'Lyrics',
                        onPressed: () {
                          setState(() {
                            _showLyrics = !_showLyrics;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
