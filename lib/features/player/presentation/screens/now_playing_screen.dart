import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
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
    final isAndroid = Platform.isAndroid;

    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        _NowPlayingBackground(
          track: track,
          blurSigma: isAndroid ? 20.0 : 80.0,
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

  Widget _buildScrollable(Widget child) {
    if (isAndroid) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _scrollPadding,
        child: child,
      );
    }
    return SilkySingleChildScrollView(padding: _scrollPadding, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (track == null) {
      return const Center(child: Text('No media playing'));
    }

    final layoutContent = Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return AppBreakpoints.isCompactWidth(totalWidth)
              ? _MobileLayout(track: track)
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
      child: _buildScrollable(layoutContent),
    );
  }
}

// ── Extracted Modular Sub-Widgets ─────────────────────────────────────────────

class _NowPlayingBackground extends StatelessWidget {
  final dynamic track;
  final double blurSigma;

  const _NowPlayingBackground({
    required this.track,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(
              child: track != null
                  ? MediaArtworkWidget(
                      item: track,
                      fit: BoxFit.cover,
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                      colorBlendMode:
                          isLight ? BlendMode.lighten : BlendMode.darken,
                    )
                  : Container(color: Theme.of(context).colorScheme.surface),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  color: (isLight ? Colors.white : Colors.black)
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CollapseButton(
            tooltip: 'Close',
            iconSize: 20,
            color: iconColor,
            onTap: onClose,
          ),
          const Spacer(),
          Text(
            'NOW PLAYING',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: iconColor,
            ),
          ),
          const Spacer(),
          ReusableHoverIconButton(
            icon: UIcons.regular.list_music,
            iconSize: 20,
            tooltip: 'Queue',
            color: iconColor,
            onTap: onQueue,
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.settings_sliders,
            iconSize: 20,
            tooltip: 'Audio Settings',
            color: iconColor,
            onTap: onAudioSettings,
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.menu_dots,
            iconSize: 20,
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

  const _ArtworkCard({required this.track});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Hero(
            tag: 'player_artwork_${track?.id ?? track.hashCode}',
            child: MediaArtworkWidget(item: track),
          ),
        ),
      ),
    );
  }
}

enum _NowPlayingTab { queueInfo, lyrics }

class _MobileLayout extends StatefulWidget {
  final dynamic track;

  const _MobileLayout({required this.track});

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  _NowPlayingTab _selectedTab = _NowPlayingTab.queueInfo;

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArtworkCard(track: widget.track),
        if (isAndroid) ...[
          const SizedBox(height: 16),
          const NavigationControlCard(showSeekSlider: true),
          const SizedBox(height: 16),
          _SubNavBar(
            selected: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: 16),
          _AndroidSubView(tab: _selectedTab, track: widget.track),
        ] else ...[
          const SizedBox(height: 24),
          MetadataCard(track: widget.track),
          const SizedBox(height: 24),
          const MiniLyricsCard(height: 350),
          const SizedBox(height: 24),
          const NextInQueueCard(),
        ],
      ],
    );
  }
}

/// Animated sub-view that switches between Queue+Info and Lyrics tabs.
class _AndroidSubView extends StatelessWidget {
  final _NowPlayingTab tab;
  final dynamic track;

  const _AndroidSubView({required this.tab, required this.track});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: tab == _NowPlayingTab.queueInfo
          ? Column(
              key: const ValueKey(_NowPlayingTab.queueInfo),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetadataCard(track: track),
                const SizedBox(height: 16),
                const NextInQueueCard(),
              ],
            )
          : const MiniLyricsCard(
              key: ValueKey(_NowPlayingTab.lyrics),
              height: 350,
            ),
    );
  }
}

class _SubNavBar extends StatelessWidget {
  final _NowPlayingTab selected;
  final ValueChanged<_NowPlayingTab> onChanged;

  const _SubNavBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _SubNavItem(
            label: 'Queue & Info',
            selected: selected == _NowPlayingTab.queueInfo,
            primaryColor: theme.primaryColor,
            onTap: () => onChanged(_NowPlayingTab.queueInfo),
          ),
          _SubNavItem(
            label: 'Lyrics',
            selected: selected == _NowPlayingTab.lyrics,
            primaryColor: theme.primaryColor,
            onTap: () => onChanged(_NowPlayingTab.lyrics),
          ),
        ],
      ),
    );
  }
}

class _SubNavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SubNavItem({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? (isLight
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? primaryColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
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
