import 'package:flutter/material.dart';

class PredictionBars extends StatefulWidget {
  const PredictionBars({
    super.key,
    required this.predictions,
    required this.highlightedLabel,
  });

  final Map<String, double> predictions;
  final String highlightedLabel;

  @override
  State<PredictionBars> createState() => _PredictionBarsState();
}

class _PredictionBarsState extends State<PredictionBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedEntries = widget.predictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, _) {
        return Column(
          children: [
            for (final entry in sortedEntries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: entry.key == widget.highlightedLabel
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text('${(entry.value * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 16,
                  value: entry.value * _controller.value,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    entry.key == widget.highlightedLabel
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}
