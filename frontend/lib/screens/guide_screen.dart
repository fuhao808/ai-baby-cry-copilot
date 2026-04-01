import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/sample_cry_catalog.dart';
import '../models/sample_cry.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/frosted_panel.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  late final AudioPlayer _player = AudioPlayer();
  String? _playingSampleId;
  String? _playbackError;
  String? _expandedSampleId;

  @override
  void initState() {
    super.initState();
    _configureAudio();
    _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingSampleId = null);
      }
    });
  }

  Future<void> _configureAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setVolume(1.0);
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

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      await _player.stop();
      await _player.setAudioSource(AudioSource.asset(sample.assetPath), preload: true);
      await _player.play();
      if (mounted) {
        setState(() {
          _playingSampleId = sample.id;
          _playbackError = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playingSampleId = null;
        _playbackError = 'Playback failed: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(recordingFlowControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        FrostedPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cry Library', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'Tap a card to open the meaning, hear a sample, and run a quick test.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
        if (_playbackError != null) ...[
          const SizedBox(height: 14),
          Text(
            _playbackError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        for (final sample in sampleCryCatalog) ...[
          _GuideCard(
            sample: sample,
            isPlaying: _playingSampleId == sample.id,
            isExpanded: _expandedSampleId == sample.id,
            onExpandPressed: () {
              setState(() {
                _expandedSampleId =
                    _expandedSampleId == sample.id ? null : sample.id;
              });
            },
            onPlayPressed: () => _toggleSamplePlayback(sample),
            onAnalyzePressed: () => controller.analyzeSampleAsset(
              userId: widget.userId,
              assetPath: sample.assetPath,
              fileName: sample.fileName,
            ),
          ),
          const SizedBox(height: 16),
        ],
        FrostedPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visual Cues', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _CueRow(
                title: 'Hungry',
                body: 'Rooting, hand-to-mouth, quick head turns, lip-smacking.',
              ),
              const SizedBox(height: 12),
              _CueRow(
                title: 'Sleepy',
                body: 'Rubbing eyes, zoning out, jerky movements, harder settling.',
              ),
              const SizedBox(height: 12),
              _CueRow(
                title: 'Pain / Gas',
                body: 'Leg tucking, arching back, sudden tense bursts, grimacing.',
              ),
              const SizedBox(height: 12),
              _CueRow(
                title: 'Fussy',
                body: 'General restlessness, squirming, overstimulation, position discomfort.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.sample,
    required this.isPlaying,
    required this.isExpanded,
    required this.onExpandPressed,
    required this.onPlayPressed,
    required this.onAnalyzePressed,
  });

  final SampleCry sample;
  final bool isPlaying;
  final bool isExpanded;
  final VoidCallback onExpandPressed;
  final VoidCallback onPlayPressed;
  final VoidCallback onAnalyzePressed;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      child: InkWell(
        onTap: onExpandPressed,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sample.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        sample.soundLike,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(label: Text(sample.topLabel)),
                    const SizedBox(height: 10),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sample.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPlayPressed,
                  icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(isPlaying ? 'Stop sample' : 'Play sample'),
                ),
                FilledButton.icon(
                  onPressed: onAnalyzePressed,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Analyze sample'),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    for (final detail in sample.details) ...[
                      _Bullet(text: detail),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 8,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
