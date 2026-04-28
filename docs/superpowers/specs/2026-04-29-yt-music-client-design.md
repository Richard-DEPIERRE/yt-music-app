# UichaaMusic — Personal YouTube Music Client Design Spec

**Date:** 2026-04-29
**Author:** Richard Dépierre
**Status:** Approved (design phase). Implementation plan to follow.
**Bundle ID (iOS):** `com.richarddepierre.ytmusic`
**App display name:** UichaaMusic

## 1. Overview

A personal-use mobile music client (Flutter, iOS-primary + Android-secondary) replacing the official YT Music app. Backed by a self-hosted FastAPI service in a homelab that wraps `ytmusicapi` (metadata, library, recommendations, mutations) and `yt-dlp` + `bgutil-ytdlp-pot-provider` (stream URL resolution). The user has a YouTube Premium account and uses its high-quality audio + ad-free benefits.

Single user. Sideloaded. Personal use. Not distributed.

### 1.1 High-level architecture

```
┌──────────────────────────┐                            ┌────────────────────────────┐
│ Flutter app (iOS+Android)│  CF-Access service token   │       Homelab               │
│                          │ ─────────────────────────► │  ┌──────────────────────┐  │
│  UI (Riverpod)           │   via Cloudflare Tunnel    │  │  yt-music-api        │  │
│  Repositories            │ ◄─────────────────────────►│  │  (FastAPI, Python)   │  │
│  Drift (local DB)        │                            │  │  ytmusicapi + yt-dlp │  │
│  just_audio +            │                            │  └─────┬────────────────┘  │
│  audio_service           │                            │        │ HTTP (internal)   │
│  background_downloader   │                            │  ┌─────▼────────────────┐  │
└──────┬───────────────────┘                            │  │  pot-provider        │  │
       │                                                │  │  (headless Chrome)   │  │
       │  resolved stream URL (signed, ~30 min TTL)     │  └──────────────────────┘  │
       ▼                                                └────────────────────────────┘
   googlevideo.com  (direct fetch, cellular or wifi)
```

Three processes in homelab Docker Compose, only `yt-music-api` exposed (via Cloudflare Tunnel + CF Access). Phone fetches metadata through CF; audio bytes go phone↔googlevideo directly. Cookies and PO tokens never leave the homelab.

### 1.2 Key architectural decisions (with rationale)

| Decision | Choice | Rationale |
|---|---|---|
| Backend role | URL resolver (not byte proxy) | Bandwidth, simplicity. Failure mode "fall back to official app for an hour" is acceptable per user. |
| Backend lang | **Python + FastAPI** | `ytmusicapi` is the canonical YT Music client; `yt-dlp` outpaces alternatives on Google-side breakage by weeks. |
| Network ingress | **Cloudflare Tunnel + CF Access service token** | Reuses existing CF setup; no Tailscale client + battery drain on phone; CF Access at edge replaces in-app bearer. Audio doesn't traverse CF, so ToS clauses on media don't apply. |
| Do NOT route through commercial VPN | Confirmed | Premium account binding + VPN exit fingerprinting = high ban risk. NordVPN keeps doing torrent duty only. |
| PO token | Sidecar (`bgutil-ytdlp-pot-provider`) | Crash isolation from FastAPI; Chromium has different failure semantics. |
| Cookie auth | Browser-extracted headers, manual refresh | OAuth path retired by Google in 2024–25 for `ytmusicapi`-style clients. Refresh ritual via small admin page on the same FastAPI app. |
| Local DB | **Drift** (not Isar) | Isar v3 dormant, v4 in long beta; Drift is actively maintained, fast enough for ~10k tracks. |
| State management | **Riverpod** (with `riverpod_generator`) | User competency; compile-time provider graph; fine-grained rebuilds. (GetX explicitly rejected.) |
| Downloader | **`background_downloader`** | Resumable, BG-safe on iOS via URLSession config. |
| State sync (offline writes) | **Online-only** for v1 (option A); option B (optimistic + queue) deferred. | Mostly online; complexity not worth it now. API surface won't preclude B. |
| File layout | Flat by `videoId` | Dedup, rename-freedom, Drift is the index. |
| Download tagging | **No ffmpeg, no remux** | `ffmpeg_kit_flutter` archived 2025; opus-in-WebM stored as `.webm`, AAC as `.m4a`. Drift is the source of truth for metadata. Files are weakly identifiable outside the app — acceptable for personal use. |
| iOS distribution | Paid Apple Developer account ($99/yr) | The 7-day re-sign dance is misery. |
| Repo layout | **Mono-repo** (`yt-music-app`) | Atomic cross-side commits; one issue tracker; no version coordination tax. |

