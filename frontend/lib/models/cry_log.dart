import 'package:cloud_firestore/cloud_firestore.dart';

class CryLog {
  const CryLog({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.predictedLabel,
    required this.confidenceScore,
    required this.actualLabelFromUser,
    required this.audioStoragePath,
  });

  final String id;
  final String userId;
  final DateTime timestamp;
  final String predictedLabel;
  final double confidenceScore;
  final String? actualLabelFromUser;
  final String audioStoragePath;

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
    );
  }
}
