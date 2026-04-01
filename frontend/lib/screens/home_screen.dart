import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_cry_catalog.dart';
import '../providers/app_mode_controller.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/breathing_spectrum.dart';
import '../widgets/frosted_panel.dart';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: [
          FrostedPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRecording
                      ? 'Listening now.'
                      : 'Simple. Calm.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Record or upload.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: BreathingSpectrum(active: isRecording),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FrostedPanel(
            radius: 48,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    _SideActionButton(
                      icon: Icons.upload_rounded,
                      label: 'Upload',
                      size: 68,
                      onPressed: state.phase == RecordingPhase.idle
                          ? () => controller.importMedia(user.uid)
                          : null,
                    ),
                    PulsingMicButton(
                      enabled: state.phase == RecordingPhase.idle,
                      isRecording: isRecording,
                      label: isRecording
                          ? '${state.secondsRemaining}s'
                          : 'Record',
                      size: 144,
                      onPressed: () => controller.startCapture(user.uid),
                    ),
                    const _SideActionButton(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      size: 68,
                      onPressed: null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  isRecording ? "I'm Listening..." : "How's Baby?",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRecording
                      ? 'Hold steady for seven seconds while the spectrum breathes.'
                      : 'Upload left. Record center.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (isTestMode) ...[
            const SizedBox(height: 22),
            FrostedPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Test Mode',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bundled sample shortcuts for developer testing.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final sample in sampleCryCatalog)
                        FilledButton.tonal(
                          onPressed: () => controller.analyzeSampleAsset(
                            userId: user.uid,
                            assetPath: sample.assetPath,
                            fileName: sample.fileName,
                          ),
                          child: Text(sample.title),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            FrostedPanel(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _TipChip(
                    icon: Icons.nightlight_round,
                    text: 'Quiet room helps.',
                  ),
                  _TipChip(
                    icon: Icons.graphic_eq_rounded,
                    text: 'Video becomes audio automatically.',
                  ),
                  _TipChip(
                    icon: Icons.favorite_outline_rounded,
                    text: 'Use caregiver judgment first.',
                  ),
                ],
              ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 72,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(size, size),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Icon(icon, size: size * 0.36),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.7,
            ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
