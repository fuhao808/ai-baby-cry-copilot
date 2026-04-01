import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/sample_cry_catalog.dart';
import '../models/sample_cry.dart';
import '../providers/recording_flow_controller.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  late final AudioPlayer _player = AudioPlayer();
  String? _playingSampleId;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingSampleId = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleSamplePlayback(SampleCry sample) async {
    if (_playingSampleId == sample.id && _player.playing) {
      await _player.stop();
      if (mounted) {
        setState(() => _playingSampleId = null);
      }
      return;
    }

    await _player.setAsset(sample.assetPath);
    await _player.play();
    if (mounted) {
      setState(() => _playingSampleId = sample.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(recordingFlowControllerProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'Cry Guide',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'A quick reference page for common cry categories, caregiver cues, and bundled sample audio you can use for testing.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          for (final sample in sampleCryCatalog) ...[
            _GuideCard(
              sample: sample,
              isPlaying: _playingSampleId == sample.id,
              onPlayPressed: () => _toggleSamplePlayback(sample),
              onAnalyzePressed: () => controller.analyzeSampleAsset(
                userId: widget.userId,
                assetPath: sample.assetPath,
                fileName: sample.fileName,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Testing note',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'These bundled sounds come from the public Donate-a-Cry corpus and are included to help you test the product flow quickly. They are examples, not medical truth and not a substitute for caregiver judgment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.sample,
    required this.isPlaying,
    required this.onPlayPressed,
    required this.onAnalyzePressed,
  });

  final SampleCry sample;
  final bool isPlaying;
  final VoidCallback onPlayPressed;
  final VoidCallback onAnalyzePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.title,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sample.soundLike,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(sample.topLabel)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sample.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 14),
            for (final detail in sample.details) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPlayPressed,
                  icon: Icon(
                    isPlaying ? Icons.stop_circle_outlined : Icons.play_circle,
                  ),
                  label: Text(isPlaying ? 'Stop sample' : 'Play sample'),
                ),
                FilledButton.icon(
                  onPressed: onAnalyzePressed,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Analyze sample'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
