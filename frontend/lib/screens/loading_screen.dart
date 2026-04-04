import 'package:flutter/material.dart';

import '../widgets/breathing_spectrum.dart';
import '../widgets/frosted_panel.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FrostedPanel(
          radius: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Checking the clip...',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 156,
                width: double.infinity,
                child: const BreathingSpectrum(
                  active: true,
                  levels: [
                    0.10,
                    0.18,
                    0.28,
                    0.36,
                    0.44,
                    0.52,
                    0.60,
                    0.56,
                    0.48,
                    0.40,
                    0.32,
                    0.24,
                    0.18,
                    0.28,
                    0.36,
                    0.46,
                    0.54,
                    0.42,
                    0.30,
                    0.22,
                    0.16,
                    0.10,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We are checking the clip, reading the sound pattern, and preparing a short summary.',
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
    );
  }
}
