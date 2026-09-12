import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Interactive real-time frequency response curve visualizer for the 9-band equalizer.
/// Renders a smooth Catmull-Rom cubic spline with vertical gradient fill and dB grid guides.
class EqualizerCurveVisualizer extends StatelessWidget {
  final List<double> bands;
  final bool isEnabled;
  final double height;

  const EqualizerCurveVisualizer({
    super.key,
    required this.bands,
    required this.isEnabled,
    this.height = 92.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(
            alpha: isDark ? 0.12 : 0.08,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<List<double>>(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        tween: _BandListTween(end: bands),
        builder: (context, animatedBands, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _EqualizerCurvePainter(
              bands: animatedBands,
              isEnabled: isEnabled,
              primaryColor: colorScheme.primary,
              onSurfaceColor: colorScheme.onSurface,
              outlineColor: colorScheme.outline,
            ),
          );
        },
      ),
    );
  }
}

class _BandListTween extends Tween<List<double>> {
  _BandListTween({required List<double> end}) : super(end: end);

  @override
  List<double> lerp(double t) {
    final b = begin ?? List.filled(end!.length, 0.0);
    final e = end!;
    final count = e.length;
    final result = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      final startVal = i < b.length ? b[i] : 0.0;
      result[i] = ui.lerpDouble(startVal, e[i], t) ?? e[i];
    }
    return result;
  }
}

class _EqualizerCurvePainter extends CustomPainter {
  final List<double> bands;
  final bool isEnabled;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color outlineColor;

  _EqualizerCurvePainter({
    required this.bands,
    required this.isEnabled,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || bands.isEmpty) return;

    final width = size.width;
    final height = size.height;
    const paddingX = 18.0;
    const paddingY = 12.0;

    final centerY = height / 2.0;
    final availableHeight = height - (paddingY * 2);
    final availableWidth = width - (paddingX * 2);

    // ── 1. Draw Grid Lines & 0 dB Reference ───────────────────────────────────
    final gridPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    // +6 dB and -6 dB guides
    final yPlus6 = centerY - (6.0 / 12.0) * (availableHeight / 2);
    final yMinus6 = centerY + (6.0 / 12.0) * (availableHeight / 2);
    canvas.drawLine(Offset(paddingX, yPlus6), Offset(width - paddingX, yPlus6), gridPaint);
    canvas.drawLine(Offset(paddingX, yMinus6), Offset(width - paddingX, yMinus6), gridPaint);

    // 0 dB dashed line
    final zeroPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;
    _drawDashedLine(canvas, Offset(paddingX, centerY), Offset(width - paddingX, centerY), zeroPaint);

    // ── 2. Compute 9 Band Points ──────────────────────────────────────────────
    final numBands = bands.length;
    final stepX = numBands > 1 ? availableWidth / (numBands - 1) : 0.0;
    final points = <Offset>[];

    for (int i = 0; i < numBands; i++) {
      final x = paddingX + (i * stepX);
      final clampedDb = bands[i].clamp(-12.0, 12.0);
      final y = centerY - (clampedDb / 12.0) * (availableHeight / 2);
      points.add(Offset(x, y));
    }

    // ── 3. Build Smooth Cubic Spline Path ─────────────────────────────────────
    final splinePath = Path();
    splinePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < numBands - 1; i++) {
      final p0 = points[i > 0 ? i - 1 : 0];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < numBands ? i + 2 : numBands - 1];

      final cp1X = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1Y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2X = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2Y = p2.dy - (p3.dy - p1.dy) / 6.0;

      splinePath.cubicTo(cp1X, cp1Y, cp2X, cp2Y, p2.dx, p2.dy);
    }

    // ── 4. Gradient Fill to 0 dB Baseline ─────────────────────────────────────
    final fillPath = Path.from(splinePath);
    fillPath.lineTo(points.last.dx, centerY);
    fillPath.lineTo(points.first.dx, centerY);
    fillPath.close();

    final activeColor = isEnabled ? primaryColor : onSurfaceColor.withValues(alpha: 0.35);
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, paddingY),
        Offset(0, height - paddingY),
        [
          activeColor.withValues(alpha: isEnabled ? 0.30 : 0.08),
          activeColor.withValues(alpha: isEnabled ? 0.08 : 0.02),
          activeColor.withValues(alpha: isEnabled ? 0.20 : 0.05),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // ── 5. Draw Glowing Spline Stroke ─────────────────────────────────────────
    final strokePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(splinePath, strokePaint);

    // ── 6. Draw Band Nodes ────────────────────────────────────────────────────
    final dotFillPaint = Paint()
      ..color = isEnabled ? primaryColor : onSurfaceColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final dotRingPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final pt in points) {
      canvas.drawCircle(pt, 3.2, dotFillPaint);
      canvas.drawCircle(pt, 3.2, dotRingPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final totalDistance = (p2.dx - p1.dx).abs();
    double currentX = p1.dx;
    final y = p1.dy;

    while (currentX < p1.dx + totalDistance) {
      final nextX = (currentX + dashWidth).clamp(p1.dx, p2.dx);
      canvas.drawLine(Offset(currentX, y), Offset(nextX, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerCurvePainter oldDelegate) {
    return !listEquals(oldDelegate.bands, bands) ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.primaryColor != primaryColor;
  }
}
