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

import 'help_screen.dart';
import 'release_manager_screen.dart';

enum SettingsSubView { none, help, updates }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSubView _subView = SettingsSubView.none;
  final ScrollController _displayScrollController = ScrollController();

  void _openSubView(SettingsSubView view) {
    setState(() => _subView = view);
    if (_displayScrollController.hasClients) {
      _displayScrollController.jumpTo(0);
    }
  }

  void _closeSubView() {
    setState(() => _subView = SettingsSubView.none);
    if (_displayScrollController.hasClients) {
      _displayScrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _displayScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tabs = [
      (icon: UIcons.regular.palette,    label: 'Display'),
      (icon: UIcons.regular.headphones, label: 'Audio'),
      (icon: UIcons.regular.hdd,        label: 'Storage'),
      (icon: UIcons.regular.globe,      label: 'Network'),
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
                  // ── Tab 1: Display (Appearance + Lyrics + Update OR SubViews) ───
                  _SettingsTabPage(
                    controller: _displayScrollController,
                    children: _subView == SettingsSubView.help
                        ? [
                            HelpScreen(
                              onBack: _closeSubView,
                            ),
                          ]
                        : _subView == SettingsSubView.updates
                            ? [
                                ReleaseManagerScreen(
                                  onBack: _closeSubView,
                                ),
                              ]
                            : [
                                const AppearanceSection(),
                                const SizedBox(height: 24),
                                const TranslationSection(),
                                const SizedBox(height: 24),
                                SupportUpdateSection(
                                  onOpenHelp: () => _openSubView(SettingsSubView.help),
                                  onOpenUpdates: () => _openSubView(SettingsSubView.updates),
                                ),
                              ],
                  ),

                  // ── Tab 2: Audio ───────────────────────────────────
                  _SettingsTabPage(children: const [
                    AudioSettingsSection(),
                  ]),

                  // ── Tab 3: Storage (Library Paths + Cache) ─────────
                  _SettingsTabPage(children: const [
                    LibraryPathsSection(),
                    SizedBox(height: 24),
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
  final ScrollController? controller;

  const _SettingsTabPage({required this.children, this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}
