import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_list_view.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';

class FloatingLyricsView extends ConsumerStatefulWidget {
  const FloatingLyricsView({super.key});

  @override
  ConsumerState<FloatingLyricsView> createState() => _FloatingLyricsViewState();
}

class _FloatingLyricsViewState extends ConsumerState<FloatingLyricsView> {
  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final lyrics = lyricsState.lyrics;

    return PageStorage(
      bucket: PageStorageBucket(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Column(
          children: [
            Expanded(
              child: lyrics.isEmpty
                  ? const Center(child: Text('Lyrics unavailable', style: TextStyle(color: Colors.white54)))
                  : const LyricsListView(compact: true),
            ),
          ],
        ),
      ),
    );
  }
}
