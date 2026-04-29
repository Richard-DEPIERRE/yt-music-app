# yt-music-api

FastAPI backend wrapping `ytmusicapi`.

## Dev setup

```bash
cd backend
uv sync --extra dev
uv run ruff check .
uv run pytest
uv run uvicorn ytmusic_api.main:app --reload --port 8000
```

## Tests

```bash
uv run pytest
```
