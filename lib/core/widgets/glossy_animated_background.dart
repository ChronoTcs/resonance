import 'package:flutter/material.dart';

class GlossyAnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final BoxBorder? border;

  const GlossyAnimatedBackground({
    super.key,
    required this.child,
    required this.isSelected,
    this.borderRadius,
    this.baseColor,
    this.border,
  });

  @override
  State<GlossyAnimatedBackground> createState() => _GlossyAnimatedBackgroundState();
}

class _GlossyAnimatedBackgroundState extends State<GlossyAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isSelected) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GlossyAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSelected && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelected) return widget.child;

    final primaryColor = Theme.of(context).primaryColor;
    final resolvedBorderRadius = widget.borderRadius ?? BorderRadius.circular(8);
    final resolvedBaseColor = widget.baseColor ?? primaryColor.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: resolvedBorderRadius,
            color: resolvedBaseColor,
            border: widget.border ?? Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
          ),
          child: ClipRRect(
            borderRadius: resolvedBorderRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment(
                      1.7 - (_controller.value * 3.4),
                      1.7 - (_controller.value * 3.4),
                    ),
                    child: Transform.rotate(
                      angle: -0.785, // 45 degrees
                      child: Container(
                        width: 40,
                        height: 300,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ?child,
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
