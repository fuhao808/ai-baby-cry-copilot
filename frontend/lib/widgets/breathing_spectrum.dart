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
    final bars = levels.isEmpty ? List<double>.filled(72, 0.035) : levels;

    return Container(
      width: double.infinity,
      height: 156,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
            active ? 'LIVE INPUT' : 'SPECTRUM READY',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 3.2,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.44),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 88),
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
    final spacing = active ? 1.55 : 1.75;
    final totalSpacing = (barCount - 1) * spacing;
    final barWidth = (size.width - totalSpacing) / barCount;
    final baselineY = size.height - 6;
    final baselinePaint = Paint()
      ..color = mutedColor.withValues(alpha: active ? 0.24 : 0.28)
      ..strokeWidth = 1.1;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    for (var i = 0; i < barCount; i++) {
      final level = levels[i].clamp(0.04, 1.0);
      final eased = math.pow(level, active ? 0.82 : 0.94).toDouble();
      final minHeight = active ? 3.0 : 5.0;
      final maxHeight = active ? size.height * 0.86 : size.height * 0.16;
      final height = minHeight + ((maxHeight - minHeight) * eased);
      final left = i * (barWidth + spacing);
      final distanceFromCenter =
          ((i - ((barCount - 1) / 2)).abs() / (barCount / 2)).clamp(0.0, 1.0);
      final emphasis = 1 - (distanceFromCenter * 0.06);

      paint.color = active
          ? Color.lerp(
              color.withValues(alpha: 0.12),
              color,
              (0.20 + (eased * 0.80)).clamp(0.0, 1.0),
            )!
          : mutedColor.withValues(alpha: 0.66);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            baselineY - (height * emphasis),
            barWidth,
            height * emphasis,
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
