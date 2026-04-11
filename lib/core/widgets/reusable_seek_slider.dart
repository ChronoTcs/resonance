import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nama: ReusableSeekSlider (SOTA V13.14)
/// Deskripsi: Komponen timeline tunggal (True Source) untuk musik dan video.
/// Fitur: Tooltip Edge-Guard, Smooth Hover, Adaptive Geometry.
class ReusableSeekSlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final double trackHeight;
  final double height;
  final double thumbRadius;
  final bool showTooltip;

  const ReusableSeekSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.trackHeight = 4.0,
    this.height = 32.0,
    this.thumbRadius = 6.0,
    this.showTooltip = true,
  });

  @override
  State<ReusableSeekSlider> createState() => _ReusableSeekSliderState();
}

class _ReusableSeekSliderState extends State<ReusableSeekSlider> {
  double? _hoverValue;
  bool _isHovering = false;
  bool _isDragging = false;
  double _dragValue = 0;

  // The Slider widget has internal horizontal padding matching the overlay radius.
  // We use 14.0 as a standard Resonance hit-area padding.
  static const double horizontalPadding = 14.0;

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.primaryColor;
    final inactiveColor = widget.inactiveColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - (2 * horizontalPadding);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          onHover: (event) {
            setState(() {
              final double localX = event.localPosition.dx;
              final double normalizedX = (localX - horizontalPadding) / trackWidth;
              _hoverValue = (normalizedX * widget.max).clamp(0.0, widget.max);
            });
          },
          child: Container(
            height: widget.height,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: widget.trackHeight,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: horizontalPadding),
                    activeTrackColor: activeColor,
                    inactiveTrackColor: inactiveColor,
                    thumbColor: activeColor,
                  ),
                  child: Slider(
                    value: widget.value.clamp(0.0, widget.max),
                    max: widget.max > 0 ? widget.max : 1.0,
                    onChanged: (val) {
                      setState(() => _dragValue = val);
                      widget.onChanged(val);
                    },
                    onChangeStart: (val) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = val;
                      });
                      widget.onChangeStart?.call(val);
                    },
                    onChangeEnd: (val) {
                      setState(() => _isDragging = false);
                      widget.onChangeEnd?.call(val);
                    },
                  ),
                ),
                // Tooltip Layer
                if (widget.showTooltip && (_isHovering || _isDragging) && widget.max > 0)
                  _buildTooltip(totalWidth, trackWidth, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltip(double totalWidth, double trackWidth, ThemeData theme) {
    final double rawX = _calculateTooltipX(totalWidth, trackWidth);
    
    // SOTA Edge-Guard Logic: Clamp tooltip position so it doesn't "drown" at screen edges
    // Tooltip width is roughly 60-80px, half is 30-40px.
    const double minEdgePadding = 40.0; 
    final double clampedX = rawX.clamp(minEdgePadding, totalWidth - minEdgePadding);

    return Positioned(
      left: clampedX,
      top: -38,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                // Theme extraction from app_theme.dart SOTA specs
                color: const Color(0xFF000000).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _formatDuration(Duration(seconds: (_isDragging ? _dragValue : (_hoverValue ?? 0)).toInt())),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            // SOTA Triangle (Following rawX even if tooltip is clamped, optional but nice)
            // For simplicity, we center it under the clamped tooltip
            CustomPaint(
              size: const Size(10, 5),
              painter: _TooltipPointerPainter(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTooltipX(double totalWidth, double trackWidth) {
    double progress;
    if (_isDragging) {
      progress = _dragValue / (widget.max > 0 ? widget.max : 1.0);
    } else if (_hoverValue != null) {
      progress = _hoverValue! / (widget.max > 0 ? widget.max : 1.0);
    } else {
      return 0;
    }
    return (horizontalPadding + (progress * trackWidth)).clamp(0.0, totalWidth);
  }
}

class _TooltipPointerPainter extends CustomPainter {
  final Color color;
  _TooltipPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
