import 'package:dio/dio.dart';

import '../models/analysis_result.dart';

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            ),
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  Future<AnalysisResult> analyzeCry(String filePath) async {
    final formData = FormData.fromMap(
      {
        'audio': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      },
    );

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/analyze',
      data: formData,
    );

    return AnalysisResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> submitFeedback({
    required String recordId,
    required String userId,
    required String actualLabel,
  }) async {
    await _dio.post<void>(
      '/api/v1/feedback',
      data: {
        'record_id': recordId,
        'user_id': userId,
        'actual_label': actualLabel,
      },
    );
  }
}
