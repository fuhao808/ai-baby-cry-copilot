# AI Baby Cry Copilot Backend

## Local run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Environment

Copy `.env.example` and provide:

- `OPENAI_API_KEY`
- `OPENAI_MODEL` default is `gpt-4o-mini`

If `OPENAI_API_KEY` is missing, the API falls back to deterministic soothing advice so local development still works.

## Media support

- Audio upload: `.wav`, `.m4a`, `.mp3`, `.aac`, `.caf`, `.3gp`
- Video upload: `.mp4`, `.mov`, `.m4v`, `.avi`, `.mkv`, `.webm`

All supported inputs are normalized with `ffmpeg` into a 7-second mono 16kHz WAV before mock classification.

## Optional general audio screening

The backend now includes an optional `YAMNet`-style general audio screening hook for:

- adult speech
- impact / knock / tapping
- background or environmental noise

This is meant to improve the front-end gate before the baby-cry classifier runs.

If you want to enable that path locally, install:

```bash
pip install -r requirements-yamnet.txt
```

Then probe a file with:

```bash
python scripts_probe_general_audio.py /path/to/audio.wav
```

If the optional TensorFlow dependencies are not installed, the backend will silently fall back to the current heuristic screening path.

## Deploy

The included `Dockerfile` installs `ffmpeg` and is ready for container deployment on services like Cloud Run, Railway, Render, or Fly.io after the repo is pushed to GitHub.
