import 'package:flutter/material.dart';

import '../widgets/breathing_spectrum.dart';
import '../widgets/frosted_panel.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FrostedPanel(
            radius: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI is Thinking...',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: BreathingSpectrum(active: true),
                ),
                const SizedBox(height: 12),
                Text(
                  'We are extracting the audio, comparing the pattern, and preparing a calm, short explanation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
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
