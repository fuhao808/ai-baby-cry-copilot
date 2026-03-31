class AnalysisResult {
  const AnalysisResult({
    required this.recordId,
    required this.predictions,
    required this.topResult,
    required this.llmAdvice,
  });

  final String recordId;
  final Map<String, double> predictions;
  final String topResult;
  final String llmAdvice;

  double get confidenceScore => predictions[topResult] ?? 0;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawPredictions = (json['predictions'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, (value as num).toDouble()));

    return AnalysisResult(
      recordId: json['record_id'] as String,
      predictions: rawPredictions,
      topResult: json['top_result'] as String,
      llmAdvice: json['llm_advice'] as String,
    );
  }
}
