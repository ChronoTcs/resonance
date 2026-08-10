import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../application/lyrics_provider.dart';
import '../../application/lyrics_translation_provider.dart';
import 'word_synced_lyric_row.dart';
import '../../../../core/theme/theme_provider.dart';

class LyricsListView extends ConsumerStatefulWidget {
  final bool compact;
  final ScrollPhysics? physics;
  final Color? textColor;

  const LyricsListView({
    super.key,
    this.compact = false,
    this.physics,
    this.textColor,
  });

  @override
  ConsumerState<LyricsListView> createState() => _LyricsListViewState();
}

class _LyricsListViewState extends ConsumerState<LyricsListView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _currentIndex = -1;
  double _listHeight = 600.0;

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    if (_itemScrollController.isAttached && index >= 0) {
      final targetIndex = widget.compact ? index + 3 : index;
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
        alignment: widget.compact ? 0.45 : 0.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final lyrics = ref.watch(displayLyricsProvider);
    final activeIndex = ref.watch(activeLyricIndexProvider);
    final activeOpacity = ref.watch(lyricsActiveOpacityProvider);
    final inactiveOpacity = ref.watch(lyricsInactiveOpacityProvider);

    if (lyricsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lyricsState.error != null && lyrics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error loading lyrics: ${lyricsState.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final effectiveTextColor =
        widget.textColor ?? Theme.of(context).colorScheme.onSurface;

    if (lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics found for this track',
          style: TextStyle(
            color: effectiveTextColor.withValues(
              alpha: widget.compact ? 0.38 : 0.54,
            ),
            fontSize: widget.compact ? 12 : 18,
          ),
        ),
      );
    }

    // Auto-scroll trigger
    if (activeIndex != _currentIndex) {
      _currentIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLyric(_currentIndex);
      });
    }

    if (widget.compact) {
      return ShaderMask(
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
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          initialScrollIndex: activeIndex != -1 ? activeIndex + 3 : 0,
          initialAlignment: 0.45,
          itemCount: lyrics.length + 6,
          physics: widget.physics ?? const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            if (index < 3 || index >= lyrics.length + 3) {
              return const SizedBox(height: 48);
            }

            final lineIndex = index - 3;
            final line = lyrics[lineIndex];
            final isActive = lineIndex == activeIndex;

            final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: WordSyncedLyricRow(
                line: line,
                playerPosition: adjustedPosition,
                isActive: isActive,
                activeOpacity: activeOpacity,
                inactiveOpacity: inactiveOpacity,
                fontSizeActive: 18,
                fontSizeInactive: 14,
                textColor: effectiveTextColor,
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _listHeight = constraints.maxHeight;
        final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);
        return RepaintBoundary(
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: activeIndex != -1 ? activeIndex : 0,
            initialAlignment: 0.5,
            physics: widget.physics ?? const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: _listHeight / 2 - 30,
              bottom: _listHeight / 2,
            ),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isActive = index == activeIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: WordSyncedLyricRow(
                  line: line,
                  playerPosition: adjustedPosition,
                  isActive: isActive,
                  activeOpacity: activeOpacity,
                  inactiveOpacity: inactiveOpacity,
                  fontSizeActive: 26,
                  fontSizeInactive: 18,
                  textColor: effectiveTextColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
