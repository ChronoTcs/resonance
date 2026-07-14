import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';

import '../widgets/appearance_section.dart';
import '../widgets/library_paths_section.dart';
import '../widgets/cache_management_section.dart';
import '../widgets/audio_settings_section.dart';
import '../widgets/translation_section.dart';
import '../widgets/downloads_settings_section.dart';
import '../widgets/support_update_section.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final tabs = [
      (icon: UIcons.regular.palette,    label: 'Display'),
      (icon: UIcons.regular.headphones, label: 'Audio'),
      (icon: UIcons.regular.hdd,        label: 'Storage'),
      (icon: UIcons.regular.download,   label: 'Downloads'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: Column(
          children: [
            TopNavigationHeader(
              left: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Settings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.label,
                        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return theme.primaryColor.withValues(alpha: 0.08);
                          }
                          return null;
                        }),
                        tabs: [
                          for (final t in tabs)
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.icon, size: 14),
                                  const SizedBox(width: 6),
                                  Text(t.label),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              right: const SizedBox(),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // ── Tab 1: Display (Appearance + Lyrics) ───────────
                  _SettingsTabPage(children: const [
                    AppearanceSection(),
                    SizedBox(height: 32),
                    TranslationSection(),
                    SizedBox(height: 32),
                    SupportUpdateSection(),
                  ]),

                  // ── Tab 2: Audio ───────────────────────────────────
                  _SettingsTabPage(children: const [
                    AudioSettingsSection(),
                  ]),

                  // ── Tab 3: Storage (Library Paths + Cache) ─────────
                  _SettingsTabPage(children: const [
                    LibraryPathsSection(),
                    SizedBox(height: 32),
                    CacheManagementSection(),
                  ]),

                  // ── Tab 4: Downloads ───────────────────────────────
                  _SettingsTabPage(children: const [
                    DownloadsSettingsSection(),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTabPage extends StatelessWidget {
  final List<Widget> children;
  const _SettingsTabPage({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}
