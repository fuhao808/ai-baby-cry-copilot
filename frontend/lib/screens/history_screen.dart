import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../models/capture_media.dart';
import '../models/cry_log.dart';
import '../providers/recording_flow_controller.dart';
import '../widgets/frosted_panel.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final AudioPlayer _player = AudioPlayer();
  String? _playingLogId;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _configureAudio();
    _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed ||
          (!state.playing && _playingLogId != null && !_isBuffering)) {
        setState(() {
          _playingLogId = null;
          _isBuffering = false;
        });
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

  Future<void> _togglePlayback(CryLog log) async {
    if (_playingLogId == log.id && _player.playing) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playingLogId = null;
          _isBuffering = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _playingLogId = log.id;
        _isBuffering = true;
      });
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      final downloadUrl = await ref
          .read(cryLogServiceProvider)
          .getDownloadUrl(log.audioStoragePath);
      await _player.setUrl(downloadUrl);
      await _player.play();
      if (mounted) {
        setState(() => _isBuffering = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _playingLogId = null;
          _isBuffering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider(widget.userId));
    final formatter = DateFormat('MMM d, h:mm a');

    return historyAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FrostedPanel(
                child: Text(
                  'No cry logs yet. Record, upload, or run one of the bundled test samples first.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final log = logs[index];
            final isPlaying = _playingLogId == log.id;

            return FrostedPanel(
              radius: 36,
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      log.sourceType == CaptureSourceType.uploadedVideo
                          ? Icons.videocam_rounded
                          : Icons.graphic_eq_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.predictedLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log.screeningLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${formatter.format(log.timestamp)} • ${log.sourceFileName ?? 'live_capture.wav'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          log.cryDetected
                              ? 'Confidence ${(log.confidenceScore * 100).toStringAsFixed(0)}% • Feedback ${log.actualLabelFromUser ?? 'Pending'}'
                              : 'Confidence ${(log.confidenceScore * 100).toStringAsFixed(0)}% • Screened result',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () => _togglePlayback(log),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(70, 70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isBuffering && isPlaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('History failed: $error')),
    );
  }
}
