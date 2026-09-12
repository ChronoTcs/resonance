import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';

import '../widgets/appearance_section.dart';
import '../widgets/library_paths_section.dart';
import '../widgets/cache_management_section.dart';
import '../widgets/audio_settings_section.dart';
import '../widgets/translation_section.dart';
import '../widgets/downloads_settings_section.dart';
import '../widgets/support_update_section.dart';
import '../widgets/about_card.dart';
import '../widgets/blocked_tracks_section.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

import 'help_screen.dart';
import 'release_manager_screen.dart';

enum SettingsSubView {
  none,
  display,
  audio,
  storage,
  network,
  blocked,
  help,
  updates,
}

class SettingsSubViewNotifier extends Notifier<SettingsSubView> {
  @override
  SettingsSubView build() => SettingsSubView.none;

  void setSubView(SettingsSubView view) => state = view;
  void close() => state = SettingsSubView.none;
}

final settingsSubViewProvider =
    NotifierProvider<SettingsSubViewNotifier, SettingsSubView>(
  SettingsSubViewNotifier.new,
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subView = ref.watch(settingsSubViewProvider);
    final canPop = subView == SettingsSubView.none;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && subView != SettingsSubView.none) {
          ref.read(settingsSubViewProvider.notifier).close();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            if (subView == SettingsSubView.none)
              TopNavigationHeader(
                left: Text(
                  'Settings',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                right: const SizedBox(),
              ),
            Expanded(
              child: _buildBody(context, theme, ref, subView),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    SettingsSubView subView,
  ) {
    void closeSubView() =>
        ref.read(settingsSubViewProvider.notifier).close();
    void openSubView(SettingsSubView view) =>
        ref.read(settingsSubViewProvider.notifier).setSubView(view);

    switch (subView) {
      case SettingsSubView.display:
        return StickySubViewLayout(
          key: const ValueKey('settings_subview_display'),
          title: 'Display Settings',
          onBack: closeSubView,
          children: const [
            AppearanceSection(),
            SizedBox(height: 24),
            TranslationSection(),
          ],
        );

      case SettingsSubView.audio:
        return StickySubViewLayout(
          key: const ValueKey('settings_subview_audio'),
          title: 'Audio Settings',
          onBack: closeSubView,
          children: const [
            AudioSettingsSection(),
          ],
        );

      case SettingsSubView.storage:
        return StickySubViewLayout(
          key: const ValueKey('settings_subview_storage'),
          title: 'Storage Settings',
          onBack: closeSubView,
          children: const [
            LibraryPathsSection(),
            SizedBox(height: 24),
            CacheManagementSection(),
          ],
        );

      case SettingsSubView.network:
        return StickySubViewLayout(
          key: const ValueKey('settings_subview_network'),
          title: 'Network & Downloads',
          onBack: closeSubView,
          children: const [
            DownloadsSettingsSection(),
          ],
        );

      case SettingsSubView.blocked:
        return StickySubViewLayout(
          key: const ValueKey('settings_subview_blocked'),
          title: 'Blocked Tracks',
          onBack: closeSubView,
          children: const [
            BlockedTracksSection(),
          ],
        );

      case SettingsSubView.help:
        return HelpScreen(
          key: const ValueKey('settings_subview_help'),
          onBack: closeSubView,
        );

      case SettingsSubView.updates:
        return ReleaseManagerScreen(
          key: const ValueKey('settings_subview_updates'),
          onBack: closeSubView,
        );

      case SettingsSubView.none:
        final blockedCount = ref.watch(blockedTracksProvider).length;
        return ListView(
          key: const ValueKey('settings_subview_none'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: AboutCard(
                onOpenUpdates: () => openSubView(SettingsSubView.updates),
              ),
            ),
            _buildNavigationItem(
              context,
              icon: UIcons.regular.palette,
              title: 'Display',
              subtitle: 'Theme, accent colours, lyrics opacity & translation',
              onTap: () => openSubView(SettingsSubView.display),
            ),
            _buildNavigationItem(
              context,
              icon: UIcons.regular.headphones,
              title: 'Audio',
              subtitle: 'Output device, volume normalization & sound effects',
              onTap: () => openSubView(SettingsSubView.audio),
            ),
            _buildNavigationItem(
              context,
              icon: UIcons.regular.hdd,
              title: 'Storage',
              subtitle: 'Library paths, offline storage & cache cleanup',
              onTap: () => openSubView(SettingsSubView.storage),
            ),
            _buildNavigationItem(
              context,
              icon: UIcons.regular.globe,
              title: 'Network',
              subtitle: 'Download limits, concurrent engines & streaming network',
              onTap: () => openSubView(SettingsSubView.network),
            ),
            _buildNavigationItem(
              context,
              icon: UIcons.regular.ban,
              title: 'Blocked Music',
              subtitle: 'Manage blacklisted tracks hidden from queue & home feeds',
              badgeText: blockedCount > 0 ? '$blockedCount' : null,
              onTap: () => openSubView(SettingsSubView.blocked),
            ),
            const SizedBox(height: 24),
            SupportUpdateSection(
              onOpenHelp: () => openSubView(SettingsSubView.help),
            ),
          ],
        );
    }
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 18, color: theme.primaryColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                UIcons.regular.angle_small_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
