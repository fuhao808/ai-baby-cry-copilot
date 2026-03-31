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

## Deploy

The included `Dockerfile` is ready for container deployment on services like Cloud Run, Railway, Render, or Fly.io after the repo is pushed to GitHub.
