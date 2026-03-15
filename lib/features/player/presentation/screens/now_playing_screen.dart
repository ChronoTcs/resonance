import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/library/data/repositories/library_provider.dart';
import 'package:resonance_app/features/lyrics/presentation/widgets/lyrics_screen.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
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
        title: Text(
          'Now Playing',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        centerTitle: true,
        actions: [
          // Add to Playlist
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add to playlist',
            onPressed: () =>
                _showMediaActions(context, track),
          ),
          IconButton(
            tooltip: 'Audio Settings',
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
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
                        Text(
                          'Playback Speed',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final currentAudioState = ref.watch(audioProvider);
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

                        // Pitch Control
                        Text(
                          'Pitch',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final currentAudioState = ref.watch(audioProvider);
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

                        // Equalizer Placeholder Button
                        const SizedBox(height: 10),
                        ListTile(
                          leading: Icon(
                            Icons.equalizer,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          title: const Text('Equalizer Settings'),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor,
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
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: MediaArtworkWidget(
                              item: track,
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 20,
                              placeholderIcon: Icons.music_note,
                            ),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      thumbColor: Theme.of(context).primaryColor,
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

                  // Timers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(audioState.position),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatDuration(audioState.duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Responsive Controls Layout
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth > 500;
                      
                      if (isDesktop) {
                        return Row(
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
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              tooltip: 'Shuffle',
                              icon: Icon(
                                Icons.shuffle,
                                color: audioState.isShuffleEnabled
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                              onPressed: () => audioNotifier.toggleShuffle(),
                            ),
                            // Previous
                            IconButton(
                              tooltip: 'Previous',
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
                              child: audioState.isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: audioState.isPlaying ? 'Pause' : 'Play',
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
                              tooltip: 'Next',
                              icon: const Icon(Icons.skip_next, size: 28),
                              onPressed: () => audioNotifier.skipToNext(),
                            ),
                            // Repeat
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
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
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
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
                        );
                      } else {
                        return Column(
                          children: [
                            // Secondary Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
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
                                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                                    style: TextStyle(
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                // Lyrics Toggle
                                IconButton(
                                  icon: Icon(
                                    Icons.lyrics_outlined,
                                    color: _showLyrics
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                            const SizedBox(height: 10),
                            // Primary Transport Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Shuffle
                                IconButton(
                                  tooltip: 'Shuffle',
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: audioState.isShuffleEnabled
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                  onPressed: () => audioNotifier.toggleShuffle(),
                                ),
                                // Previous
                                IconButton(
                                  tooltip: 'Previous',
                                  icon: const Icon(Icons.skip_previous, size: 28),
                                  onPressed: () => audioNotifier.skipToPrevious(),
                                ),
                                // Play/Pause
                                Container(
                                  width: 64,
                                  height: 64,
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
                                  child: audioState.isLoading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: audioState.isPlaying ? 'Pause' : 'Play',
                                          icon: Icon(
                                            audioState.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: 36,
                                            color: Theme.of(context).colorScheme.surface,
                                          ),
                                          onPressed: () => audioNotifier.togglePlayPause(),
                                        ),
                                ),
                                // Next
                                IconButton(
                                  tooltip: 'Next',
                                  icon: const Icon(Icons.skip_next, size: 28),
                                  onPressed: () => audioNotifier.skipToNext(),
                                ),
                                // Repeat
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
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).primaryColor,
                                    size: 22,
                                  ),
                                  onPressed: () => audioNotifier.cycleLoopMode(),
                                ),
                              ],
                            ),
                          ]
                        );
                      }
                    },
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

  void _showMediaActions(
    BuildContext context,
    MediaItem track,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: track,
        onDelete: track.id == null
            ? () => _confirmDelete(context, track)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, MediaItem item) {
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
