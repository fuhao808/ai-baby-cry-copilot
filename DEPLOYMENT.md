# Deployment Notes

## Backend

The backend is already containerized with `backend/Dockerfile`.

Recommended deployment sequence:

1. Create a managed deployment target such as Cloud Run, Render, or Railway.
2. Add `OPENAI_API_KEY` and optionally `OPENAI_MODEL`.
3. Deploy the `backend/` service and note the public base URL.
4. Set Flutter `API_BASE_URL` to that backend URL.

## Firebase

Configure:

- Anonymous auth in Firebase Authentication
- Firestore database
- Cloud Storage bucket
- Android and iOS app registrations

## Frontend

Provide Firebase values through `--dart-define` as documented in `frontend/README.md`.

If you want fully automated production deployment after GitHub push, the next step is adding:

- CI workflow for backend container builds
- Fastlane or Codemagic for mobile builds
