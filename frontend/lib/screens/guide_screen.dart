import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/sample_cry_catalog.dart';
import '../models/sample_cry.dart';
import '../widgets/frosted_panel.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  late final AudioPlayer _player = AudioPlayer();
  String? _playingSampleId;
  String? _playbackError;

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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cry Library',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Master the secret language of your little one.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w500,
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
            onPlayPressed: () => _toggleSamplePlayback(sample),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.sample,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  final SampleCry sample;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 42,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.24),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sample.pattern,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onPlayPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(54, 54),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            sample.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.58,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 26),
          Container(
            height: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.35),
          ),
          const SizedBox(height: 22),
          Text(
            'VISUAL CUES',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 4.2,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.22),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              sample.visualCues,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.44),
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
