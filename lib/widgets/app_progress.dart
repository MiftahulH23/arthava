import 'dart:math' as math;

import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';

double _clampProgress(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  return value.clamp(0.0, 1.0).toDouble();
}

/// Progress bar radius penuh (spec §4.2 tinggi 8, 6 di dalam baris list).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    required this.color,
    this.height = 8,
    this.onDark = false,
    super.key,
  });

  final double value;
  final Color color;
  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.track,
        borderRadius: radius,
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _clampProgress(value),
        heightFactor: 1,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: radius)),
      ),
    );
  }
}

/// Cincin progres (Detail Anggaran, spec §7).
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    required this.value,
    required this.color,
    this.size = 110,
    this.strokeWidth = 11,
    this.center,
    super.key,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: AppProgressRingPainter(value: value, color: color, strokeWidth: strokeWidth),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class AppProgressRingPainter extends CustomPainter {
  AppProgressRingPainter({required double value, required this.color, required this.strokeWidth})
      : value = _clampProgress(value);

  final double value;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = AppColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(AppProgressRingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
