import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/analysis_result.dart';
import '../models/capture_media.dart';
import '../models/cry_log.dart';
import '../services/api_service.dart';
import '../services/app_environment_service.dart';
import '../services/auth_service.dart';
import '../services/cry_log_service.dart';
import '../services/media_picker_service.dart';
import '../services/record_service.dart';

enum RecordingPhase { idle, recording, paused, analyzing, result }

class RecordingFlowState {
  const RecordingFlowState({
    required this.phase,
    required this.secondsRemaining,
    required this.waveformLevels,
    this.result,
    this.errorMessage,
    this.audioPath,
    this.selectedFeedback,
    this.isSubmittingFeedback = false,
    this.activeSourceType,
  });

  final RecordingPhase phase;
  final int secondsRemaining;
  final List<double> waveformLevels;
  final AnalysisResult? result;
  final String? errorMessage;
  final String? audioPath;
  final String? selectedFeedback;
  final bool isSubmittingFeedback;
  final CaptureSourceType? activeSourceType;

  const RecordingFlowState.initial()
      : phase = RecordingPhase.idle,
        secondsRemaining = 0,
        waveformLevels = const [],
        result = null,
        errorMessage = null,
        audioPath = null,
        selectedFeedback = null,
        isSubmittingFeedback = false,
        activeSourceType = null;

