import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recording_flow_controller.dart';
import '../widgets/pulsing_mic_button.dart';
import '../widgets/theme_palette_sheet.dart';
import 'history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingFlowControllerProvider);
    final controller = ref.watch(recordingFlowControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cry Copilot'),
        actions: [
          const ThemePaletteButton(),
          IconButton(
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HistoryScreen(userId: user.uid),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Use a live 7-second recording or upload a saved video. Videos are converted to audio automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'The app keeps a replayable audio track with each prediction, so you can review what happened later.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              PulsingMicButton(
                enabled: state.phase == RecordingPhase.idle,
                label: state.phase == RecordingPhase.recording
                    ? '${state.secondsRemaining}s'
                    : 'Record 7 Seconds',
                onPressed: () => controller.startCapture(user.uid),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: state.phase == RecordingPhase.idle
                    ? () => controller.importMedia(user.uid)
                    : null,
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Upload Video Or Audio'),
              ),
              const SizedBox(height: 28),
              if (state.phase == RecordingPhase.recording)
                Text(
                  'Recording... ${state.secondsRemaining}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        ),
      ),
    );
  }
}
