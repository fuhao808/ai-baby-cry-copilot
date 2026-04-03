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
      if (sample.previewStartSeconds > 0) {
        await _player.seek(Duration(milliseconds: (sample.previewStartSeconds * 1000).round()));
      }
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        FrostedPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Tap a card to open the meaning and hear a sample.',
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
          ),
          const SizedBox(height: 16),
        ],
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
  });

  final SampleCry sample;
  final bool isPlaying;
  final bool isExpanded;
  final VoidCallback onExpandPressed;
  final VoidCallback onPlayPressed;

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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sample.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'VISUAL CUES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 3.0,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.26),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                sample.visualCue,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onExpandPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
                label: Text(
                  isExpanded ? 'Hide notes' : 'More notes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.82),
                      ),
                ),
              ),
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
