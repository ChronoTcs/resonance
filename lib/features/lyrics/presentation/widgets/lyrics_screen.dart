import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/lyrics_provider.dart';
import '../../../player/application/audio_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';
import '../providers/lyrics_ui_provider.dart';
import '../../application/lyrics_translation_provider.dart';

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
    final translationState = ref.watch(lyricsTranslationProvider);
    final lyrics = ref.watch(displayLyricsProvider);
    final audioState = ref.watch(audioProvider);
    final track = audioState.currentTrack;

    // 1. Determine Content based on state
    Widget content;
    
    if (lyricsState.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (lyricsState.error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error loading lyrics: ${lyricsState.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    } else if (lyrics.isEmpty) {
      content = const Center(
        child: Text(
          'No lyrics found for this track',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      );
    } else {
      // Success State: Calculate current index and build list
      int newIndex = -1;
      for (int i = 0; i < lyrics.length; i++) {
        if (audioState.position >= lyrics[i].timestamp) {
          newIndex = i;
        } else {
          break;
        }
      }

      if (newIndex != _currentIndex) {
        _currentIndex = newIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActiveLyric(_currentIndex);
        });
      }

      content = LayoutBuilder(
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
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final line = lyrics[index];
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
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
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
      );
    }

    // 2. Build the unified Stack
    return Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.transparent : null,
      body: Stack(
        children: [
          // Background (Only if embedded/overlay)
          if (widget.isEmbedded) ...[
            Positioned.fill(
              child: track != null 
                ? MediaArtworkWidget(
                    item: track,
                    fit: BoxFit.cover,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.6),
                    colorBlendMode: Theme.of(context).brightness == Brightness.light
                        ? BlendMode.lighten
                        : BlendMode.darken,
                  )
                : Container(color: Theme.of(context).colorScheme.surface),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  color: (Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Colors.black)
                      .withOpacity(0.4),
                ),
              ),
            ),
          ],

          // Content Wrapper
          Container(
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
                    // Drag handle and Modal Header
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const Spacer(),
                          if (translationState.isSystemEnabled && lyrics.isNotEmpty)
                            _buildTranslationToggle(context, ref, translationState),
                          if (!translationState.isSystemEnabled || lyrics.isEmpty)
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                  // Corrected: Content is already potentially an Expanded or Center
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),

           // Overlay Close Button (Only if embedded)
          if (widget.isEmbedded)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: SafeArea(
                child: ModernIconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  onPressed: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
                ),
              ),
            ),
          
          // Overlay Translation Toggle (Only if embedded)
          if (widget.isEmbedded && translationState.isSystemEnabled && lyrics.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 16,
              child: SafeArea(
                child: _buildTranslationToggle(context, ref, translationState),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslationToggle(BuildContext context, WidgetRef ref, LyricsTranslationState state) {
    final bool isActive = state.mode != LyricsTranslationMode.original;
    
    String label = state.targetLanguage.toUpperCase();
    if (state.mode == LyricsTranslationMode.romanized) {
      label = 'ROM';
    } else if (state.mode == LyricsTranslationMode.translated) {
      label = 'TRN';
    }

    return HoverWrapper(
      onTap: () => ref.read(lyricsTranslationProvider.notifier).cycleMode(),
      padding: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive 
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Theme.of(context).colorScheme.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive 
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive 
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
