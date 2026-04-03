import 'dart:async';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordService {
  RecordService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _outputPath;

  Future<String> startRecording({
    void Function(double level)? onAmplitude,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final outputPath =
        '${tempDirectory.path}/cry_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _outputPath = outputPath;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: outputPath,
    );

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 24))
        .listen((amplitude) {
      onAmplitude?.call(_normalizeAmplitude(amplitude));
    });

    return outputPath;
  }

  Future<void> pauseRecording() => _recorder.pause();

  Future<void> resumeRecording() => _recorder.resume();

  Future<String?> stopRecording() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final stoppedPath = await _recorder.stop();
    final resolved = stoppedPath ?? _outputPath;
    _outputPath = null;
    return resolved;
  }

  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _recorder.dispose();
  }

  double _normalizeAmplitude(Amplitude amplitude) {
    final current = amplitude.current;
    if (current.isNaN || current.isInfinite) {
      return 0.02;
    }

    if (current <= 0) {
      final db = current.clamp(-55.0, 0.0);
      final linear = math.pow(10, db / 20).toDouble();
      final boosted = math.pow(linear, 0.48).toDouble();
      return boosted.clamp(0.02, 1.0);
    }

    final ratio = current / (amplitude.max == 0 ? 100 : amplitude.max);
    return math.pow(ratio.clamp(0.0, 1.0), 0.42).toDouble().clamp(0.02, 1.0);
  }
}
