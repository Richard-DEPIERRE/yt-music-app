# UichaaMusic

A personal-use mobile music client backed by a self-hosted FastAPI service that wraps `ytmusicapi` + `yt-dlp`. See [`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`](docs/superpowers/specs/2026-04-29-yt-music-client-design.md) for the full design.

## Layout

- `backend/` — FastAPI service
- `pot-provider/` — `bgutil-ytdlp-pot-provider` sidecar (PO-token minting)
- `app/` — Flutter app (added in later phases)
- `docs/` — design specs and plans

## Phase 0 setup

### 1. Bring up the homelab stack

```bash
docker compose up -d --build
curl -s http://localhost:8001/v1/health
```

You should see `{"status":"degraded","auth_status":"expired",...}`. That means the backend is alive but no cookies are loaded yet.

### 2. Cloudflare Tunnel

We assume you already have `cloudflared` running on the homelab. Add a public hostname routing your chosen subdomain (example: `ytmusic.example.com`) to `http://localhost:8001`:

- Cloudflare Zero Trust dashboard → Networks → Tunnels → your tunnel → Public Hostname → Add
- Subdomain: `ytmusic`
- Domain: your zone
- Service: `HTTP`, URL: `localhost:8001`

### 3. Cloudflare Access

Create an Access Application gating the new hostname:

- Zero Trust → Access → Applications → Add an application → Self-hosted
- Application name: `UichaaMusic`
- Session duration: 24h (or whatever)
- Application domain: `ytmusic.example.com`
- Path: leave blank to cover everything (including `/admin/*`)

Add a service-token-based policy (used by the mobile app):

- Policies → Add a policy → Name: "App + admin"
- Action: Allow
- Selector: **Service Token** → pick "Create a service token"
  - Name: `uichaa-music-mobile`
  - Save and **copy the Client ID + Client Secret immediately** (the secret is only shown once)

Add a second policy for browser access to `/admin` (so you can use the cookie-refresh page from a laptop without the service token):

- Policies → Add a policy → Name: "Admin browser"
- Action: Allow
- Selector: Emails → your email

### 4. Verify Access

From your laptop (logged in via the email policy):

```
https://ytmusic.<your-zone>/admin
```

You should see the admin page. Paste a "Copy as cURL (bash)" from Chrome DevTools after browsing music.youtube.com → click Save & test. The auth status should flip to `ok` within `AUTH_HEALTH_INTERVAL` seconds (default 900 s = 15 minutes).

From a terminal (using the service token):

```bash
CFID="<paste Client-Id>"
CFSECRET="<paste Client-Secret>"
curl -s \
  -H "CF-Access-Client-Id: $CFID" \
  -H "CF-Access-Client-Secret: $CFSECRET" \
  https://ytmusic.<your-zone>/v1/health
```

Should return the same JSON as the localhost call.

### 5. Configure the Flutter app

On first launch the app shows an Onboarding screen. Enter:

- Base URL: `https://ytmusic.<your-zone>`
- CF Access Client ID
- CF Access Client Secret

The app stores these in iOS Keychain / Android Keystore. The Health screen then ticks live from `/v1/health`.

## Dev workflow

- Backend: `cd backend && uv sync --extra dev && uv run pytest`
- Flutter app: `cd app && flutter pub get && flutter test` *(after Phase 0 Task 11)*
- Stack up: `docker compose up -d --build`
- Stack down: `docker compose down`

## Phase 0 implementation plan

See [`docs/superpowers/plans/2026-04-29-phase-0-foundations.md`](docs/superpowers/plans/2026-04-29-phase-0-foundations.md).
