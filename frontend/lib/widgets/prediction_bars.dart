import 'package:flutter/material.dart';

class PredictionBars extends StatelessWidget {
  const PredictionBars({
    super.key,
    required this.predictions,
    required this.highlightedLabel,
  });

  final Map<String, double> predictions;
  final String highlightedLabel;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = predictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final entry in sortedEntries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: entry.key == highlightedLabel
                        ? FontWeight.w700
                        : FontWeight.w500,
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
              minHeight: 14,
              value: entry.value,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                entry.key == highlightedLabel
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
