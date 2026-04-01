import 'package:file_picker/file_picker.dart';

import '../models/capture_media.dart';

class MediaPickerService {
  Future<CaptureMedia?> pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'wav',
        'm4a',
        'mp3',
        'aac',
        'caf',
        '3gp',
        'mp4',
        'mov',
        'm4v',
        'avi',
        'mkv',
        'webm',
      ],
    );

    final picked = result?.files.single;
    final path = picked?.path;
    if (picked == null || path == null) {
      return null;
    }

    final lowerName = picked.name.toLowerCase();
    final sourceType = lowerName.endsWith('.mp4') ||
            lowerName.endsWith('.mov') ||
            lowerName.endsWith('.m4v') ||
            lowerName.endsWith('.avi') ||
            lowerName.endsWith('.mkv') ||
            lowerName.endsWith('.webm')
        ? CaptureSourceType.uploadedVideo
        : CaptureSourceType.uploadedAudio;

    return CaptureMedia(
      filePath: path,
      sourceType: sourceType,
      originalFileName: picked.name,
    );
  }
}
