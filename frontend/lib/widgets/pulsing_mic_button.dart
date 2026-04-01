import 'package:flutter/material.dart';

class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    super.key,
    required this.onPressed,
    required this.enabled,
    required this.label,
  });

  final VoidCallback onPressed;
  final bool enabled;
  final String label;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
        final scale = widget.enabled ? 1 + (_controller.value * 0.08) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
        child: SizedBox(
          width: 220,
          height: 220,
          child: ElevatedButton(
            onPressed: widget.enabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              elevation: 10,
              padding: const EdgeInsets.all(24),
            ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_rounded, size: 72),
              const SizedBox(height: 12),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