  RecordingFlowState copyWith({
    RecordingPhase? phase,
    int? secondsRemaining,
    List<double>? waveformLevels,
    AnalysisResult? result,
    String? errorMessage,
    String? audioPath,
    String? selectedFeedback,
    bool? isSubmittingFeedback,
    CaptureSourceType? activeSourceType,
    bool clearResult = false,
    bool clearError = false,
    bool clearAudioPath = false,
    bool clearFeedback = false,
    bool clearSourceType = false,
    bool clearWaveform = false,
  }) {
    return RecordingFlowState(
      phase: phase ?? this.phase,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      waveformLevels:
          clearWaveform ? const [] : waveformLevels ?? this.waveformLevels,
      result: clearResult ? null : result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      selectedFeedback:
          clearFeedback ? null : selectedFeedback ?? this.selectedFeedback,
      isSubmittingFeedback: isSubmittingFeedback ?? this.isSubmittingFeedback,
      activeSourceType:
          clearSourceType ? null : activeSourceType ?? this.activeSourceType,
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final appEnvironmentServiceProvider = Provider<AppEnvironmentService>(
  (ref) => AppEnvironmentService(),
);
final cryLogServiceProvider = Provider<CryLogService>((ref) => CryLogService());
final mediaPickerServiceProvider =
    Provider<MediaPickerService>((ref) => MediaPickerService());
final recordServiceProvider = Provider<RecordService>(
  (ref) {
    final service = RecordService(
      environmentService: ref.watch(appEnvironmentServiceProvider),
    );
    ref.onDispose(() {
      service.dispose();
    });
    return service;
  },
);

final recordingSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(appEnvironmentServiceProvider).isRecordingSupported(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final historyProvider = StreamProvider.family<List<CryLog>, String>(
  (ref, userId) => ref.watch(cryLogServiceProvider).watchHistory(userId),
);

final recordingFlowControllerProvider =
    StateNotifierProvider<RecordingFlowController, RecordingFlowState>(
  (ref) => RecordingFlowController(
    apiService: ref.watch(apiServiceProvider),
    cryLogService: ref.watch(cryLogServiceProvider),
    mediaPickerService: ref.watch(mediaPickerServiceProvider),
    recordService: ref.watch(recordServiceProvider),
  ),
);

class RecordingFlowController extends StateNotifier<RecordingFlowState> {
  RecordingFlowController({
    required ApiService apiService,
    required CryLogService cryLogService,
    required MediaPickerService mediaPickerService,
    required RecordService recordService,
  })  : _apiService = apiService,
        _cryLogService = cryLogService,
        _mediaPickerService = mediaPickerService,
        _recordService = recordService,
        super(const RecordingFlowState.initial());

  final ApiService _apiService;
  final CryLogService _cryLogService;
  final MediaPickerService _mediaPickerService;
  final RecordService _recordService;
  Timer? _countdownTimer;
  String? _capturePath;
  String? _captureUserId;
  int _elapsedSeconds = 0;

  Future<void> startCapture(String userId) async {
    state = state.copyWith(
      phase: RecordingPhase.recording,
      secondsRemaining: 7,
      waveformLevels: _seedWaveform(),
      clearError: true,
      clearResult: true,
      clearAudioPath: true,
      clearFeedback: true,
      activeSourceType: CaptureSourceType.recordedAudio,
    );

    try {
      _captureUserId = userId;
      _elapsedSeconds = 0;
      final audioPath = await _recordService.startRecording(
        onAmplitude: _pushWaveformLevel,
      );
      _capturePath = audioPath;
      _startCountdown();
    } catch (error) {
      _clearCaptureState();
      state = state.copyWith(
        phase: RecordingPhase.idle,
        secondsRemaining: 0,
        clearWaveform: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> pauseCapture() async {
    if (state.phase != RecordingPhase.recording) {
      return;
    }

    try {
      _countdownTimer?.cancel();
      await _recordService.pauseRecording();
      state = state.copyWith(phase: RecordingPhase.paused);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> resumeCapture() async {
    if (state.phase != RecordingPhase.paused) {
      return;
    }

    try {
      await _recordService.resumeRecording();
      state = state.copyWith(phase: RecordingPhase.recording);
      _startCountdown();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> finishCapture() async {
    if (state.phase != RecordingPhase.recording &&
        state.phase != RecordingPhase.paused) {
      return;
    }

    final userId = _captureUserId;
    final capturePath = _capturePath;
    if (userId == null || capturePath == null) {
      return;
    }

    _countdownTimer?.cancel();

    try {
      final audioPath = await _recordService.stopRecording() ?? capturePath;
      _clearCaptureState();
      await _analyzeSelection(
        userId: userId,
        media: CaptureMedia(
          filePath: audioPath,
          sourceType: CaptureSourceType.recordedAudio,
        ),
      );
    } catch (error) {
      _clearCaptureState();
      state = state.copyWith(
        phase: RecordingPhase.idle,
        secondsRemaining: 0,
        clearWaveform: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> importMedia(String userId) async {
    state = state.copyWith(
      phase: RecordingPhase.idle,
      clearError: true,
      clearResult: true,
      clearAudioPath: true,
      clearFeedback: true,
      clearSourceType: true,
      clearWaveform: true,
    );

    try {
      final media = await _mediaPickerService.pickMedia();
      if (media == null) {
        return;
      }

      await _analyzeSelection(userId: userId, media: media);
    } catch (error) {
      state = state.copyWith(
        phase: RecordingPhase.idle,
        secondsRemaining: 0,
        clearWaveform: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> analyzeSampleAsset({
    required String userId,
    required String assetPath,
    required String fileName,
  }) async {
    state = state.copyWith(
      clearError: true,
      clearResult: true,
      clearAudioPath: true,
      clearFeedback: true,
      clearSourceType: true,
      clearWaveform: true,
    );

    try {
      final media = await _writeBundledSampleToTemp(
        assetPath: assetPath,
        fileName: fileName,
      );
      await _analyzeSelection(userId: userId, media: media);
    } catch (error) {
      state = state.copyWith(
        phase: RecordingPhase.idle,
        clearWaveform: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _analyzeSelection({
    required String userId,
    required CaptureMedia media,
  }) async {
    state = state.copyWith(
      phase: RecordingPhase.analyzing,
      secondsRemaining: 0,
      audioPath: media.filePath,
      activeSourceType: media.sourceType,
      clearError: true,
      clearResult: true,
      clearFeedback: true,
      clearWaveform: true,
    );

    try {
      final result = await _apiService.analyzeCry(media.filePath);
      final normalizedAudioPath = await _writeNormalizedAudioToTemp(result);
      final storagePath = await _cryLogService.uploadAudio(
        userId: userId,
        recordId: result.recordId,
        filePath: normalizedAudioPath,
      );
      final sourceStoragePath = media.sourceType == CaptureSourceType.recordedAudio
          ? null
          : await _cryLogService.uploadSourceMedia(
              userId: userId,
              recordId: result.recordId,
              filePath: media.filePath,
            );

      await _cryLogService.createCryLog(
        userId: userId,
        result: result,
        audioStoragePath: storagePath,
        sourceType: media.sourceType,
        sourceStoragePath: sourceStoragePath,
        sourceFileName: media.originalFileName,
      );

      state = state.copyWith(
        phase: RecordingPhase.result,
        result: result,
        audioPath: normalizedAudioPath,
        activeSourceType: media.sourceType,
      );
    } catch (error) {
      state = state.copyWith(
        phase: RecordingPhase.idle,
        secondsRemaining: 0,
        clearWaveform: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String> _writeNormalizedAudioToTemp(AnalysisResult result) async {
    final tempDirectory = await getTemporaryDirectory();
    final outputPath =
        '${tempDirectory.path}/${result.recordId}.${result.normalizedAudioFormat}';
    final bytes = base64Decode(result.normalizedAudioBase64);
    await File(outputPath).writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  Future<CaptureMedia> _writeBundledSampleToTemp({
    required String assetPath,
    required String fileName,
  }) async {
    final tempDirectory = await getTemporaryDirectory();
    final outputPath = '${tempDirectory.path}/$fileName';
    final byteData = await rootBundle.load(assetPath);
    await File(outputPath).writeAsBytes(
      byteData.buffer.asUint8List(),
      flush: true,
    );
    return CaptureMedia(
      filePath: outputPath,
      sourceType: CaptureSourceType.uploadedAudio,
      originalFileName: fileName,
    );
  }

  Future<void> submitFeedback({
    required String userId,
    required String actualLabel,
  }) async {
    final result = state.result;
    if (result == null) {
      return;
    }

    state = state.copyWith(isSubmittingFeedback: true);

    try {
      await _apiService.submitFeedback(
        recordId: result.recordId,
        userId: userId,
        actualLabel: actualLabel,
      );

      await _cryLogService.updateActualLabel(
        recordId: result.recordId,
        actualLabel: actualLabel,
      );

      state = state.copyWith(
        isSubmittingFeedback: false,
        selectedFeedback: actualLabel,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmittingFeedback: false,
        errorMessage: error.toString(),
      );
    }
  }

  void reset() {
    _clearCaptureState();
    state = const RecordingFlowState.initial();
  }

  void _pushWaveformLevel(double level) {
    final previous =
        state.waveformLevels.isEmpty ? 0.04 : state.waveformLevels.last;
    final smoothed = ((previous * 0.12) + (level * 0.88)).clamp(0.02, 1.0);
    final next = [...state.waveformLevels, smoothed].takeLast(72).toList();
    state = state.copyWith(
      waveformLevels: next,
      phase: state.phase == RecordingPhase.paused
          ? RecordingPhase.paused
          : RecordingPhase.recording,
      activeSourceType: CaptureSourceType.recordedAudio,
    );
  }

  List<double> _seedWaveform() =>
      List<double>.filled(72, 0.035, growable: false);

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.phase != RecordingPhase.recording) {
        return;
      }

      _elapsedSeconds += 1;
      final remaining = 7 - _elapsedSeconds;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(finishCapture());
        return;
      }

      state = state.copyWith(
        phase: RecordingPhase.recording,
        secondsRemaining: remaining,
        activeSourceType: CaptureSourceType.recordedAudio,
      );
    });
  }

  void _clearCaptureState() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _capturePath = null;
    _captureUserId = null;
    _elapsedSeconds = 0;
  }

  @override
  void dispose() {
    _clearCaptureState();
    super.dispose();
  }
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) {
      return this;
    }

    return skip(length - count);
  }
}
