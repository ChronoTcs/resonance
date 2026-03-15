import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/lyrics_provider.dart';
import '../../../player/data/repositories/audio_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const LyricsScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _currentIndex = -1;
  double _listHeight = 600.0; // Default fallback

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    if (_itemScrollController.isAttached && index >= 0) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
        alignment: 0.5, // Precisely center the item
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final audioState = ref.watch(audioProvider);

    if (lyricsState.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (lyricsState.error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'Error loading lyrics: \${lyricsState.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (lyricsState.lyrics.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'No lyrics found for this track',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ),
      );
    }

    // Determine current lyric index based on audio position
    int newIndex = -1;
    for (int i = 0; i < lyricsState.lyrics.length; i++) {
      if (audioState.position >= lyricsState.lyrics[i].timestamp) {
        newIndex = i;
      } else {
        break; // Stop since lines are sorted
      }
    }

    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLyric(_currentIndex);
      });
    }

    return Container(
      height: widget.isEmbedded
          ? double.infinity
          : MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.isEmbedded
            ? Colors.transparent
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: widget.isEmbedded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!widget.isEmbedded) ...[
              // Drag handle indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // balance close button
                  ],
                ),
              ),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _listHeight = constraints.maxHeight;
                    return ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: _listHeight / 2 - 30,
                        bottom: _listHeight / 2,
                      ),
                      itemCount: lyricsState.lyrics.length,
                      itemBuilder: (context, index) {
                        final line = lyricsState.lyrics[index];
                        final isActive = index == _currentIndex;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            line.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isActive ? 26 : 18,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isActive
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
