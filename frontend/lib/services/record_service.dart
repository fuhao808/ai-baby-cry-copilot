import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordService {
  RecordService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  Future<String> recordSevenSeconds({
    required void Function(int remainingSeconds) onTick,
    void Function(double level)? onAmplitude,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final outputPath =
        '${tempDirectory.path}/cry_${DateTime.now().millisecondsSinceEpoch}.m4a';

    StreamSubscription<Amplitude>? amplitudeSubscription;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: outputPath,
    );

    amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amplitude) {
      onAmplitude?.call(_normalizeAmplitude(amplitude));
    });

    for (var remaining = 7; remaining >= 1; remaining--) {
      onTick(remaining);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    await amplitudeSubscription.cancel();
    return await _recorder.stop() ?? outputPath;
  }

  Future<void> dispose() => _recorder.dispose();

  double _normalizeAmplitude(Amplitude amplitude) {
    final current = amplitude.current;
    if (current.isNaN || current.isInfinite) {
      return 0.04;
    }

    if (current <= 0) {
      return ((current + 60) / 60).clamp(0.04, 1.0);
    }

    return (current / (amplitude.max == 0 ? 100 : amplitude.max))
        .clamp(0.04, 1.0);
  }
}
