import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import '../../application/lyrics_provider.dart';
import '../../../player/application/providers/audio_provider.dart';

import 'package:resonance/core/utils/uicons.dart';
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
    final screenWidget = Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.transparent : null,
      body: Stack(
        children: [
          // Background (Only if embedded/overlay)
          if (widget.isEmbedded) _LyricsEmbeddedBackground(track: track),

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
                  if (!widget.isEmbedded)
                    _LyricsModalHeader(
                      track: track,
                      translationState: translationState,
                      hasLyrics: lyrics.isNotEmpty,
                    ),
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

          // Overlay Controls (Only if embedded)
          if (widget.isEmbedded)
            _LyricsEmbeddedControls(
              translationState: translationState,
              hasLyrics: lyrics.isNotEmpty,
              onClose: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
            ),
        ],
      ),
    );

    // Back navigation for the embedded overlay is handled by the Dashboard's
    // _handleBackPress (lyrics checked before now playing), so no PopScope here.
    return screenWidget;
  }
}

class _LyricsModalHeader extends StatelessWidget {
  final MediaItem? track;
  final LyricsTranslationState translationState;
  final bool hasLyrics;

  const _LyricsModalHeader({
    required this.track,
    required this.translationState,
    required this.hasLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle and Modal Header
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(UIcons.regular.music, color: theme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'No Track',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track?.artist != null)
                      Text(
                        track!.artist!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (translationState.isSystemEnabled && hasLyrics) ...[
                if (translationState.error != null) ...[
                  LyricsRetryButton(
                    modeLabel: translationState.mode == LyricsTranslationMode.translated
                        ? 'Translation'
                        : 'Romanization',
                  ),
                  const SizedBox(width: 8),
                ],
                const LyricsTranslationToggle(
                  fontSize: 12,
                  padding: 4,
                ),
              ],
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _LyricsEmbeddedBackground extends StatelessWidget {
  final MediaItem? track;

  const _LyricsEmbeddedBackground({required this.track});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          track != null
              ? MediaArtworkWidget(
                  item: track!,
                  fit: BoxFit.cover,
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                  colorBlendMode:
                      isLight ? BlendMode.lighten : BlendMode.darken,
                )
              : Container(color: Theme.of(context).colorScheme.surface),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              color: (isLight ? Colors.white : Colors.black)
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsEmbeddedControls extends StatelessWidget {
  final LyricsTranslationState translationState;
  final bool hasLyrics;
  final VoidCallback onClose;

  const _LyricsEmbeddedControls({
    required this.translationState,
    required this.hasLyrics,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Overlay Close Button (Only if embedded)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          child: CollapseButton(
            iconSize: 20,
            tooltip: 'Close',
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            onTap: onClose,
          ),
        ),

        // Overlay Translation Toggle (Only if embedded)
        if (translationState.isSystemEnabled && hasLyrics)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (translationState.error != null) ...[
                  LyricsRetryButton(
                    modeLabel: translationState.mode ==
                            LyricsTranslationMode.translated
                        ? 'Translation'
                        : 'Romanization',
                  ),
                  const SizedBox(width: 8),
                ],
                const LyricsTranslationToggle(
                  fontSize: 12,
                  padding: 4,
                ),
              ],
            ),
          ),

        // Overlay Offset Control (Only if embedded)
        Positioned(
          bottom: MediaQuery.paddingOf(context).bottom + 24,
          left: 0,
          right: 0,
          child: const Center(child: LyricsOffsetControl()),
        ),
      ],
    );
  }
}
