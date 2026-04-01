import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../models/cry_log.dart';
import '../providers/recording_flow_controller.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Cry History')),
      body: historyAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Text('No cry logs yet. Record or upload your first sample.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              final isPlaying = _playingLogId == log.id;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${log.predictedLabel} • ${(log.confidenceScore * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _togglePlayback(log),
                            icon: _isBuffering && isPlaying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  ),
                            label: Text(isPlaying ? 'Stop' : 'Replay'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(log.sourceType.label)),
                          if (log.sourceFileName != null)
                            Chip(label: Text(log.sourceFileName!)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${formatter.format(log.timestamp)}\n'
                        'User feedback: ${log.actualLabelFromUser ?? 'Pending'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('History failed: $error')),
      ),
    );
  }
}
