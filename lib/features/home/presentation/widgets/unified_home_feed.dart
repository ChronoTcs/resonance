import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/features/home/presentation/widgets/home_online_feed_section.dart';
import 'package:resonance/features/home/presentation/widgets/home_personalized_sections.dart';
import 'package:resonance/features/home/presentation/widgets/home_recent_plays_section.dart';
import 'package:resonance/features/home/presentation/widgets/local_quick_picks_section.dart';
import 'package:resonance/features/home/presentation/widgets/home_cached_music_section.dart';
import 'package:resonance/features/home/presentation/widgets/quick_picks_column_section.dart';
import 'package:resonance/features/home/presentation/widgets/speed_dial_section.dart';

/// Unified responsive feed for Home screen across Windows Desktop and Android Mobile.
///
/// Order of presentation:
/// 1. Speed Dial Bento Grid (Picture 4)
/// 2. Quick Picks 4-Row Column Snap Carousel (Picture 3)
/// 3. YouTube Music Recommendation Feeds (Mixed for you, Listen again, Trending, Charts from old Explore)
/// 4. Recently Played Carousel with Clear Action
/// 5. Local Quick Picks (scanned local audio)
/// 6. Daily Discover Mix
/// 7. Forgotten Favorites Mix
/// 8. Similar Artists Radios
class UnifiedHomeFeed extends StatelessWidget {
  const UnifiedHomeFeed({super.key});

  List<Widget> get slivers => const [
        // 1. Speed Dial Bento Grid (Picture 4)
        SpeedDialSection(),

        // 2. Quick Picks 4-Row Snap Carousel (Picture 3)
        QuickPicksColumnSection(),

        // 3. YouTube Music Online Recommendation Feeds (Mixed for you, Trending, Listen again)
        ExploreHomeFeedSection(),

        // 4. Recently Played
        ExploreRecentPlaysSection(),

        // 5. Local Scanned Audio & Cached Stream Music
        LocalQuickPicksSection(),
        HomeCachedMusicSection(),

        // 6. Daily Discover & Forgotten Favorites
        ExploreDailyDiscoverSection(),
        ExploreForgottenFavoritesSection(),

        // 7. Similar Artists Radios
        ExploreSimilarArtistsSection(),

        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ];

  @override
  Widget build(BuildContext context) {
    return SilkyCustomScrollView(
      slivers: slivers,
    );
  }
}
