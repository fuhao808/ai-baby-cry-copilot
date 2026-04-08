import 'dart:io';

import 'package:flutter/services.dart';

class AppEnvironmentService {
  static const MethodChannel _channel = MethodChannel('baby_no_cry/environment');

  Future<bool> isRecordingSupported() async {
    if (!Platform.isIOS) {
      return true;
    }

    try {
      final isSimulator = await _channel.invokeMethod<bool>('isIosSimulator');
      return !(isSimulator ?? false);
    } on PlatformException {
      return true;
    }
  }
}
