# AI Baby Cry Copilot Frontend

Flutter client for:

- 7-second live recording
- Video or audio upload from local storage
- System-adaptive theming with selectable light-first palettes
- Replayable audio history stored in Firebase Storage
- A second `Guide` tab with common cry categories, quick explanations, bundled sample playback, and sample-driven testing

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
- Storage path for replayable audio: `cry-recordings/{user_id}/{record_id}.wav`
- Storage path for uploaded source media: `cry-source-media/{user_id}/{record_id}.{ext}`

## Local run

```bash
flutter pub get
flutter run -d emulator-5554
```

## Notes

- The app follows system light or dark mode automatically.
- Users can pick one of four palette families in-app: Cloud, Butter, Lavender, Sage.
- Uploaded videos are sent to the backend, where the audio track is extracted for analysis.
- The `Guide` tab bundles four public sample cries so you can test analysis without collecting new recordings first.
