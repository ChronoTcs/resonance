import 'dart:async';
import 'package:flutter/material.dart';

/// A reusable horizontal marquee text widget that smoothly auto-scrolls
/// when text exceeds available constraints, eliminating truncation ellipses.
class ResonanceMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double velocity; // in pixels per second

  const ResonanceMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.velocity = 35.0,
  });

  @override
  State<ResonanceMarqueeText> createState() => _ResonanceMarqueeTextState();
}

class _ResonanceMarqueeTextState extends State<ResonanceMarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  int _cycleId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleScroll();
    });
  }

  @override
  void didUpdateWidget(covariant ResonanceMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _cancelTimers();
      _cycleId++;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleScroll();
      });
    }
  }

  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleScroll() {
    _cancelTimers();
    if (!mounted) return;
    final currentCycle = ++_cycleId;

    _timer = Timer(widget.pauseDuration, () async {
      if (!mounted || currentCycle != _cycleId) return;
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final durationMs = ((maxScroll / widget.velocity) * 1000).toInt();
      final scrollDuration = Duration(milliseconds: durationMs.clamp(500, 30000));

      if (!_scrollController.hasClients) return;
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: scrollDuration,
          curve: Curves.linear,
        );
      } catch (_) {
        return;
      }

      if (!mounted || currentCycle != _cycleId) return;

      _timer = Timer(widget.pauseDuration, () {
        if (!mounted || currentCycle != _cycleId) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _timer = Timer(const Duration(seconds: 1), () {
          if (!mounted || currentCycle != _cycleId) return;
          _scheduleScroll();
        });
      });
    });
  }

  @override
  void dispose() {
    _cancelTimers();
    _cycleId++;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
