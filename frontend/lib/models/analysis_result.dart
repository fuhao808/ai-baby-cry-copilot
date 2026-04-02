class AnalysisResult {
  const AnalysisResult({
    required this.recordId,
    required this.predictions,
    required this.topResult,
    required this.llmAdvice,
    required this.analysisFamily,
    required this.screeningLabel,
    required this.cryDetected,
    required this.babyVoiceDetected,
    required this.resultSummary,
    required this.normalizedAudioBase64,
    required this.normalizedAudioFormat,
    required this.sourceType,
  });

  final String recordId;
  final Map<String, double> predictions;
  final String topResult;
  final String llmAdvice;
  final String analysisFamily;
  final String screeningLabel;
  final bool cryDetected;
  final bool babyVoiceDetected;
  final String resultSummary;
  final String normalizedAudioBase64;
  final String normalizedAudioFormat;
  final String sourceType;

  double get confidenceScore => predictions[topResult] ?? 0;
  bool get requiresCryFeedback => cryDetected;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawPredictions = (json['predictions'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, (value as num).toDouble()));

    return AnalysisResult(
      recordId: json['record_id'] as String,
      predictions: rawPredictions,
      topResult: json['top_result'] as String,
      llmAdvice: json['llm_advice'] as String,
      analysisFamily: json['analysis_family'] as String? ?? 'baby_cry',
      screeningLabel: json['screening_label'] as String? ?? 'Baby cry detected',
      cryDetected: json['cry_detected'] as bool? ?? true,
      babyVoiceDetected: json['baby_voice_detected'] as bool? ?? true,
      resultSummary: json['result_summary'] as String? ??
          'An infant cry-like signal was detected.',
      normalizedAudioBase64: json['normalized_audio_base64'] as String? ?? '',
      normalizedAudioFormat: json['normalized_audio_format'] as String? ?? 'wav',
      sourceType: json['source_type'] as String? ?? 'uploaded_audio',
    );
  }
}
