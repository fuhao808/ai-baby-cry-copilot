import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordService {
  RecordService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  Future<String> recordSevenSeconds({
    required void Function(int remainingSeconds) onTick,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final outputPath =
        '${tempDirectory.path}/cry_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: outputPath,
    );

    for (var remaining = 7; remaining >= 1; remaining--) {
      onTick(remaining);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    return await _recorder.stop() ?? outputPath;
  }

  Future<void> dispose() => _recorder.dispose();
}
