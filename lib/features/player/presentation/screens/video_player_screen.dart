import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../library/data/models/media_item.dart';
import '../../application/providers/audio_provider.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem videoItem;

  const VideoPlayerScreen({super.key, required this.videoItem});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    // Pause background audio via microtask if it's currently playing
    Future.microtask(() {
      final audioState = ref.read(audioProvider);
      if (audioState.isPlaying) {
        ref.read(audioProvider.notifier).togglePlayPause();
      }
    });

    _player = Player();
    _controller = VideoController(_player);
    // Open the video file
    _player.open(Media(widget.videoItem.path));
    _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.videoItem.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Video(
          controller: _controller,
          // Automatically provides Material/Cupertino based controls built-in to media_kit
        ),
      ),
    );
  }
}
