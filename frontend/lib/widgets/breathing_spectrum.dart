import 'dart:math' as math;

import 'package:flutter/material.dart';

class BreathingSpectrum extends StatefulWidget {
  const BreathingSpectrum({
    super.key,
    required this.active,
  });

  final bool active;

  @override
  State<BreathingSpectrum> createState() => _BreathingSpectrumState();
}

class _BreathingSpectrumState extends State<BreathingSpectrum>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _SpectrumPainter(
            progress: _controller.value,
            active: widget.active,
            color: Theme.of(context).colorScheme.primary,
            mutedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          ),
        );
      },
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter({
    required this.progress,
    required this.active,
    required this.color,
    required this.mutedColor,
  });

  final double progress;
  final bool active;
  final Color color;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const barCount = 22;
    final barWidth = size.width / (barCount * 1.45);
    final spacing = barWidth * 0.45;
    final centerY = size.height / 2;

    for (var index = 0; index < barCount; index++) {
      final x = index * (barWidth + spacing);
      final seed = math.sin((index * 0.65) + (progress * math.pi * 2));
      final amplitude = active ? (0.3 + (seed.abs() * 0.85)) : 0.22 + ((index % 3) * 0.05);
      final barHeight = size.height * amplitude;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + (barWidth / 2), centerY),
          width: barWidth,
          height: barHeight.clamp(14, size.height),
        ),
        Radius.circular(barWidth),
      );
      paint.color = active
          ? Color.lerp(color.withValues(alpha: 0.25), color, (seed.abs()))!
          : mutedColor;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor;
  }
}
