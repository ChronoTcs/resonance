import 'package:resonance/core/widgets/widgets.dart';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import '../widgets/player_cards.dart';
import '../widgets/mini_player/shared/audio_settings_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  void _showMediaActions(BuildContext context, dynamic track) {
    MediaActionsBottomSheet.show(context: context, item: track);
  }

  void _showAudioSettings(BuildContext context) {
    AudioSettingsSheet.show(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioProvider.select((s) => s.currentTrack));
    final isAndroid =
        Theme.of(context).platform == TargetPlatform.android ||
        Platform.isAndroid;

    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        _NowPlayingBackground(
          track: track,
        ),
        SafeArea(
          child: Column(
            children: [
              NowPlayingTopBar(
                track: track,
                onClose: () =>
                    ref.read(nowPlayingOverlayProvider.notifier).setVisible(false),
                onQueue: () =>
                    ref.read(queueOverlayProvider.notifier).toggle(),
                onMediaActions: () => _showMediaActions(context, track),
                onAudioSettings: () => _showAudioSettings(context),
              ),
              Expanded(
                child: _NowPlayingBody(track: track, isAndroid: isAndroid),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Entry animation + scroll wrapper ─────────────────────────────────────────

class _NowPlayingBody extends StatelessWidget {
  final dynamic track;
  final bool isAndroid;

  const _NowPlayingBody({required this.track, required this.isAndroid});

  static const _scrollPadding = EdgeInsets.only(
    left: 24,
    right: 24,
    top: 12,
    bottom: 48,
  );

  Widget _buildScrollable(Widget child, {EdgeInsetsGeometry? padding}) {
    final effectivePadding = padding ?? _scrollPadding;
    if (isAndroid) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: effectivePadding,
        child: child,
      );
    }
    return SilkySingleChildScrollView(padding: effectivePadding, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (track == null) {
      return const Center(child: Text('No media playing'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = AppBreakpoints.isCompactWidth(constraints.maxWidth);
        final padding = (!isAndroid && isCompact)
            ? const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 48)
            : _scrollPadding;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        final layoutContent = Center(
          child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final totalWidth = innerConstraints.maxWidth;
              if (isAndroid) {
                return _AndroidMobileLayout(track: track);
              }
              return isCompact
                  ? _DesktopCompactLayout(
                      track: track,
                      totalWidth: totalWidth,
                      maxHeight: availableHeight,
                    )
                  : _DesktopLayout(track: track, totalWidth: totalWidth);
            },
          ),
        );

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          ),
          child: _buildScrollable(layoutContent, padding: padding),
        );
      },
    );
  }
}

// ── Extracted Modular Sub-Widgets ─────────────────────────────────────────────

class _NowPlayingBackground extends StatelessWidget {
  final dynamic track;

  const _NowPlayingBackground({
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final bg = theme.scaffoldBackgroundColor;
    final accent = theme.colorScheme.primary;

    final topColor = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.25 : 0.22),
      bg,
    );
    final midColor = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.08 : 0.06),
      bg,
    );

    return Positioned.fill(
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [topColor, midColor, bg],
            ),
          ),
        ),
      ),
    );
  }
}

class NowPlayingTopBar extends StatelessWidget {
  final dynamic track;
  final VoidCallback onClose;
  final VoidCallback onQueue;
  final VoidCallback onMediaActions;
  final VoidCallback onAudioSettings;

