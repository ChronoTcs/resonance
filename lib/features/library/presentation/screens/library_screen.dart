import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import '../../application/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/download/presentation/screens/download_screen.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_screen.dart';
import '../widgets/morphing_library_bar.dart';
import '../widgets/add_audio_sheet.dart';
import '../widgets/blocked_tracks_sheet.dart';
import '../../application/blocked_tracks_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOptions(BuildContext context) {
    AddAudioSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(libraryProvider);
    final bool hasPaths = libraryState.musicFolderPath != null;
    final blockedCount = ref.watch(blockedTracksProvider).length;

    Widget buildMusicTab() {
      final audioList = libraryState.allMedia
          .where((m) =>
              m.type == 'audio' &&
              (m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (m.artist?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                      false)))
          .toList();

      return SilkyCustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (!hasPaths)
            _buildEmptyState(
              context,
              'Library paths not configured',
              'Go to Settings to add music folders.',
              icon: UIcons.regular.folder,
            )
          else if (libraryState.isLoading && libraryState.allMedia.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (audioList.isEmpty)
            _buildEmptyState(
              context,
              _searchQuery.isNotEmpty ? 'No matching tracks' : 'No local tracks',
              _searchQuery.isNotEmpty
                  ? 'Try searching with another keyword.'
                  : 'Import audio files from your device or download songs.',
              buttonLabel: _searchQuery.isEmpty ? 'Add Audio Files' : null,
              onButtonPressed:
                  _searchQuery.isEmpty ? () => _showAddOptions(context) : null,
              icon: UIcons.regular.music,
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = audioList[index];
                  return _LibraryTrackTile(
                    item: item,
                    index: index,
                    onTap: () {
                      ref
                          .read(queueOrchestratorProvider)
                          .playSequentialContext(item, audioList);
                    },
                    onMoreOptions: () {
                      MediaActionsBottomSheet.show(
                        context: context,
                        item: item,
                        onDelete: () => _confirmDelete(context, ref, item),
                      );
                    },
                  );
                },
                childCount: audioList.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      );
    }

    final bool isDesktop = AppBreakpoints.isWide(context);
    final mobileNavMode = ref.watch(libraryNavModeProvider);

    final Widget content = isDesktop
        ? buildMusicTab()
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(mobileNavMode),
              child: mobileNavMode == LibraryNavMode.music
                  ? buildMusicTab()
                  : mobileNavMode == LibraryNavMode.playlists
                      ? const PlaylistScreen(showHeader: false)
                      : const DownloadScreen(showHeader: false),
            ),
          );

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearching) {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !isDesktop,
        body: Column(
          children: [
            const OfflineBanner(),
            TopNavigationHeader(
              left: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search in library...',
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: Center(
                                  child: ReusableHoverIconButton(
                                    icon: UIcons.regular.cross_small,
                                    tooltip: 'Clear text',
                                    iconSize: 16,
                                    padding: 2.0,
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    )
                  : Text(
                      isDesktop ? 'Local Library' : 'Library',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              right: (!isDesktop && _isSearching)
                  ? TextButton(
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: blockedCount > 0,
                          label: Text(
                            '$blockedCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: theme.colorScheme.error,
                          textColor: theme.colorScheme.onError,
                          child: ReusableHoverIconButton(
                            icon: UIcons.regular.ban,
                            tooltip: blockedCount > 0
                                ? 'Blocked music ($blockedCount)'
                                : 'Blocked music',
                            iconSize: 18,
                            onTap: () => BlockedTracksSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ReusableHoverIconButton(
                          icon: UIcons.regular.add,
                          tooltip: 'Add audio',
                          iconSize: 18,
                          onTap: () => _showAddOptions(context),
                        ),
                        const SizedBox(width: 8),
                        ReusableHoverIconButton(
                          icon: _isSearching
                              ? UIcons.regular.cross_small
                              : UIcons.regular.search,
                          tooltip: _isSearching ? 'Close search' : 'Search library',
                          iconSize: 18,
                          onTap: () {
                            setState(() {
                              if (_isSearching) {
                                _isSearching = false;
                                _searchQuery = '';
                                _searchController.clear();
                              } else {
                                _isSearching = true;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ReusableHoverIconButton(
                          icon: libraryState.isLoading ? null : UIcons.regular.refresh,
                          tooltip: 'Scan folders',
                          iconSize: 18,
                          onTap: () {
                            final isMusicTab = isDesktop ||
                                mobileNavMode == LibraryNavMode.music;
                            if (isMusicTab) {
                              ref.read(libraryProvider.notifier).scanLibrary();
                            }
                          },
                          child: libraryState.isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.primaryColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
            ),
            if (!isDesktop && !_isSearching)
              MorphingLibraryBar(
                currentMode: mobileNavMode,
                onModeChanged: (mode) {
                  ref.read(libraryNavModeProvider.notifier).setMode(mode);
                },
              ),
            Expanded(
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String subtitle, {
    String? buttonLabel,
    VoidCallback? onButtonPressed,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? UIcons.regular.music,
              size: 64,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ResonanceButton(
                onPressed: onButtonPressed,
                icon: UIcons.regular.add,
                label: buttonLabel,
                style: ResonanceButtonStyle.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => ResonanceConfirmDialog(
        title: 'Delete Track',
        content: 'Permanently delete "${item.title}" from your device? This cannot be undone.',
        confirmLabel: 'Delete',
        isDanger: true,
        onConfirm: () {
          ref.read(libraryProvider.notifier).deleteTrack(item);
          ref.read(notificationProvider.notifier).showNotification(
            'Track Deleted',
            '"${item.title}" deleted from library.',
            target: 'target:library',
            silentOsNotification: true,
          );
        },
      ),
    );
  }
}



class _LibraryTrackTile extends ConsumerWidget {
  final MediaItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMoreOptions;

  const _LibraryTrackTile({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index % 10 * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            position: details.globalPosition,
            item: item,
          );
        },
        child: ListTile(
          mouseCursor: SystemMouseCursors.click,
          leading: MediaArtworkWidget(
            item: item,
            width: 48,
            height: 48,
            borderRadius: 4,
            placeholderIcon: UIcons.regular.music,
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.artist ?? 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: OverflowMenuButton(
            tooltip: 'More options',
            onTap: onMoreOptions,
          ),
          onTap: onTap,
          onLongPress: onMoreOptions,
        ),
      ),
    );
  }
}


