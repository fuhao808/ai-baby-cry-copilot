import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_cry_catalog.dart';
import '../models/sample_cry.dart';
import '../providers/app_mode_controller.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/breathing_spectrum.dart';
import '../widgets/pulsing_mic_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingFlowControllerProvider);
    final controller = ref.watch(recordingFlowControllerProvider.notifier);
    final isTestMode = ref.watch(appModeProvider).isTestMode;
    final isRecording = state.phase == RecordingPhase.recording;
    final isPaused = state.phase == RecordingPhase.paused;
    final isBusy = state.phase == RecordingPhase.analyzing;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 38),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 18),
                Text(
                  isRecording
                      ? "I'm Listening..."
                      : isPaused
                          ? 'Clip Paused'
                          : "How's Baby?",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRecording
                      ? 'Tap stop anytime.'
                      : isPaused
                          ? 'Resume or analyze this clip.'
                          : 'Record or upload',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                BreathingSpectrum(
                  active: isRecording,
                  levels: state.waveformLevels,
                ),
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _SideActionButton(
                      icon: Icons.upload_rounded,
                      onPressed: state.phase == RecordingPhase.idle
                          ? () => controller.importMedia(user.uid)
                          : null,
                    ),
                    PulsingMicButton(
                      enabled: !isBusy,
                      isRecording: isRecording,
                      isPaused: isPaused,
                      label: isRecording
                          ? '${state.secondsRemaining}s'
                          : isPaused
                              ? 'Done'
                              : 'Record',
                      size: 144,
                      onPressed: () {
                        if (state.phase == RecordingPhase.idle) {
                          controller.startCapture(user.uid);
                          return;
                        }
                        if (isRecording || isPaused) {
                          controller.finishCapture();
                        }
                      },
                    ),
                    _SideActionButton(
                      icon: isPaused
                          ? Icons.play_arrow_rounded
                          : isRecording
                              ? Icons.pause_rounded
                              : Icons.photo_camera_outlined,
                      onPressed: isPaused
                          ? controller.resumeCapture
                          : isRecording
                              ? controller.pauseCapture
                              : null,
                    ),
                  ],
                ),
                if (isTestMode) ...[
                  const SizedBox(height: 28),
                  _DeveloperPanel(
                    samples: sampleCryCatalog,
                    onAnalyze: (sample) => controller.analyzeSampleAsset(
                      userId: user.uid,
                      assetPath: sample.assetPath,
                      fileName: sample.fileName,
                    ),
                    onExit: () => ref.read(appModeProvider.notifier).toggleTestMode(),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 26),
                Opacity(
                  opacity: 0.72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'NOT A MEDICAL DEVICE. This tool uses AI to estimate needs. Always prioritize parental intuition and professional medical advice.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(74, 74),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Icon(icon, size: 28),
    );
  }
}

class _DeveloperPanel extends StatelessWidget {
  const _DeveloperPanel({
    required this.samples,
    required this.onAnalyze,
    required this.onExit,
  });

  final List<SampleCry> samples;
  final void Function(SampleCry sample) onAnalyze;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Mode',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Developer sample shortcuts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('User Mode'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final sample in samples)
                FilledButton.tonal(
                  onPressed: () => onAnalyze(sample),
                  child: Text(sample.title),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
