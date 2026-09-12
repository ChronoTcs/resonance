import 'package:flutter/material.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'shimmer_skeleton.dart';

// ── Shared: 140px vertical track card skeleton ────────────────────────────────

/// Individual vertical track card skeleton (140px width).
class TrackCardSkeleton extends StatelessWidget {
  final double width;
  final double imageHeight;

  const TrackCardSkeleton({
    super.key,
    this.width = 140,
    this.imageHeight = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerSkeleton(
            width: width,
            height: imageHeight,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          ShimmerSkeleton(
            width: width * 0.78,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          ShimmerSkeleton(
            width: width * 0.52,
            height: 11,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

// ── Shared: Standard 140px horizontal carousel section skeleton ───────────────

/// Horizontal carousel section skeleton (Box widget).
/// Used by: Online Feeds, Recently Played, Daily Discover,
///           Forgotten Favorites, Similar Artists, Local Quick Picks.
class SectionCarouselSkeleton extends StatelessWidget {
  final double titleWidth;
  final double? subtitleWidth;
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const SectionCarouselSkeleton({
    super.key,
    this.titleWidth = 130,
    this.subtitleWidth,
    this.itemCount = 5,
    this.height = 200,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerSkeleton(
                    width: 18,
                    height: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 8),
                  ShimmerSkeleton(
                    width: titleWidth,
                    height: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              if (subtitleWidth != null) ...[
                const SizedBox(height: 4),
                ShimmerSkeleton(
                  width: subtitleWidth!,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: SilkyListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: itemCount,
            itemBuilder: (context, index) => const TrackCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

/// Horizontal carousel section skeleton wrapped as a Sliver.
class SectionCarouselSliverSkeleton extends StatelessWidget {
  final double titleWidth;
  final double? subtitleWidth;
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const SectionCarouselSliverSkeleton({
    super.key,
    this.titleWidth = 130,
    this.subtitleWidth,
    this.itemCount = 5,
    this.height = 200,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionCarouselSkeleton(
        titleWidth: titleWidth,
        subtitleWidth: subtitleWidth,
        itemCount: itemCount,
        height: height,
        padding: padding,
      ),
    );
  }
}

// ── Dedicated: Speed Dial 2-row horizontal grid skeleton ─────────────────────

/// Single 116x116 square card skeleton matching SpeedDialCard.
class _SpeedDialCardSkeleton extends StatelessWidget {
  const _SpeedDialCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ShimmerSkeleton(
            width: 116,
            height: 116,
            borderRadius: BorderRadius.circular(12),
          ),
          Positioned(
            left: 8,
            right: 6,
            bottom: 8,
            child: Row(
              children: [
                ShimmerSkeleton(
                  width: 64,
                  height: 11,
                  borderRadius: BorderRadius.circular(3),
                ),
                const Spacer(),
                ShimmerSkeleton(
                  width: 10,
                  height: 10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Speed Dial 2-row horizontal grid skeleton.
/// Matches the loaded SpeedDialSection exactly:
///   height: 254, crossAxisCount: 2, childAspectRatio: 1.0, cards: 116x116.
class SpeedDial2RowGridSkeleton extends StatelessWidget {
  const SpeedDial2RowGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row matching _SpeedDialHeader
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        ShimmerSkeleton(
                          width: 18,
                          height: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(width: 8),
                        ShimmerSkeleton(
                          width: 90,
                          height: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ShimmerSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(width: 6),
                        ShimmerSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2-row horizontal grid — height: 254 matching the actual SizedBox height
            SizedBox(
              height: 254,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: 8,
                itemBuilder: (context, index) => const _SpeedDialCardSkeleton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Deprecated alias so old references compile (points to new impl) ───────────

/// @deprecated Use [SpeedDial2RowGridSkeleton] instead.
@Deprecated('Use SpeedDial2RowGridSkeleton which matches the actual horizontal 2-row grid design')
class SpeedDialGridSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SpeedDialGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
  });

  @override
  Widget build(BuildContext context) {
    return const SpeedDial2RowGridSkeleton();
  }
}

// ── Dedicated: Quick Picks 4-row column carousel skeleton ────────────────────

/// Single tile row skeleton matching QuickPicksTrackTile.
class _QuickPicksTileSkeleton extends StatelessWidget {
  const _QuickPicksTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: Row(
        children: [
          ShimmerSkeleton(
            width: 52,
            height: 52,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(
                  width: 140,
                  height: 13,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 5),
                ShimmerSkeleton(
                  width: 90,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShimmerSkeleton(
            width: 18,
            height: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// A single column of 4 stacked QuickPicksTileSkeletons.
class _QuickPicksColumnSkeleton extends StatelessWidget {
  final double columnWidth;

  const _QuickPicksColumnSkeleton({required this.columnWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: Column(
        children: List.generate(4, (_) => const Expanded(child: _QuickPicksTileSkeleton())),
      ),
    );
  }
}

/// Quick Picks horizontal snap carousel skeleton.
/// Matches the loaded QuickPicksColumnSection exactly:
///   height: 256, columns: 340dp (desktop) or 85% width (mobile), 4 rows per column.
class QuickPicksColumnCarouselSkeleton extends StatelessWidget {
  const QuickPicksColumnCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = AppBreakpoints.isWideWidth(screenWidth);
    final columnWidth =
        isDesktop ? 340.0 : (screenWidth * 0.85).clamp(280.0, 360.0);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching _QuickPicksHeader
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        ShimmerSkeleton(
                          width: 18,
                          height: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(width: 8),
                        ShimmerSkeleton(
                          width: 100,
                          height: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // "Play all" pill shimmer
                        ShimmerSkeleton(
                          width: 84,
                          height: 32,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        const SizedBox(width: 8),
                        ShimmerSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(width: 4),
                        ShimmerSkeleton(
                          width: 24,
                          height: 24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Horizontal carousel — height: 256 matching the actual SizedBox height
            SizedBox(
              height: 256,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, _) =>
                    _QuickPicksColumnSkeleton(columnWidth: columnWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dedicated: Recent Searches Carousel skeleton (Explore page) ───────────────

/// Single 105x105 card skeleton matching RecentSearchesCard.
class _RecentSearchCardSkeleton extends StatelessWidget {
  const _RecentSearchCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerSkeleton(
            width: 105,
            height: 105,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          ShimmerSkeleton(
            width: 85,
            height: 13,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Horizontal carousel skeleton for the RecentSearchesCarouselSection.
/// Matches: height 145, 105x105 square cards, 1-line title, no subtitle.
class RecentSearchesCarouselSkeleton extends StatelessWidget {
  const RecentSearchesCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching RecentSearchesCarouselSection header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ShimmerSkeleton(
                      width: 16,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(width: 8),
                    ShimmerSkeleton(
                      width: 120,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                ShimmerSkeleton(
                  width: 26,
                  height: 26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Carousel row — height: 145 matching the actual SizedBox height
          SizedBox(
            height: 145,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const _RecentSearchCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dedicated: Explore Music search results list skeleton ─────────────────────

/// Single explore music tile skeleton matching ExploreMusicTile.
/// Thumbnail: 60x60, 2-line title row, author/duration subtitle.
class ExploreMusicTileSkeleton extends StatelessWidget {
  const ExploreMusicTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          ShimmerSkeleton(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ShimmerSkeleton(
                        width: 200,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShimmerSkeleton(
                      width: 32,
                      height: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ShimmerSkeleton(
                  width: 110,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShimmerSkeleton(
            width: 24,
            height: 24,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Full list skeleton for Explore Search Music tab.
class ExploreMusicListSkeleton extends StatelessWidget {
  final int itemCount;

  const ExploreMusicListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (_, _) => const ExploreMusicTileSkeleton(),
    );
  }
}

// ── Dedicated: Explore Playlist search results list skeleton ──────────────────

/// Single explore playlist card skeleton matching ExplorePlaylistCardTile.
/// Matches: 12dp radius bordered container, 80x80 thumbnail, 2-line title + author.
class ExplorePlaylistCardSkeleton extends StatelessWidget {
  const ExplorePlaylistCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ShimmerSkeleton(
              width: 80,
              height: 80,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(
                    width: 160,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  ShimmerSkeleton(
                    width: 100,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  ShimmerSkeleton(
                    width: 70,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ShimmerSkeleton(
              width: 28,
              height: 28,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full list skeleton for Explore Search Playlists tab.
class ExplorePlaylistCardListSkeleton extends StatelessWidget {
  final int itemCount;

  const ExplorePlaylistCardListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (_, _) => const ExplorePlaylistCardSkeleton(),
    );
  }
}

// ── Shared: Horizontal list tile skeleton (library, search rows) ──────────────

/// Horizontal list tile skeleton for playlists or search rows.
class TrackTileSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const TrackTileSkeleton({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          ShimmerSkeleton(
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(
                  width: 180,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                ShimmerSkeleton(
                  width: 110,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShimmerSkeleton(
            width: 36,
            height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
