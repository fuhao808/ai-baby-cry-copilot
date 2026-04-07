import 'package:flutter_test/flutter_test.dart';

import 'package:ai_baby_cry_copilot/models/analysis_result.dart';

void main() {
  test('AnalysisResult parses cry response payload', () {
    final result = AnalysisResult.fromJson(
      {
        'record_id': 'record-123',
        'predictions': {
          'Hungry': 0.81,
          'Sleepy': 0.1,
          'Pain/Gas': 0.05,
          'Fussy': 0.04,
        },
        'top_result': 'Hungry',
        'llm_advice': 'Try feeding soon.',
        'analysis_family': 'baby_cry',
        'screening_label': 'Baby cry detected',
        'cry_detected': true,
        'baby_voice_detected': true,
        'result_summary': 'Infant cry-like signal detected.',
        'detected_sound': 'Infant cry-like vocal pattern',
        'primary_pattern': 'neh',
        'phonetic_patterns': ['neh'],
        'mixed_types': ['Sleepy'],
        'normalized_audio_base64': 'ZmFrZQ==',
        'normalized_audio_format': 'wav',
        'source_type': 'uploaded_audio',
      },
    );

    expect(result.recordId, 'record-123');
    expect(result.topResult, 'Hungry');
    expect(result.confidenceScore, 0.81);
    expect(result.requiresCryFeedback, isTrue);
    expect(result.phoneticPatterns, ['neh']);
    expect(result.mixedTypes, ['Sleepy']);
    expect(result.normalizedAudioBase64, isNotEmpty);
  });
}
