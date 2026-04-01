import 'dart:math' as math;

import 'package:flutter/material.dart';

class BreathingSpectrum extends StatelessWidget {
  const BreathingSpectrum({
    super.key,
    required this.active,
    required this.levels,
  });

  final bool active;
  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = primary.withValues(alpha: 0.16);
    final bars = levels.isEmpty ? List<double>.filled(22, 0.05) : levels;

    return Container(
      width: double.infinity,
      height: 156,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.78)
            : theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 14),
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.light ? 0.06 : 0.22,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            active ? 'LISTENING LIVE' : 'SPECTRUM READY',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 2.4,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _SpectrumPainter(
                levels: bars,
                active: active,
                color: primary,
                mutedColor: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter({
    required this.levels,
    required this.active,
    required this.color,
    required this.mutedColor,
  });

  final List<double> levels;
  final bool active;
  final Color color;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final barCount = levels.length;
    final totalSpacing = (barCount - 1) * 5.0;
    final barWidth = (size.width - totalSpacing) / barCount;
    final centerY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final level = levels[i].clamp(0.04, 1.0);
      final eased = math.pow(level, 0.75).toDouble();
      final minHeight = active ? 8.0 : 10.0;
      final maxHeight = active ? size.height * 0.95 : size.height * 0.24;
      final height = minHeight + ((maxHeight - minHeight) * eased);
      final left = i * (barWidth + 5.0);

      paint.color = active
          ? Color.lerp(
              color.withValues(alpha: 0.32),
              color,
              (0.35 + (eased * 0.65)).clamp(0.0, 1.0),
            )!
          : mutedColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(left + (barWidth / 2), centerY),
            width: barWidth,
            height: height,
          ),
          Radius.circular(barWidth),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.levels != levels ||
        oldDelegate.active != active ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor;
  }
}
