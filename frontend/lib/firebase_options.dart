import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) {
      return android;
    }

    if (Platform.isIOS) {
      return ios;
    }

    throw UnsupportedError('This MVP currently supports only iOS and Android.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: 'demo-android-api-key'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:1234567890:android:demo'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '1234567890'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'demo-baby-cry'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'demo-baby-cry.appspot.com'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: 'demo-ios-api-key'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:1234567890:ios:demo'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '1234567890'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'demo-baby-cry'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'demo-baby-cry.appspot.com'),
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.example.aiBabyCryCopilot',
    ),
  );
}