  const NowPlayingTopBar({
    super.key,
    required this.track,
    required this.onClose,
    required this.onQueue,
    required this.onMediaActions,
    required this.onAudioSettings,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CollapseButton(
            tooltip: 'Close',
            iconSize: 20,
            color: iconColor,
            onTap: onClose,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ReusableHoverIconButton(
            icon: UIcons.regular.list_music,
            iconSize: 20,
            padding: 6,
            tooltip: 'Queue',
            color: iconColor,
            onTap: onQueue,
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.settings_sliders,
            iconSize: 20,
            padding: 6,
            tooltip: 'Audio Settings',
            color: iconColor,
            onTap: onAudioSettings,
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.menu_dots,
            iconSize: 20,
            padding: 6,
            tooltip: 'Media Actions',
            color: iconColor,
            onTap: onMediaActions,
          ),
        ],
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  final dynamic track;
  final double? maxSize;

  const _ArtworkCard({
    required this.track,
    this.maxSize,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Hero(
            tag: 'player_artwork_${track?.id ?? track.hashCode}',
            child: MediaArtworkWidget(
              item: track,
              width: maxSize ?? 380,
              height: maxSize ?? 380,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    if (maxSize != null) {
      card = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxSize!,
            maxHeight: maxSize!,
          ),
          child: card,
        ),
      );
    }

    return card;
  }
}

class _DesktopCompactLayout extends StatelessWidget {
  final dynamic track;
  final double totalWidth;
  final double maxHeight;

  const _DesktopCompactLayout({
    required this.track,
    required this.totalWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (totalWidth < 420.0) {
      final artworkSize = min(totalWidth * 0.5, 180.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArtworkCard(track: track, maxSize: artworkSize),
          const SizedBox(height: 16),
          MetadataCard(track: track),
          const SizedBox(height: 16),
          const SizedBox(
            height: 240,
            child: MiniLyricsCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          const NextInQueueCard(),
        ],
      );
    }

    const spacing = 16.0;
    final leftWidth = (totalWidth - spacing) * 0.42;
    final artworkSize =
        min(leftWidth, min(maxHeight * 0.45, 210.0)).clamp(150.0, 210.0);
    final minLeftHeight = artworkSize + 16.0 + 150.0;
    const minRightHeight = 260.0 + 16.0 + 105.0; // Ensures >= 260px for lyrics
    final contentHeight =
        max(max(minLeftHeight, minRightHeight), maxHeight - 60.0);

    return SizedBox(
      height: contentHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (42%): Artwork + Metadata
          Expanded(
            flex: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArtworkCard(track: track, maxSize: artworkSize),
                const SizedBox(height: 16),
                Expanded(
                  child: MetadataCard(track: track),
                ),
              ],
            ),
          ),
          const SizedBox(width: spacing),
          // Right Column (58%): Lyrics + Queue
          const Expanded(
            flex: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MiniLyricsCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                NextInQueueCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AndroidMobileLayout extends StatelessWidget {
  final dynamic track;

  const _AndroidMobileLayout({required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArtworkCard(track: track),
        const SizedBox(height: 18),
        // Title & Artist + Actions (Add to Playlist + Like Heart)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResonanceMarqueeText(
                      text: track?.title ?? 'Not Playing',
                      style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: theme.colorScheme.onSurface,
                          ) ??
                          const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Add to Playlist Button using ReusableHoverIconButton
              ReusableHoverIconButton(
                icon: UIcons.regular.plus,
                tooltip: 'Add to playlist',
                iconSize: 22,
                padding: 8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                onTap: track != null && track is MediaItem
                    ? () => MediaActionsBottomSheet.showPlaylistPicker(
                          context,
                          track as MediaItem,
                        )
                    : null,
              ),
              const SizedBox(width: 4),
              // Like Button using ReusableHoverIconButton
              Consumer(
                builder: (context, ref, _) {
                  final isLiked = track != null &&
                      track is MediaItem &&
                      ref.watch(
                        playlistProvider.select(
                          (s) => s.value?.isLiked(track) ?? false,
                        ),
                      );
                  return ReusableHoverIconButton(
                    icon: isLiked ? UIcons.solid.heart : UIcons.regular.heart,
                    tooltip: isLiked ? 'Unlike' : 'Like',
                    iconSize: 22,
                    padding: 8,
                    color: isLiked
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    iconColor: isLiked ? Colors.redAccent : null,
                    onTap: track == null || track is! MediaItem
                        ? null
                        : () {
                            ref
                                .read(playlistProvider.notifier)
                                .toggleLike(track as MediaItem);
                          },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Fused Navigation Controls (Seek slider & unified controls fused into view background)
        const NavigationControlCard(
          showSeekSlider: true,
          showVolumeSlider: false,
          isLargePlayButton: true,
          isCard: false,
        ),
        const SizedBox(height: 12),
        // Auxiliary Output Route & Queue Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => AudioSettingsSheet.show(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        UIcons.regular.settings_sliders,
                        size: 15,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Audio Settings',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        UIcons.regular.angle_small_down,
                        size: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  return IconButton(
                    icon: Icon(
                      UIcons.regular.list_music,
                      size: 22,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                    tooltip: 'Queue',
                    onPressed: () {
                      ref.read(queueOverlayProvider.notifier).toggle();
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Floating Bottom Lyrics Preview Sheet
        const _FloatingLyricsPreviewSheet(),
      ],
    );
  }
}

class _FloatingLyricsPreviewSheet extends ConsumerWidget {
  const _FloatingLyricsPreviewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsState = ref.watch(lyricsProvider);
    final pos = ref.watch(audioProvider.select((s) => s.position));
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Determine current active lyric line
    String previewText = 'Tap to view lyrics';
    if (lyricsState.isLoading) {
      previewText = 'Loading lyrics...';
    } else if (lyricsState.lyrics.isNotEmpty) {
      String? activeLine;
      for (final line in lyricsState.lyrics) {
        if (line.timestamp <= pos) {
          if (line.text.trim().isNotEmpty) {
            activeLine = line.text;
          }
        } else {
          break;
        }
      }
      previewText = activeLine ?? lyricsState.lyrics.first.text;
    }

    return GestureDetector(
      onTap: () => ref.read(lyricsOverlayProvider.notifier).setVisible(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFF15181E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      UIcons.regular.comment_alt_music,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lyrics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Icon(
                  UIcons.regular.expand,
                  size: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final dynamic track;
  final double totalWidth;

  const _DesktopLayout({
    required this.track,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 32.0;
    final leftWidth = (totalWidth - spacing) * 0.4;
    final gridHeight = leftWidth + 24 + 240;

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Artwork + Metadata (40%)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArtworkCard(track: track),
                const SizedBox(height: 24),
                SizedBox(
                  height: 240,
                  child: MetadataCard(track: track, height: 240),
                ),
              ],
            ),
          ),
          const SizedBox(width: spacing),
          // Right Column: Lyrics + Queue (60%)
          const Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: MiniLyricsCard()),
                SizedBox(height: 24),
                NextInQueueCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
