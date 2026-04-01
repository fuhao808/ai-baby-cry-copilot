import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 40,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.68)
                : const Color(0xFF1A1A1A).withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isLight ? Colors.white70 : Colors.white10,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 28,
                offset: const Offset(0, 18),
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.24),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
