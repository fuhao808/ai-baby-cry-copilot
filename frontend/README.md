# AI Baby Cry Copilot Frontend

This is a hand-built Flutter MVP scaffold because the Flutter SDK was not available in the workspace during implementation.

## Required runtime config

Pass Firebase and backend settings with `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project.appspot.com \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_ANDROID_API_KEY=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_API_KEY=... \
  --dart-define=FIREBASE_IOS_APP_ID=... \
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.your.bundle
```

## Firebase usage

- Auth: anonymous sign-in
- Firestore collection: `cry_logs`
- Storage path: `cry-recordings/{user_id}/{record_id}.m4a`

## Next local step once Flutter is installed

1. Run `flutter create .` inside this `frontend/` folder if you want a full generated shell.
2. Add Android and iOS Firebase native config if your setup requires it.
3. Run `flutter pub get`.
4. Launch on iOS Simulator or Android Emulator.
