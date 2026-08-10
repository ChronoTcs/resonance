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
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = isLight
        ? theme.colorScheme.surface.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.85);
    final textColor = theme.colorScheme.onSurface;

    return PageStorage(
      bucket: PageStorageBucket(),
      child: Container(
        color: backgroundColor,
        child: Column(
          children: [
            Expanded(
              child: lyrics.isEmpty
                  ? Center(
                      child: Text(
                        'Lyrics unavailable',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.54),
                        ),
                      ),
                    )
                  : LyricsListView(compact: true, textColor: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
