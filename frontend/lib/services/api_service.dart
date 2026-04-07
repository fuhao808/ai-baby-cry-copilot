import 'dart:io';

import 'package:dio/dio.dart';

import '../models/analysis_result.dart';

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue:
                  'https://ai-baby-cry-backend-695729621254.us-central1.run.app',
            ),
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  Future<AnalysisResult> analyzeCry(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('The selected recording could not be found.');
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception(
        'The recording is empty. Please allow microphone access and try again.',
      );
    }

    final formData = FormData.fromMap(
      {
        'media': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      },
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/analyze',
        data: formData,
      );

      return AnalysisResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw Exception(_describeDioError(error));
    }
  }

  Future<void> submitFeedback({
    required String recordId,
    required String userId,
    required String actualLabel,
  }) async {
    try {
      await _dio.post<void>(
        '/api/v1/feedback',
        data: {
          'record_id': recordId,
          'user_id': userId,
          'actual_label': actualLabel,
        },
      );
    } on DioException catch (error) {
      throw Exception(_describeDioError(error));
    }
  }

  String _describeDioError(DioException error) {
    final response = error.response;
    final payload = response?.data;
    String? detail;

    if (payload is Map<String, dynamic>) {
      final rawDetail = payload['detail'];
      if (rawDetail is String && rawDetail.isNotEmpty) {
        detail = rawDetail;
      }
    } else if (payload is String && payload.isNotEmpty) {
      detail = payload;
    }

    if (response != null) {
      final statusCode = response.statusCode ?? 0;
      return 'Request failed ($statusCode): ${detail ?? error.message ?? 'Unknown server error.'}';
    }

    return error.message ?? 'Network request failed.';
  }
}
