import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recording_flow_controller.dart';
import '../widgets/prediction_bars.dart';
import 'history_screen.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({
    super.key,
    required this.user,
  });

  final User user;

  String _displayFeedbackLabel(String label) {
    return label == 'Pain/Gas' ? 'Gas' : label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingFlowControllerProvider);
    final controller = ref.watch(recordingFlowControllerProvider.notifier);
    final result = state.result;

    if (result == null) {
      return const Scaffold(
        body: Center(child: Text('No analysis result available.')),
      );
    }

    final alternativeLabels = result.predictions.keys
        .where((label) => label != result.topResult)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Result',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.topResult,
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF7DD3FC),
                                ),
                      ),
                      const SizedBox(height: 20),
                      PredictionBars(
                        predictions: result.predictions,
                        highlightedLabel: result.topResult,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soothing Advice',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.llmAdvice,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Was this accurate?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: state.isSubmittingFeedback ||
                                state.selectedFeedback != null
                            ? null
                            : () => controller.submitFeedback(
                                  userId: user.uid,
                                  actualLabel: result.topResult,
                                ),
                        child: const Text('Spot On!'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in alternativeLabels)
                            OutlinedButton(
                              onPressed: state.isSubmittingFeedback ||
                                      state.selectedFeedback != null
                                  ? null
                                  : () => controller.submitFeedback(
                                        userId: user.uid,
                                        actualLabel: label,
                                      ),
                              child: Text(
                                'Actually, it was ${_displayFeedbackLabel(label)}',
                              ),
                            ),
                        ],
                      ),
                      if (state.selectedFeedback != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Feedback saved: ${state.selectedFeedback}',
                          style: const TextStyle(color: Color(0xFF7DD3FC)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.reset,
                      child: const Text('Record Another Cry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HistoryScreen(userId: user.uid),
                          ),
                        );
                      },
                      child: const Text('View History'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
