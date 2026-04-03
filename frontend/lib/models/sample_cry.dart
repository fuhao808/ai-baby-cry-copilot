class SampleCry {
  const SampleCry({
    required this.id,
    required this.title,
    required this.topLabel,
    required this.soundLike,
    required this.summary,
    required this.details,
    required this.visualCue,
    required this.assetPath,
    required this.fileName,
    this.previewStartSeconds = 0,
  });

  final String id;
  final String title;
  final String topLabel;
  final String soundLike;
  final String summary;
  final List<String> details;
  final String visualCue;
  final String assetPath;
  final String fileName;
  final double previewStartSeconds;
}
