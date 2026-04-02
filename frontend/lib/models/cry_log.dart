import 'package:cloud_firestore/cloud_firestore.dart';

import 'capture_media.dart';

class CryLog {
  const CryLog({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.predictedLabel,
    required this.confidenceScore,
    required this.actualLabelFromUser,
    required this.audioStoragePath,
    required this.analysisFamily,
    required this.screeningLabel,
    required this.cryDetected,
    required this.babyVoiceDetected,
    required this.sourceType,
    this.sourceStoragePath,
    this.sourceFileName,
  });

  final String id;
  final String userId;
  final DateTime timestamp;
  final String predictedLabel;
  final double confidenceScore;
  final String? actualLabelFromUser;
  final String audioStoragePath;
  final String analysisFamily;
  final String screeningLabel;
  final bool cryDetected;
  final bool babyVoiceDetected;
  final CaptureSourceType sourceType;
  final String? sourceStoragePath;
  final String? sourceFileName;

  factory CryLog.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};

    return CryLog(
      id: data['id'] as String? ?? document.id,
      userId: data['user_id'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      predictedLabel: data['predicted_label'] as String? ?? 'Unknown',
      confidenceScore: (data['confidence_score'] as num?)?.toDouble() ?? 0,
      actualLabelFromUser: data['actual_label_from_user'] as String?,
      audioStoragePath: data['audio_storage_path'] as String? ?? '',
      analysisFamily: data['analysis_family'] as String? ?? 'baby_cry',
      screeningLabel: data['screening_label'] as String? ?? 'Baby cry detected',
      cryDetected: data['cry_detected'] as bool? ?? true,
      babyVoiceDetected: data['baby_voice_detected'] as bool? ?? true,
      sourceType: CaptureSourceType.fromStorageValue(
        data['source_type'] as String? ?? CaptureSourceType.recordedAudio.storageValue,
      ),
      sourceStoragePath: data['source_storage_path'] as String?,
      sourceFileName: data['source_file_name'] as String?,
    );
  }
}
