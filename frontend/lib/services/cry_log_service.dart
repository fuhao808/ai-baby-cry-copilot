import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/analysis_result.dart';
import '../models/cry_log.dart';

class CryLogService {
  CryLogService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<String> uploadAudio({
    required String userId,
    required String recordId,
    required String filePath,
  }) async {
    final extension = filePath.split('.').last;
    final ref = _storage.ref('cry-recordings/$userId/$recordId.$extension');
    await ref.putFile(File(filePath));
    return ref.fullPath;
  }

  Future<void> createCryLog({
    required String userId,
    required AnalysisResult result,
    required String audioStoragePath,
  }) async {
    await _firestore.collection('cry_logs').doc(result.recordId).set(
      {
        'id': result.recordId,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'predicted_label': result.topResult,
        'confidence_score': result.confidenceScore,
        'actual_label_from_user': null,
        'audio_storage_path': audioStoragePath,
      },
    );
  }

  Future<void> updateActualLabel({
    required String recordId,
    required String actualLabel,
  }) async {
    await _firestore.collection('cry_logs').doc(recordId).update(
      {'actual_label_from_user': actualLabel},
    );
  }

  Stream<List<CryLog>> watchHistory(String userId) {
    return _firestore
        .collection('cry_logs')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CryLog.fromFirestore)
              .toList(growable: false),
        );
  }
}
