# AI Baby Cry Copilot

Cross-platform MVP for recording a baby's cry, uploading saved videos, classifying the likely reason, generating short soothing suggestions, browsing a built-in cry guide, and collecting parent feedback to power a training data flywheel.

## Stack

- Frontend: Flutter
- Backend: FastAPI
- Auth / DB / Storage: Firebase Authentication, Firestore, Cloud Storage
- AI: mock cry classifier plus OpenAI-generated soothing advice
- Training: public Donate-a-Cry dataset baseline under `training/`

## Repository Layout

```text
ai-baby-cry-copilot/
├── backend/
├── frontend/
└── training/
```

## MVP Flow

1. User signs in anonymously.
2. User records 7 seconds of audio or uploads a saved video/audio clip.
3. Flutter uploads the selected media to the FastAPI backend.
4. Backend converts media into a normalized 7-second mono WAV, then returns cry-class probabilities and soothing advice.
5. Users can browse a built-in guide tab with category notes, sample playback, and bundled test cries.
6. Flutter stores the replayable audio track in Cloud Storage, plus the original uploaded source when applicable.
7. User submits correction feedback for future training.

## Firestore Schema

Collection: `cry_logs`

- `id` (`String`)
- `user_id` (`String`)
- `timestamp` (`DateTime`)
- `predicted_label` (`String`)
- `confidence_score` (`Double`)
- `actual_label_from_user` (`String?`)
- `audio_storage_path` (`String`)
- `source_type` (`String`)
- `source_storage_path` (`String?`)
- `source_file_name` (`String?`)

## Local Development

Backend instructions: [backend/README.md](backend/README.md)  
Frontend instructions: [frontend/README.md](frontend/README.md)
Training instructions: [training/README.md](training/README.md)

## Deployment

- Backend: build from `backend/Dockerfile` and deploy to Cloud Run, Render, Railway, Fly.io, or similar
- Frontend: build from Flutter for iOS and Android after Firebase credentials are configured

## Live Backend

- Cloud Run API: `https://ai-baby-cry-backend-695729621254.us-central1.run.app`
