import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance_app/features/lyrics/application/lyrics_translation_provider.dart';

class FloatingLyricsView extends ConsumerStatefulWidget {
  const FloatingLyricsView({super.key});

  @override
  ConsumerState<FloatingLyricsView> createState() => _FloatingLyricsViewState();
}

class _FloatingLyricsViewState extends ConsumerState<FloatingLyricsView> {
  final ItemScrollController _itemScrollController = ItemScrollController();

  void _scrollToActiveLyric(int index) {
    if (!mounted) return;

    // ATURAN SOTA: Gunakan PostFrameCallback untuk mencegah crash saat list belum siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      if (index < 0) return;

      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(displayLyricsProvider);
    final activeIndex = ref.watch(activeLyricIndexProvider);

    // Auto-scroll logic
    ref.listen<int>(activeLyricIndexProvider, (prev, next) {
      if (next != -1 && next != prev) {
        _scrollToActiveLyric(next);
      }
    });

    return PageStorage(
      bucket: PageStorageBucket(), // ATURAN SOTA: Fix PageStorage.of() crash
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Column(
          children: [
            // List Lirik (Fullscreen Area V2.5)
            Expanded(
              child: lyrics.isEmpty
                  ? const Center(child: Text('Lirik tidak tersedia', style: TextStyle(color: Colors.white54)))
                  : ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemCount: lyrics.length,
                      itemBuilder: (context, index) {
                        final line = lyrics[index];
                        final isActive = index == activeIndex;
  
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            line.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isActive ? 16 : 13,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Colors.white : Colors.white24,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
