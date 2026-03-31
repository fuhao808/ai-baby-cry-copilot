# AI Baby Cry Copilot

Cross-platform MVP for recording a baby's cry, classifying the likely reason, generating short soothing suggestions, and collecting parent feedback to power a training data flywheel.

## Stack

- Frontend: Flutter
- Backend: FastAPI
- Auth / DB / Storage: Firebase Authentication, Firestore, Cloud Storage
- AI: mock cry classifier plus OpenAI-generated soothing advice

## Repository Layout

```text
ai-baby-cry-copilot/
├── backend/
└── frontend/
```

## MVP Flow

1. User signs in anonymously.
2. User records 7 seconds of audio.
3. Flutter uploads audio to the FastAPI backend.
4. Backend returns cry-class probabilities and soothing advice.
5. Flutter stores the log in Firestore and audio in Cloud Storage.
6. User submits correction feedback for future training.

## Firestore Schema

Collection: `cry_logs`

- `id` (`String`)
- `user_id` (`String`)
- `timestamp` (`DateTime`)
- `predicted_label` (`String`)
- `confidence_score` (`Double`)
- `actual_label_from_user` (`String?`)
- `audio_storage_path` (`String`)

## Local Development

Backend instructions: [backend/README.md](backend/README.md)  
Frontend instructions: [frontend/README.md](frontend/README.md)

## Deployment

- Backend: build from `backend/Dockerfile` and deploy to Cloud Run, Render, Railway, Fly.io, or similar
- Frontend: build from Flutter for iOS and Android after Firebase credentials are configured
