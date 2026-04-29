# UichaaMusic

A personal-use mobile music client backed by a self-hosted FastAPI service that wraps `ytmusicapi` + `yt-dlp`. See [`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`](docs/superpowers/specs/2026-04-29-yt-music-client-design.md) for the full design.

## Layout

- `backend/` — FastAPI service
- `pot-provider/` — `bgutil-ytdlp-pot-provider` sidecar (PO token minting)
- `app/` — Flutter app
- `docs/` — design specs and plans

## Phase 0: Foundations

See [`docs/superpowers/plans/2026-04-29-phase-0-foundations.md`](docs/superpowers/plans/2026-04-29-phase-0-foundations.md).
