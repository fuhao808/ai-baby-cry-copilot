class SampleCry {
  const SampleCry({
    required this.id,
    required this.title,
    required this.topLabel,
    required this.soundLike,
    required this.summary,
    required this.details,
    required this.assetPath,
    required this.fileName,
  });

  final String id;
  final String title;
  final String topLabel;
  final String soundLike;
  final String summary;
  final List<String> details;
  final String assetPath;
  final String fileName;
}
