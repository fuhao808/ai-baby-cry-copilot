import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis_result.dart';
import '../models/cry_log.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cry_log_service.dart';
import '../services/record_service.dart';

enum RecordingPhase { idle, recording, analyzing, result }

class RecordingFlowState {
  const RecordingFlowState({
    required this.phase,
    required this.secondsRemaining,
    this.result,
    this.errorMessage,
    this.audioPath,
    this.selectedFeedback,
    this.isSubmittingFeedback = false,
  });

  final RecordingPhase phase;
  final int secondsRemaining;
  final AnalysisResult? result;
  final String? errorMessage;
  final String? audioPath;
  final String? selectedFeedback;
  final bool isSubmittingFeedback;

  const RecordingFlowState.initial()
      : phase = RecordingPhase.idle,
        secondsRemaining = 0,
        result = null,
        errorMessage = null,
        audioPath = null,
        selectedFeedback = null,
        isSubmittingFeedback = false;

  RecordingFlowState copyWith({
    RecordingPhase? phase,
    int? secondsRemaining,
    AnalysisResult? result,
    String? errorMessage,
    String? audioPath,
    String? selectedFeedback,
    bool? isSubmittingFeedback,
    bool clearResult = false,
    bool clearError = false,
    bool clearAudioPath = false,
    bool clearFeedback = false,
  }) {
    return RecordingFlowState(
      phase: phase ?? this.phase,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      result: clearResult ? null : result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      selectedFeedback:
          clearFeedback ? null : selectedFeedback ?? this.selectedFeedback,
      isSubmittingFeedback:
          isSubmittingFeedback ?? this.isSubmittingFeedback,
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final cryLogServiceProvider = Provider<CryLogService>((ref) => CryLogService());
final recordServiceProvider = Provider<RecordService>(
  (ref) {
    final service = RecordService();
    ref.onDispose(() {
      service.dispose();
    });
    return service;
  },
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
    recordService: ref.watch(recordServiceProvider),
  ),
);

class RecordingFlowController extends StateNotifier<RecordingFlowState> {
  RecordingFlowController({
    required ApiService apiService,
    required CryLogService cryLogService,
    required RecordService recordService,
  })  : _apiService = apiService,
        _cryLogService = cryLogService,
        _recordService = recordService,
        super(const RecordingFlowState.initial());

  final ApiService _apiService;
  final CryLogService _cryLogService;
  final RecordService _recordService;

  Future<void> startCapture(String userId) async {
    state = state.copyWith(
      phase: RecordingPhase.recording,
      secondsRemaining: 7,
      clearError: true,
      clearResult: true,
      clearAudioPath: true,
      clearFeedback: true,
    );

    try {
      final audioPath = await _recordService.recordSevenSeconds(
        onTick: (remaining) {
          state = state.copyWith(
            phase: RecordingPhase.recording,
            secondsRemaining: remaining,
          );
        },
      );

      state = state.copyWith(
        phase: RecordingPhase.analyzing,
        secondsRemaining: 0,
        audioPath: audioPath,
      );

      final result = await _apiService.analyzeCry(audioPath);
      final storagePath = await _cryLogService.uploadAudio(
        userId: userId,
        recordId: result.recordId,
        filePath: audioPath,
      );

      await _cryLogService.createCryLog(
        userId: userId,
        result: result,
        audioStoragePath: storagePath,
      );

      state = state.copyWith(
        phase: RecordingPhase.result,
        result: result,
        audioPath: audioPath,
      );
    } catch (error) {
      state = state.copyWith(
        phase: RecordingPhase.idle,
        secondsRemaining: 0,
        errorMessage: error.toString(),
      );
    }
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
    state = const RecordingFlowState.initial();
  }
}
