import 'package:flutter/material.dart';

class PacifierMark extends StatelessWidget {
  const PacifierMark({
    super.key,
    this.size = 22,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PacifierPainter(color),
    );
  }
}

class _PacifierPainter extends CustomPainter {
  const _PacifierPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final ringCenter = Offset(center.dx, size.height * 0.30);
    final ringRadius = size.width * 0.21;
    canvas.drawCircle(ringCenter, ringRadius, strokePaint);

    final barRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.60),
        width: size.width * 0.68,
        height: size.height * 0.14,
      ),
      Radius.circular(size.width * 0.07),
    );
    canvas.drawRRect(barRect, fillPaint);

    final shieldPath = Path()
      ..moveTo(size.width * 0.34, size.height * 0.56)
      ..quadraticBezierTo(
        center.dx,
        size.height * 0.97,
        size.width * 0.66,
        size.height * 0.56,
      )
      ..close();
    canvas.drawPath(shieldPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _PacifierPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
