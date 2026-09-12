import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:silky_scroll/silky_scroll.dart';
import '../../application/lyrics_provider.dart';
import '../../application/lyrics_translation_provider.dart';
import 'word_synced_lyric_row.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/fluent_scroll_behavior.dart';


class LyricsListView extends ConsumerStatefulWidget {
  final bool compact;
  final ScrollPhysics? physics;
  final Color? textColor;

  const LyricsListView({
    super.key,
    this.compact = false,
    this.physics,
    this.textColor,
  });

  @override
  ConsumerState<LyricsListView> createState() => _LyricsListViewState();
}

class _LyricsListViewState extends ConsumerState<LyricsListView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final UniqueKey _silkyLockKey = UniqueKey();
  int _currentIndex = -1;
  double _listHeight = 600.0;
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  DateTime _lastUserScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _onUserScrolled() {
    _lastUserScrollTime = DateTime.now();
    if (_isAutoScrolling) {
      _isAutoScrolling = false;
      _autoScrollTimer?.cancel();
    }
  }

  bool _handleScrollNotificationPredicate(ScrollNotification notification) {
    if (notification.depth > 0) return false;
    // Suppress scrollbar while sync lyrics is auto-scrolling
    if (_isAutoScrolling) return false;
    // User is dragging directly
    if ((notification is ScrollUpdateNotification && notification.dragDetails != null) ||
        (notification is ScrollStartNotification && notification.dragDetails != null) ||
        (notification is UserScrollNotification && notification.direction != ScrollDirection.idle)) {
      _onUserScrolled();
      return true;
    }
    // Accept only if user recently scrolled via mouse/pointer
    final isRecentUserScroll =
        DateTime.now().difference(_lastUserScrollTime).inMilliseconds < 1200;
    return isRecentUserScroll;
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    SilkyScrollGlobalManager.instance.detachKey(_silkyLockKey);
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    if (_itemScrollController.isAttached && index >= 0) {
      _isAutoScrolling = true;
      _autoScrollTimer?.cancel();
      _autoScrollTimer = Timer(const Duration(milliseconds: 750), () {
        _isAutoScrolling = false;
      });

      final targetIndex = widget.compact ? index + 3 : index;
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
        alignment: widget.compact ? 0.45 : 0.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final lyrics = ref.watch(displayLyricsProvider);
    final activeIndex = ref.watch(activeLyricIndexProvider);
    final activeOpacity = ref.watch(lyricsActiveOpacityProvider);
    final inactiveOpacity = ref.watch(lyricsInactiveOpacityProvider);

    if (lyricsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lyricsState.error != null && lyrics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error loading lyrics: ${lyricsState.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final effectiveTextColor =
        widget.textColor ?? Theme.of(context).colorScheme.onSurface;

    if (lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics found for this track',
          style: TextStyle(
            color: effectiveTextColor.withValues(
              alpha: widget.compact ? 0.38 : 0.54,
            ),
            fontSize: widget.compact ? 12 : 18,
          ),
        ),
      );
    }

    // Auto-scroll trigger
    if (activeIndex != _currentIndex) {
      _currentIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLyric(_currentIndex);
      });
    }

    Widget content;
    if (widget.compact) {
      content = ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.1, 0.9, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          initialScrollIndex: activeIndex != -1 ? activeIndex + 3 : 0,
          initialAlignment: 0.45,
          itemCount: lyrics.length + 6,
          physics: widget.physics ?? const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            if (index < 3 || index >= lyrics.length + 3) {
              return const SizedBox(height: 48);
            }

            final lineIndex = index - 3;
            final line = lyrics[lineIndex];
            final isActive = lineIndex == activeIndex;

            final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: WordSyncedLyricRow(
                line: line,
                playerPosition: adjustedPosition,
                isActive: isActive,
                activeOpacity: activeOpacity,
                inactiveOpacity: inactiveOpacity,
                fontSizeActive: 18,
                fontSizeInactive: 14,
                textColor: effectiveTextColor,
              ),
            );
          },
        ),
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          _listHeight = constraints.maxHeight;
          final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);
          return RepaintBoundary(
            child: ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              initialScrollIndex: activeIndex != -1 ? activeIndex : 0,
              initialAlignment: 0.5,
              physics: widget.physics ?? const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: _listHeight / 2 - 30,
                bottom: _listHeight / 2,
              ),
              itemCount: lyrics.length,
              itemBuilder: (context, index) {
                final line = lyrics[index];
                final isActive = index == activeIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: WordSyncedLyricRow(
                    line: line,
                    playerPosition: adjustedPosition,
                    isActive: isActive,
                    activeOpacity: activeOpacity,
                    inactiveOpacity: inactiveOpacity,
                    fontSizeActive: 26,
                    fontSizeInactive: 18,
                    textColor: effectiveTextColor,
                  ),
                );
              },
            ),
          );
        },
      );
    }

    return MouseRegion(
      onEnter: (_) => SilkyScrollGlobalManager.instance.enteredKey(_silkyLockKey),
      onExit: (_) => SilkyScrollGlobalManager.instance.exitKey(_silkyLockKey),
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            _onUserScrolled();
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (event) {},
            );
          }
        },
        onPointerDown: (_) => _onUserScrolled(),
        onPointerMove: (event) {
          if (event.delta.dy.abs() > 0.5) {
            _onUserScrolled();
          }
        },
        child: ScrollConfiguration(
          behavior: _LyricsScrollBehavior(
            notificationPredicate: _handleScrollNotificationPredicate,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _LyricsScrollBehavior extends FluentScrollBehavior {
  final ScrollNotificationPredicate notificationPredicate;

  _LyricsScrollBehavior({required this.notificationPredicate});

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          notificationPredicate: notificationPredicate,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
