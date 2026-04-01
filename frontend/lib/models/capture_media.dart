enum CaptureSourceType {
  recordedAudio('recorded_audio'),
  uploadedAudio('uploaded_audio'),
  uploadedVideo('uploaded_video');

  const CaptureSourceType(this.storageValue);

  final String storageValue;

  String get label => switch (this) {
        CaptureSourceType.recordedAudio => 'Live recording',
        CaptureSourceType.uploadedAudio => 'Uploaded audio',
        CaptureSourceType.uploadedVideo => 'Uploaded video',
      };

  static CaptureSourceType fromStorageValue(String value) {
    return CaptureSourceType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => CaptureSourceType.recordedAudio,
    );
  }
}

class CaptureMedia {
  const CaptureMedia({
    required this.filePath,
    required this.sourceType,
    this.originalFileName,
  });

  final String filePath;
  final CaptureSourceType sourceType;
  final String? originalFileName;
}
