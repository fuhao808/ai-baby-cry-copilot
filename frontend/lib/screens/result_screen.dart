import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/capture_media.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/frosted_panel.dart';
import '../widgets/prediction_bars.dart';

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
      return const Center(child: Text('No analysis result available.'));
    }

    final alternativeLabels = result.predictions.keys
        .where((label) => label != result.topResult)
        .toList(growable: false);
    final sourceType =
        state.activeSourceType ?? CaptureSourceType.recordedAudio;
    final canCollectFeedback = result.requiresCryFeedback;
    final insightTitle = canCollectFeedback ? 'AI Insight' : 'Audio Insight';
    final resultSubtitle = canCollectFeedback
        ? 'This is the strongest cry-related signal from the current clip.'
        : result.resultSummary;
    final hasPatterns = result.phoneticPatterns.isNotEmpty;
    final hasDetectedSound =
        (result.detectedSound != null && result.detectedSound!.trim().isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FrostedPanel(
            radius: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ResultPill(
                      label: sourceType.label,
                      emphasized: false,
                    ),
                    _ResultPill(
                      label: result.screeningLabel,
                      icon: canCollectFeedback
                          ? Icons.verified_rounded
                          : Icons.hearing_rounded,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  result.topResult,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  resultSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (hasPatterns || hasDetectedSound) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected Sound',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.62),
                              ),
                        ),
                        if (hasDetectedSound) ...[
                          const SizedBox(height: 10),
                          Text(
                            result.detectedSound!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.68),
                                  height: 1.45,
                                ),
                          ),
                        ],
                        if (hasPatterns) ...[
                          const SizedBox(height: 10),
                          Text(
                            result.phoneticPatterns.join('  •  '),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PredictionBars(
                  predictions: result.predictions,
                  highlightedLabel: result.topResult,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FrostedPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insightTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    result.llmAdvice,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FrostedPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      canCollectFeedback ? 'Was this accurate?' : 'Screening Note',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    if (canCollectFeedback) ...[
                      FilledButton(
                        onPressed: state.isSubmittingFeedback ||
                                state.selectedFeedback != null
                            ? null
                            : () => controller.submitFeedback(
                                  userId: user.uid,
                                  actualLabel: result.topResult,
                                ),
                        child: const Text('Spot On'),
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
                                'Actually ${_displayFeedbackLabel(label)}',
                              ),
                            ),
                        ],
                      ),
                    ] else
                      Text(
                        result.babyVoiceDetected
                            ? 'Baby voice was detected, but this clip did not screen as crying. No cry-label feedback is needed.'
                            : 'This clip screened as non-baby audio or unclear sound. Try again with the phone closer to the baby.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                      ),
                    if (state.selectedFeedback != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Saved: ${state.selectedFeedback}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.reset,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: controller.reset,
                  child: const Text('Try Another'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({
    required this.label,
    required this.emphasized,
    this.icon,
  });

  final String label;
  final bool emphasized;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: emphasized ? 0.13 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: primary.withValues(alpha: emphasized ? 0.92 : 0.62),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: primary.withValues(alpha: emphasized ? 0.92 : 0.72),
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