## 2. Backend API surface

All endpoints prefixed with `/v1/`. Auth: Cloudflare Access service-token headers (`CF-Access-Client-Id`, `CF-Access-Client-Secret`) on every request, enforced at the CF edge.

### 2.1 Endpoint inventory

| Group | Method + Path | Purpose |
|---|---|---|
| Catalog | `GET /search?q=&type=&limit=` | Search; `type` ∈ {song, album, artist, playlist, all} |
| | `GET /track/{videoId}` | Track metadata |
| | `GET /album/{browseId}` | Album + tracklist |
| | `GET /playlist/{browseId}?continuation=` | Playlist with paging |
| | `GET /artist/{browseId}` | Artist page |
| Streaming | `GET /track/{videoId}/stream?codec=&quality=` | Resolved playback URL (see §2.2) |
| Library (read) | `GET /library/liked?continuation=` | Liked songs |
| | `GET /library/playlists` | User playlists (titles only) |
| | `GET /library/playlists/{id}?continuation=` | One playlist, paged |
| | `GET /library/subscriptions` | Subscribed artists |
| | `GET /library/history` | Recently played |
| | `GET /library/snapshot` | One-shot full backup of account state as JSON. Phase-4 prerequisite. |
| Library (write) | `POST /library/like` `{videoId}` | Like (idempotent) |
| | `DELETE /library/like/{videoId}` | Unlike |
| | `POST /library/playlists` `{title, description, privacy}` | Create playlist |
| | `DELETE /library/playlists/{id}` | Delete playlist |
| | `POST /library/playlists/{id}/tracks` `{videoIds:[]}` | Add tracks |
| | `DELETE /library/playlists/{id}/tracks` `{setVideoIds:[]}` | Remove tracks (uses YT's per-occurrence `setVideoId`) |
| Discovery | `GET /home` | Home feed sections |
| | `GET /radio?seedVideoId=` | Radio queue |
| | `GET /up-next?videoId=&radio=` | Watch-next continuation |
| Downloads | `POST /downloads/manifest` | Bulk stream-URL resolution (see §6) |
| Ops | `GET /health` | `{auth_status, last_ok_at, pot_provider_ok, version}` |
| | `POST /admin/cookies/refresh` | Programmatic refresh trigger (admin page also serves UI) |
| Admin UI | `GET /admin/*` | Server-rendered (Jinja2) cookie-refresh page; behind same CF Access policy |

### 2.2 `/stream` contract

Request:
```
GET /v1/track/{videoId}/stream?codec=opus&quality=high
```

- `codec` ∈ {`aac`, `opus`, `any`} (default `any`)
- `quality` ∈ {`high`, `medium`, `low`} (default `high`)

Response 200:
```json
{
  "videoId": "abc123XYZ",
  "url": "https://rr3---sn-xxxx.googlevideo.com/videoplayback?...",
  "expiresAt": "2026-04-29T17:42:00Z",
  "codec": "opus",
  "container": "webm",
  "bitrate": 160000,
  "approxDurationMs": 213000,
  "contentLength": 4321234
}
```

Best-effort negotiation: if requested codec/quality unavailable, server returns the next-best option, *not* a 404. Client reads `codec`/`bitrate` from the response.

Server is stateless about streams. Client handles 403/410 from googlevideo by re-requesting `/stream`.

### 2.3 List pagination

All list endpoints return `{"items": [...], "continuation": "<opaque-or-null>"}`. Client passes `?continuation=<token>` for next page; null means done. Token is whatever `ytmusicapi` returned — passed through unchanged.

### 2.4 Error model

Single shape across all endpoints:
```json
{ "error": "cookies_expired", "message": "...", "retryable": false }
```

| Code | HTTP | Client behavior |
|---|---|---|
| `cookies_expired` | 401 | Show top banner: "YT Music auth needs refresh on homelab." |
| `pot_token_failed` | 503 | Retry with exponential backoff |
| `rate_limited` | 429 | Exponential backoff |
| `upstream_breakage` | 502 | Catch-all for unrecognized `ytmusicapi`/`yt-dlp` errors. Log loudly — this is the canary for Google-side breakage. |
| `not_found` | 404 | Inline error |

### 2.5 Caching (server-side, SQLite)

| Endpoint | TTL | Notes |
|---|---|---|
| `/search` | 5 min | Keyed by exact query string |
| `/track`, `/album`, `/playlist`, `/artist` | 24 h | Metadata changes rarely |
| `/track/{id}/stream` | 25 min | Conservative vs typical 6h URL TTL |
| `/library/*` | **Never** | Phone's Drift is the local cache |
| `/home`, `/radio` | 5 min | Personalized but stable for short windows |

### 2.6 Concurrency posture

- `ytmusicapi`/`yt-dlp` are sync; wrap calls in `asyncio.to_thread()`.
- **2–3 concurrent stream resolutions** maximum (account-safety pacing).
- No bulk pre-resolution: a 12-track album manifest resolves serially with 3-wide concurrency, not all 12 at once.

## 3. Auth & cookie management

### 3.1 Auth model

Use `ytmusicapi`'s browser-headers flow (cookies + `Authorization: SAPISIDHASH ...` + `User-Agent`). Stored as JSON in `./secrets/yt_headers.json`, mounted as a Docker volume into `yt-music-api`. `chmod 600`. `ytmusicapi` auto-rotates the time-based portion of the SAPISIDHASH on each request as long as the underlying `SAPISID` cookie is alive.

Encryption at rest: not used. Single-user homelab disk, not off-site backed up. Adds key-management complexity for no real win.

### 3.2 Cookie health check

A background task runs every 15 min:

```
loop:
  call ytmusic.get_library_songs(limit=1)
  on success → write auth_status=OK, last_ok_at=now
  on auth error → write auth_status=EXPIRED
```

`/health` reflects the latest status. Flutter app polls `/health` on cold start; shows persistent top banner when degraded. No push notification infrastructure.

### 3.3 Refresh ritual

A small admin web page mounted on `yt-music-api` at `/admin/*`, behind the same Cloudflare Access policy. Single page with:

- Current `auth_status`, `last_ok_at`, `last_refreshed_at`
- A textarea for "paste curl-as-bash from DevTools"
- A "test & save" button that runs `ytmusicapi`'s parser against the input, validates with a test API call, then writes to `./secrets/yt_headers.json`
- Backend `watchfiles`-watches the file and hot-reloads the `ytmusicapi` client — no container restart

Targeted ritual time: <2 min once familiar. CLI fallback (`scripts/refresh-cookies.sh`) ships for "the admin page is broken and I need to fix it" scenarios.

### 3.4 PO token lifecycle

`pot-provider` sidecar exposes HTTP on internal Docker network. `yt-dlp` is configured with:

```
--extractor-args "youtube:po_token_provider_url=http://pot-provider:4416"
```

PoT minted per-`visitor_data`, cached in `pot-provider` for ~hours. On stream resolution failure with PoT-related errors, `yt-music-api` returns `pot_token_failed` and retries with backoff. Compose policy: `restart: unless-stopped` plus a daily `cron`-style restart (Chromium leaks memory).

### 3.5 Account safety rules (baked into the design)

- Cap concurrent stream resolutions at 2–3 (§2.6)
- Lazy URL resolution on auto-download (one-at-a-time with pacing, never bulk)
- Never share the cookie file across other clients/devices/projects
- Residential IP only; no commercial VPN

## 4. Flutter app architecture

### 4.1 Layers

```
Presentation (widgets + Riverpod Notifiers, GoRouter)
       │
   Repositories (CatalogRepo, LibraryRepo, PlaybackRepo, DownloadRepo, SettingsRepo)
       │
   Sources: RemoteSource (Dio + ApiClient), LocalSource (Drift DAOs), FileSource
```

No use-case layer. Repositories merge remote + local; UI never `await`s the network for library views — it streams from Drift while a background sync hits the API.

### 4.2 Package selection

| Concern | Package |
|---|---|
| Routing | `go_router` |
| State | `flutter_riverpod` + `riverpod_generator` |
| HTTP | `dio` + interceptors (CF Access headers, 429 backoff, 401 surfacing) |
| Audio | `just_audio` + `audio_service` |
| Local DB | `drift` + `drift_dev` |
| Downloads | `background_downloader` |
| BG sync | `workmanager` |
| Image cache | `cached_network_image` |
| Connectivity | `connectivity_plus` |
| Secret storage | `flutter_secure_storage` (CF Access service token at rest) |
| FFmpeg | **None** (decision: drop it, see §1.2) |

### 4.3 Audio playback

A single `AudioPlaybackHandler extends BaseAudioHandler` registered at app startup. Owns:

- A `just_audio` `AudioPlayer`
- The current queue (`List<MediaItem>`)
- Source resolution policy:
  - If track is `downloaded` → load from local file URI
  - Else → call `CatalogRepo.resolveStream(videoId)`, load `url`
  - On `PlatformException`/HTTP 403/410 → re-resolve, seek to last position, resume

`PlayerController` (Riverpod `Notifier`) proxies user actions to the handler and exposes derived state via streams.

### 4.4 Error handling

A single `ErrorBoundary` widget listens to a global `Stream<AppError>`:

- Toast for transient + retryable (`rate_limited`, transient `upstream_breakage`)
- Persistent top banner for sticky failures (`cookies_expired`, repeated `pot_token_failed`)

Repositories emit `AppError` events; they never show UI directly.

### 4.5 Out of scope (v1)

- Analytics SDK
- Crash reporting (Sentry/Crashlytics)
- Background isolate for the audio handler (use modern same-isolate setup)
- Bloc, GetX (rejected)
- OpenAPI codegen (~20 endpoints, hand-write)

## 5. Data model

### 5.1 Drift tables

```
tracks                              -- canonical track, keyed by YT video ID
  videoId            TEXT PK
  title              TEXT
  artistName         TEXT
  artistBrowseId     TEXT?
  albumName          TEXT?
  albumBrowseId      TEXT?
  durationMs         INT
  artworkUrl         TEXT?
  isLiked            BOOL
  likedAt            DATETIME?
  -- download fields
  downloadStatus     TEXT     -- not_downloaded | queued | downloading | downloaded | failed
  downloadAttempts   INT DEFAULT 0
  lastDownloadError  TEXT?
  pinned             BOOL DEFAULT 0
  localPath          TEXT?
  downloadedCodec    TEXT?    -- 'opus' | 'aac'
  downloadedBitrate  INT?
  sizeBytes          INT?
  downloadedAt       DATETIME?
  lastPlayedAt       DATETIME?

albums
  browseId           TEXT PK
  title              TEXT
  artistName         TEXT
  artistBrowseId     TEXT?
  year               INT?
  artworkUrl         TEXT?     -- 600x600 default
  trackCount         INT
  lastSyncedAt       DATETIME?

album_tracks
  albumBrowseId      TEXT FK
  videoId            TEXT FK
  position           INT
  PK (albumBrowseId, videoId)
  INDEX (albumBrowseId, position)

artists
  browseId           TEXT PK
  name               TEXT
  subscribed         BOOL DEFAULT 0
  artworkUrl         TEXT?
  lastSyncedAt       DATETIME?

playlists
  browseId           TEXT PK
  title              TEXT
  description        TEXT?
  ownerName          TEXT?
  isOwn              BOOL
  trackCount         INT
  lastSyncedAt       DATETIME?

playlist_tracks
  playlistBrowseId   TEXT FK
  videoId            TEXT FK
  setVideoId         TEXT      -- YT Music quirk; required for removal
  position           INT
  addedAt            DATETIME
  PK (playlistBrowseId, setVideoId)
  INDEX (playlistBrowseId, position)

recently_played
  videoId            TEXT FK
  playedAt           DATETIME
  PK (videoId, playedAt)

sync_state
  key                TEXT PK   -- e.g. 'library_liked', 'playlist:PLxxx'
  lastSyncedAt       DATETIME
  etag               TEXT?

settings
  key                TEXT PK
  value              TEXT
```

Indexes:
```
CREATE INDEX tracks_download_status   ON tracks(downloadStatus);
CREATE INDEX tracks_is_liked          ON tracks(isLiked) WHERE isLiked = 1;
CREATE INDEX tracks_last_played       ON tracks(lastPlayedAt);
CREATE INDEX tracks_album             ON tracks(albumBrowseId);
CREATE INDEX album_tracks_position    ON album_tracks(albumBrowseId, position);
CREATE INDEX playlist_tracks_position ON playlist_tracks(playlistBrowseId, position);
```

### 5.2 Notable design decisions

- `tracks` is the single source of identity. Every list (liked, album, playlist, recently played) references `videoId`. Liking flips a bit; never duplicates.
- `playlist_tracks` PK uses `setVideoId`, not `videoId`, because YT Music permits the same track twice in a playlist and removal requires the per-occurrence ID.
- `pinned` is recomputed during sync from the union of pinned albums/playlists, not reference-counted. Cheap, single-user-correct.
- `recently_played` is server-driven only; we do not log plays locally.
- No `pending_mutations` table in v1 (deferred option B); a future migration can add it.
- No `lyrics` table (deferred).

### 5.3 Download state machine

```
not_downloaded ──pin / auto-like / album-dl──► queued
                                                 │
                                  worker picks up; resolves URL
                                                 ▼
                                            downloading
                                              │     │
                                          success failure
                                              │     │
                                              ▼     ▼
                                        downloaded  failed ──retry──► queued
                                              │
                                  evict (only if pinned=0, LRU)
                                              │
                                              ▼
                                        not_downloaded
```

- Only `pinned=0` tracks are evictable.
- Auto-retry on `failed`: 3 attempts with exponential backoff (5min, 30min, 4h). After that, sit in `failed` until manual retry.
- Re-resolve URL on retry only for URL-expiry failures (403/410); other failures reuse the existing URL.

### 5.4 On-disk layout

```
{appDocs}/
  db.sqlite
  audio/
    {videoId}.webm        -- opus
    {videoId}.m4a         -- aac
  artwork/
    {browseId}.jpg        -- one per album/playlist (600x600)
```

Flat by `videoId`. Track-level artwork only when `albumBrowseId` is null (orphan singles); stored under `{videoId}.jpg`.

### 5.5 Eviction

Sweep runs after every successful download:

```sql
WITH downloaded_unpinned AS (
  SELECT videoId, sizeBytes, lastPlayedAt
  FROM tracks
  WHERE downloadStatus = 'downloaded' AND pinned = 0
  ORDER BY lastPlayedAt ASC
)
-- if SUM(sizeBytes) > cap: pop LRU until under cap
```

Default cap: **10 GB** (user-configurable in Settings). Evicted tracks: file deleted, `downloadStatus → not_downloaded`, file fields cleared, row stays.

## 6. Download system

### 6.1 Two-step flow

```
Phone ──manifest request──► yt-music-api ──► resolves N URLs (paced)
Phone ◄──{items:[{url,...}]}── yt-music-api
Phone ──direct fetch──► googlevideo.com
```

### 6.2 Manifest endpoint

```
POST /v1/downloads/manifest
{
  "videoIds": ["abc...", "def...", ...],
  "codec": "opus",
  "quality": "high"
}

200:
{
  "items": [
    {
      "videoId": "abc...",
      "url": "https://rr3---sn-...googlevideo.com/...",
      "expiresAt": "...",
      "codec": "opus",
      "container": "webm",
      "bitrate": 160000,
      "contentLength": 4321234,
      "metadata": {
        "title": "...", "artist": "...", "album": "...",
        "year": 2018, "trackNumber": 4, "discNumber": 1,
        "albumArtist": "..."
      },
      "artworkUrl": "https://lh3.googleusercontent.com/..."
    }
  ],
  "errors": [
    { "videoId": "ghi...", "error": "not_found" }
  ]
}
```

- Bulk: one round-trip for an album/playlist. Backend resolves with concurrency 3.
- Per-item failures, not all-or-nothing: client marks failed entries, others still download.
- Metadata in the manifest is what Drift will store. We do **not** embed it in the file (no ffmpeg).

### 6.3 Worker pipeline

1. `DownloadCoordinator` (Riverpod, app-wide) watches Drift for `downloadStatus = queued` rows.
2. Batches by 8, calls `/downloads/manifest`.
3. Hands each item's `url` to `background_downloader` (max 3 concurrent on phone).
4. `background_downloader` writes to `{appCache}/dl/{videoId}.{ext}.part` with HTTP Range resume.
5. On completion: move file from cache to `{appDocs}/audio/{videoId}.{ext}`. Update Drift row (`downloadStatus`, `localPath`, `sizeBytes`, `downloadedCodec`, `downloadedBitrate`, `downloadedAt`).
6. Trigger eviction sweep.

No ffmpeg post-processing. File extension reflects what was served (`.webm` for opus-in-WebM, `.m4a` for AAC). `just_audio` plays both natively on iOS and Android. Files outside the app are weakly identifiable; acceptable for personal use.

### 6.4 URL expiry mid-download

`background_downloader` reports 403/410 as a typed failure. Coordinator:

1. Looks up which `videoId` failed.
2. Calls `POST /v1/downloads/manifest` for just that one.
3. Tells `background_downloader` to resume the existing partial file with the new URL via HTTP `Range`.

If re-resolution fails (track withdrawn, etc.): mark `failed`, log, move on.

### 6.5 Auto-sync (liked → download)

`workmanager` periodic task — Android: every 6h with wifi+charging constraint; iOS: BGProcessingTask, OS-decided (typically 1–3× per day).

```
auto_sync_liked():
  serverLiked = full pull from /library/liked
  localLiked  = SELECT videoId FROM tracks WHERE isLiked = 1

  newlyLiked  → upsert track + isLiked=1
              → if downloadStatus = not_downloaded AND on_wifi:
                  downloadStatus = queued; pinned = 0  (evictable!)

  unliked     → isLiked = 0
              (file remains; eviction may reclaim later)
```

iOS reality: BGProcessingTask gives ~30s of foreground work, but `background_downloader` uses `URLSession` background config so file fetches continue across multiple OS wakes. A 1 GB album may span hours of clock time. Acceptable.

### 6.6 Concurrency caps

| Where | Cap |
|---|---|
| Backend stream resolutions | 2–3 in flight |
| Phone parallel downloads | 3 |
| Phone parallel artwork fetches | 5 |

### 6.7 Out of scope

- P2P / cross-device sync of downloads
- Speculative pre-cache of next track in queue (`just_audio` buffers ~30s, sufficient)
- On-phone transcoding to "save space" (lossy-to-lossy)

## 7. Repository structure

Mono-repo: `yt-music-app`.

```
yt-music-app/
├── README.md
├── docker-compose.yml
├── .env.example
├── .gitignore                  # secrets/, build artifacts, .local
├── docs/
│   └── superpowers/specs/
│       └── 2026-04-29-yt-music-client-design.md
├── backend/
│   ├── pyproject.toml          # uv-managed
│   ├── Dockerfile
│   ├── src/ytmusic_api/
│   │   ├── main.py
│   │   ├── config.py           # pydantic-settings
│   │   ├── deps.py
│   │   ├── auth/
│   │   │   ├── headers.py
│   │   │   └── health.py
│   │   ├── routers/
│   │   │   ├── catalog.py
│   │   │   ├── stream.py
│   │   │   ├── library.py
│   │   │   ├── discovery.py
│   │   │   ├── downloads.py
│   │   │   ├── admin.py
│   │   │   └── health.py
│   │   ├── services/
│   │   │   ├── ytmusic_client.py
│   │   │   ├── stream_resolver.py
│   │   │   ├── pot_client.py
│   │   │   └── cache.py
│   │   ├── models/
│   │   └── admin/templates/
│   └── tests/
├── pot-provider/
│   └── Dockerfile
├── app/
│   ├── pubspec.yaml
│   ├── android/
│   ├── ios/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── api/
│   │   │   ├── audio/
│   │   │   ├── db/
│   │   │   ├── downloads/
│   │   │   ├── errors/
│   │   │   ├── settings/
│   │   │   └── theme/
│   │   ├── features/
│   │   │   ├── search/
│   │   │   ├── home/
│   │   │   ├── library/
│   │   │   ├── playlist/
│   │   │   ├── album/
│   │   │   ├── artist/
│   │   │   ├── now_playing/
│   │   │   ├── downloads/
│   │   │   └── settings/
│   │   └── shared/widgets/
│   └── test/
├── scripts/
│   ├── dev-up.sh
│   ├── refresh-cookies.sh
│   └── deploy.sh
└── secrets/                    # gitignored
    └── yt_headers.json
```

Conventions:
- Backend uses `src/` layout. `uv` for deps, `ruff` for lint+format, `pytest`, `pydantic-settings`. No SQLAlchemy ORM (cache is flat, YT data isn't ours).
- App uses feature-first layout. Each feature owns widgets, controllers, and feature-specific repositories.
- One Drift database under `app/lib/core/db/`.
- Cloudflared runs outside Compose (already set up).
- No shared types package, no OpenAPI codegen, no nx/turborepo.

## 8. Phased roadmap

| # | Phase | Milestone | Est. |
|---|---|---|---|
| 0 | Foundations | Repo + Compose + Cloudflared + CF Access + admin page MVP + cookie ingestion + `/health`. Flutter shell talks to backend through CF Access. | 1–2 wk |
| 1 | Read-only core: search → play | `/search`, `/track`, `/track/{id}/stream`. just_audio + audio_service playback with lockscreen on both platforms. Search UI + minimal now-playing. **Truth-test phase.** | 2–3 wk |
| 2 | Library reads + persistence | Drift schema, all `/library/*` GET, library screens, sync state, pull-to-refresh. | 2 wk |
| 3 | Albums, artists, discovery, queue | `/album`, `/artist`, `/home`, `/radio`, `/up-next`. Detail screens, home feed, queue UI, radio autoplay. | 1–2 wk |
| 4 | Mutations (online-only) | Pre-flight `/library/snapshot` JSON backup. Like/unlike, playlist CRUD, add/remove tracks. | 1 wk |
| 5 | Manual downloads | `/downloads/manifest`, DownloadCoordinator, background_downloader, eviction sweep, download UI. Pinned vs evictable. | 2 wk |
| 6 | Auto-sync liked songs | workmanager periodic task, wifi+charging gating, diff-and-queue. | 1 wk |
| 7 | Polish + sideload | Error UX, settings screen, icon/splash, Apple Developer cert + sideload, manual QA. iOS-primary; Android tested but not heavily polished. | 1 wk |

**Total: ~12–14 weeks** at evenings-and-weekends pace.

Deferred to post-v1 (each its own future spec):
- Optimistic offline writes (option B)
- Lyrics
- Last.fm scrobbling
- Cross-device playback position sync
- Equalizer
- CarPlay / Android Auto

## 9. Risks register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | PO token scheme changes | High | High | Sidecar isolated; pinned & easy to upgrade; monitor `bgutil-ytdlp-pot-provider` releases. Plan ~1 emergency upgrade per 6 months. |
| 2 | `ytmusicapi`/`yt-dlp` lag behind Google breakage | High | Medium | Pin versions, weekly upgrade habit. When breakage hits, fall back to official YT Music app for 1–14 days until upstream patches. |
| 3 | Cookies expire / invalidated | Medium | Medium | 15-min health check, admin-page refresh, `/health` flips to degraded, in-app banner. Refresh ritual <2 min. |
| 4 | Google flags Premium account | Low (with discipline) | **Severe** (loses Premium) | Concurrency caps 2–3, no VPN, no bulk pre-resolution, residential IP only. Recovery: new Premium subscription. |
| 5 | iOS background download windows shorter than expected | Medium | Medium | URLSession background config via `background_downloader` survives across OS wakes. Document multi-hour clock time as expected. |
| 6 | Apple Developer cert hassles or cost change | Low | Low | $99/yr accepted; calendar reminder for renewal. |
| 7 | `ffmpeg_kit_flutter` archived | Confirmed | None (mitigated) | Decision: drop ffmpeg, store opus-in-WebM as `.webm`, Drift is the metadata source of truth. |
| 8 | CF Tunnel rate-limit or ToS | Low | Low | Audio doesn't traverse CF — only metadata. Within Self-Serve ToS. Connection layer is replaceable (swap to Tailscale). |
| 9 | `just_audio` / `audio_service` edge cases | Medium | Low | Both packages mature; Phase 7 buffer for platform quirks (iOS lockscreen artwork, Android 13+ notification permissions). |

## 10. Open items / future revision triggers

These are not blocking the implementation plan but should re-trigger spec revision if circumstances change:

- If user starts editing playlists offline frequently → pull option B forward.
- If `pot-provider` gets banned/blocked at scale → consider alternative resolvers or fallback to the official app.
- If `background_downloader` becomes unmaintained → revisit downloader choice (no concrete signs as of design date).
- If user adds a second device they want to sync playback position with → introduces a tiny new server-side state table; revise §2.

## 11. Glossary

- **PoT (PO Token)**: Proof-of-Origin Token; Google-required client attestation for high-quality stream resolution.
- **`browseId`**: YT Music's stable identifier for albums/artists/playlists.
- **`videoId`**: YouTube's stable identifier for a track.
- **`setVideoId`**: YT Music's per-occurrence ID for a track within a playlist; required for removal.
- **CF Access service token**: Cloudflare Access non-interactive auth pair (`Client-Id` + `Client-Secret`) for machine-to-machine auth.
- **Pinned**: A downloaded track that's part of a manual album/playlist download; immune to eviction.
