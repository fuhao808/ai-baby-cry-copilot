import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'app_environment_service.dart';

class RecordService {
  RecordService({AppEnvironmentService? environmentService})
      : _recorder = AudioRecorder(),
        _environmentService = environmentService ?? AppEnvironmentService();

  final AudioRecorder _recorder;
  final AppEnvironmentService _environmentService;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _outputPath;
  AudioSession? _audioSession;

  Future<String> startRecording({
    void Function(double level)? onAmplitude,
  }) async {
    final recordingSupported = await _environmentService.isRecordingSupported();
    if (!recordingSupported) {
      throw Exception(
        'Recording is not supported on the iOS Simulator. Use Upload, enable Test Mode, or run Baby No Cry on a physical iPhone.',
      );
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception(
        'Microphone permission denied. If you are testing on the iOS Simulator, also enable microphone access for Simulator in macOS System Settings and choose your Mac microphone in Simulator I/O settings.',
      );
    }

    final tempDirectory = await getTemporaryDirectory();
    final outputPath =
        '${tempDirectory.path}/cry_${DateTime.now().millisecondsSinceEpoch}.wav';
    _outputPath = outputPath;

    _audioSession ??= await AudioSession.instance;
    await _audioSession!.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
    await _audioSession!.setActive(true);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
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
    await _audioSession?.setActive(false);
    final resolved = stoppedPath ?? _outputPath;
    _outputPath = null;
    if (resolved == null) {
      throw Exception('No recording file was produced.');
    }
    final file = File(resolved);
    if (!await file.exists()) {
      throw Exception('The recording file could not be created.');
    }
    final size = await file.length();
    if (size == 0) {
      throw Exception(
        'The recording was empty. Check microphone access and, on iOS Simulator, confirm Simulator is allowed to use your Mac microphone.',
      );
    }
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
