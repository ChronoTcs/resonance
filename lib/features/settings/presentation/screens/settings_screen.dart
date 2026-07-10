import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sections
import '../widgets/appearance_section.dart';
import '../widgets/library_paths_section.dart';
import '../widgets/audio_settings_section.dart';
import '../widgets/translation_section.dart';
import '../widgets/cache_management_section.dart';
import '../widgets/support_update_section.dart';

import '../../../../core/widgets/top_navigation_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Column(
        children: [
          TopNavigationHeader(
            left: Text(
              'Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            right: const SizedBox(),
          ),
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const SizedBox(height: 8),

          // 1. Appearance (Theme & Accent)
          const AppearanceSection(),
          const SizedBox(height: 32),

          // 2. Library (Music, Video, Lyrics, Cache Path)
          const LibraryPathsSection(),
          const SizedBox(height: 32),

          // 3. Audio (Volume, Speed, Pitch)
          const AudioSettingsSection(),
          const SizedBox(height: 32),

          // 4. Lyrics Translation
          const TranslationSection(),
          const SizedBox(height: 32),

          // 5. Cache Management (Modern Nested UI)
          const CacheManagementSection(),
          const SizedBox(height: 32),

          // 6. Support & Update (About, Support, Updates)
          const SupportUpdateSection(),
          
          const SizedBox(height: 32),
        ],
      ),
    ),
  ],
),
    );
  }
}
