import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/lyrics_provider.dart';
import '../../../player/application/providers/audio_provider.dart';

import 'package:resonance/core/providers/overlay_provider.dart';
import '../../application/lyrics_translation_provider.dart';
import '../widgets/lyrics_retry_button.dart';
import '../widgets/lyrics_translation_toggle.dart';
import '../widgets/lyrics_list_view.dart';
import '../widgets/lyrics_offset_control.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const LyricsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  @override
  void dispose() {
    super.dispose();
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
      content = Center(
        child: Text(
          'No lyrics found for this track',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 18,
          ),
        ),
      );
    } else {
      content = const LyricsListView();
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
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
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
                      .withValues(alpha: 0.4),
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
                          CollapseButton(
                            iconSize: 20,
                            tooltip: 'Minimize',
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            onTap: () => Navigator.pop(context),
                          ),
                           const LyricsOffsetControl(),
                          const Spacer(),
                          if (translationState.isSystemEnabled && lyrics.isNotEmpty) ...[
                            if (translationState.error != null) ...[
                              LyricsRetryButton(
                                modeLabel: translationState.mode == LyricsTranslationMode.translated 
                                    ? 'Translation' : 'Romanization',
                              ),
                              const SizedBox(width: 8),
                            ],
                              LyricsTranslationToggle(
                                fontSize: 12,
                                padding: 4,
                              ),
                          ],
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
                child: CollapseButton(
                  iconSize: 20,
                  tooltip: 'Close',
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  onTap: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
                ),
              ),
            ),
          
          // Overlay Translation Toggle (Only if embedded)
          if (widget.isEmbedded && translationState.isSystemEnabled && lyrics.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (translationState.error != null) ...[
                      LyricsRetryButton(
                        modeLabel: translationState.mode == LyricsTranslationMode.translated 
                            ? 'Translation' : 'Romanization',
                      ),
                      const SizedBox(width: 8),
                    ],
                    LyricsTranslationToggle(
                      fontSize: 12,
                      padding: 4,
                    ),
                  ],
                ),
              ),
            ),

          // Overlay Offset Control (Only if embedded)
          if (widget.isEmbedded)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: const Center(child: LyricsOffsetControl()),
            ),
        ],
      ),
    );
  }
}
