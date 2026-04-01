import 'package:flutter/material.dart';

class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    super.key,
    required this.onPressed,
    required this.enabled,
    required this.isRecording,
    required this.label,
    this.size = 144,
  });

  final VoidCallback onPressed;
  final bool enabled;
  final bool isRecording;
  final String label;
  final double size;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
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
    final primary = Theme.of(context).colorScheme.primary;
    final outerColor = widget.isRecording
        ? Colors.redAccent.withValues(alpha: 0.12)
        : primary.withValues(alpha: 0.12);
    final haloSize = widget.size + 18;
    final buttonSize = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.enabled ? 1 + (_controller.value * 0.05) : 1.0;
        final haloScale = 1.05 + (_controller.value * 0.14);

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: haloScale,
                child: Container(
                  width: haloSize,
                  height: haloSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: outerColor,
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: FilledButton(
          onPressed: widget.enabled ? widget.onPressed : null,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor:
                widget.isRecording ? const Color(0xFFEF4444) : primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.all(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                size: buttonSize * 0.32,
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
