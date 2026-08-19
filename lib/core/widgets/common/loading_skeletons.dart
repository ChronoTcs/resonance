import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'shimmer_skeleton.dart';

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

/// Horizontal carousel section skeleton (Box widget).
class SectionCarouselSkeleton extends StatelessWidget {
  final double titleWidth;
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const SectionCarouselSkeleton({
    super.key,
    this.titleWidth = 130,
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
          child: Row(
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
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const SectionCarouselSliverSkeleton({
    super.key,
    this.titleWidth = 130,
    this.itemCount = 5,
    this.height = 200,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionCarouselSkeleton(
        titleWidth: titleWidth,
        itemCount: itemCount,
        height: height,
        padding: padding,
      ),
    );
  }
}

/// Speed dial quick-launch grid skeleton.
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
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
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
                  width: 90,
                  height: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 56,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      ShimmerSkeleton(
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerSkeleton(
                              width: 120,
                              height: 13,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 5),
                            ShimmerSkeleton(
                              width: 75,
                              height: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
