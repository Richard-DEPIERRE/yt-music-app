# Phase 5 — Manual Downloads (design)

**Date:** 2026-06-13
**Status:** Approved
**Roadmap:** Phase 5 of the yt-music-app design spec
(`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`, §5–6).

## Goal

Let the user manually download a song, album, or playlist for offline playback.
Manual downloads are **pinned** (immune to eviction). An LRU eviction sweep with a
10 GB cap is built and tested now, but only acts on unpinned tracks (which arrive in
Phase 6 auto-sync). Auto-sync (Phase 6) and the Settings cap-config UI (Phase 7) are
out of scope.

## Decisions (locked)

- **Downloader:** `background_downloader` — iOS background-safe (URLSession config),
  resumable via HTTP Range, persists tasks across app restarts.
- **Manifest payload:** lean — stream-resolution data + artwork only. The app already
  has title/artist/album from catalog views and Drift, and files are not tag-embedded
  (no ffmpeg), so rich tags would be redundant.
- **Scope:** full Phase 5 manual downloads — manifest endpoint, `DownloadCoordinator`,
  song/album/playlist download, pinned-vs-evictable, LRU eviction sweep (10 GB
  constant), download UI. Defer auto-sync (P6) and cap-config UI (P7).
- **Storage cap:** 10 GB compile-time constant (not yet user-configurable).

## 1. Backend — `POST /v1/downloads/manifest`

Bulk stream-URL resolver. Reuses the existing `StreamResolver`, the global
`BoundedRunner` (already capped at 2–3 in-flight, matching the spec's "concurrency 3"),
and the existing `stream:{id}:{codec}:{quality}` TTL cache so a recently-resolved track
is not re-resolved.

### Request / response

```
POST /v1/downloads/manifest
{
  "videoIds": ["abc", "def"],
  "codec":    "opus",          // any | aac | opus   (default: any)
  "quality":  "high"           // high | medium | low (default: high)
}

200:
{
  "items": [
    {
      "videoId":       "abc",
      "url":           "https://rr3---sn-...googlevideo.com/...",
      "expiresAt":     "2026-06-13T15:00:00Z",
      "codec":         "opus",
      "container":     "webm",
      "bitrate":       160000,
      "contentLength": 4321234,        // nullable
      "artworkUrl":    "https://lh3.googleusercontent.com/..."   // nullable
    }
  ],
  "errors": [
    { "videoId": "ghi", "error": "upstream_breakage" }
  ]
}
```

### Behaviour

- Resolves each `videoId` concurrently through `request.app.state.stream_runner`
  (`asyncio.gather` over `runner.run(resolver.resolve, ...)`). The runner's global cap
  bounds in-flight resolutions; no new concurrency primitive.
- **Per-item failures are isolated**: a resolution exception for one id appends to
  `errors[]`; the others still resolve. Never all-or-nothing.
- Cache: per id, check `stream:{id}:{codec}:{quality}` first; on miss, resolve and
  populate the same cache key the single-track stream endpoint uses.
- `artworkUrl`: pick the best thumbnail from the yt-dlp `info` dict. `ResolvedStream`
  gains an `artwork_url: str | None` field (the single-track `StreamResponse` ignores
  it — no behaviour change there).
- `videoIds` capped at a sane max per request (e.g. 50); empty list → empty `items`.

### New / changed files

- `backend/src/ytmusic_api/models/downloads.py` — `ManifestRequest`, `ManifestItem`,
  `ManifestError`, `ManifestResponse` (pydantic).
- `backend/src/ytmusic_api/routers/downloads.py` — `POST /downloads/manifest`.
- `backend/src/ytmusic_api/services/stream_resolver.py` — add `artwork_url` to
  `ResolvedStream` + thumbnail extraction.
- `backend/src/ytmusic_api/main.py` — register the downloads router.
- `backend/tests/test_downloads_manifest.py` — mock the resolver.

## 2. App — download core (`app/lib/core/downloads/`)

### `FileDownloaderGateway` (interface)

Thin abstraction over `background_downloader`:

```dart
abstract class FileDownloaderGateway {
  Future<void> enqueue(DownloadRequest req);   // url, videoId, ext
  Future<void> resume(String videoId, String newUrl);
  Future<void> cancel(String videoId);
  Stream<DownloadEvent> get events;            // progress | complete | failed(code)
  Future<void> configure({int maxConcurrent});
}
```

- Real impl (`background_downloader_gateway.dart`) wraps the plugin: `DownloadTask`
  targeting `BaseDirectory.applicationDocuments`, subdirectory `audio`, filename
  `{videoId}.{ext}`; `maxConcurrent = 3`; maps `TaskStatusUpdate`/`TaskProgressUpdate`
  to `DownloadEvent`. The plugin handles `.partial` files and atomic move, so the
  spec's manual cache→move step is delegated to the library.
- A **fake gateway** drives all coordinator/eviction tests with no native plugin.
- Exact plugin API (task construction, updates stream, pause/resume, holding-queue
  concurrency) verified against current docs via Context7 at implementation time.

### `DownloadRepository` (Drift-backed)

No schema migration — every download column already exists (Phase 2 `tracks` table).

- `enqueue(List<String> videoIds, {bool pinned})` → upsert/patch rows to
  `downloadStatus='queued'`, set `pinned`.
- `markDownloading / markDownloaded(...) / markFailed(...)` → state transitions, set
  `localPath`, `sizeBytes`, `downloadedCodec`, `downloadedBitrate`, `downloadedAt`,
  `downloadAttempts`, `lastDownloadError`.
- `watchQueued()`, `watchDownloaded()` → streams for the coordinator and the UI.
- Eviction queries: total `sizeBytes` of `downloaded AND pinned=0`; LRU list by
  `lastPlayedAt ASC`.
- `removeDownload(videoId)` → delete file, clear file fields, `not_downloaded`,
  `pinned=0`.

### `DownloadCoordinator` (Riverpod, app-wide)

1. Watches `downloadStatus='queued'`.
2. Batches up to 8 → `ApiClient.getManifest`.
3. For each returned item: `markDownloading`, enqueue into the gateway.
4. Manifest `errors[]` → `markFailed`.
5. On gateway `complete`: `markDownloaded` (path, size, codec, bitrate, time) →
   eviction sweep.
6. On gateway `failed(403|410)`: re-resolve that one id via manifest, `resume` the
   partial with the new URL.
7. On other `failed`: increment attempts; `failed` after 3; reuse existing URL on retry.
8. **Reconcile on launch**: rows stuck in `downloading` whose gateway task no longer
   exists → requeue.

### Eviction (`eviction.dart` / repository method)

```sql
-- candidates: downloaded AND pinned = 0, ordered lastPlayedAt ASC (NULLs first)
-- if SUM(sizeBytes) > 10 GB: pop LRU, delete file, clear fields, status not_downloaded
```

Runs after every successful download. No-op in Phase 5 (manual downloads are pinned),
fully wired and tested for Phase 6.

## 3. App — playback integration

When starting a track, before resolving a stream URL: if `downloadStatus='downloaded'`
and `localPath` exists on disk → play the **local file URI**; else resolve the stream
URL as today. Touch `lastPlayedAt` on play (feeds eviction LRU). This is the change that
makes downloads genuinely offline-capable.

## 4. App — API + models

- `core/api/models/download_manifest.dart` — `ManifestItem`, `DownloadManifest`
  (`items`, `errors`).
- `ApiClient.getManifest(List<String> videoIds, {String codec, String quality})`.

## 5. App — UI

- **Download action** on album detail, playlist detail, now-playing, and track-row
  menus. Album/playlist enqueues all of its tracks (`pinned=1`).
- **Per-track status indicator**: queued / downloading (progress) / downloaded (check) /
  failed (tap to retry).
- **Downloads screen** (linked from the library hub): list of downloaded tracks, total
  storage used, remove-download per item.

## 6. Dependencies

- Add `background_downloader` to `app/pubspec.yaml`; `pod install` for iOS
  (`fvm flutter pub get` then pods). Android needs no extra manifest config for the
  basic case; verify at implementation time.

## 7. Testing (TDD)

- **Backend:** manifest success, per-item errors (mixed ok/error), codec/quality
  params, cache reuse, `videoIds` cap, empty list.
- **App:**
  - `DownloadRepository` state transitions + eviction queries (in-memory Drift).
  - Eviction LRU correctness (cap boundary, pinned excluded, NULL `lastPlayedAt`).
  - `DownloadCoordinator` happy path, manifest per-item error, 403/410 re-resolve +
    resume, launch reconcile — all against fake gateway + fake `ApiClient`.
  - `ApiClient.getManifest` (request shape, response parse, errors).
  - Playback source selection (downloaded → file URI; else stream).
  - Key widget states: download button transitions, Downloads screen rendering.

## 8. Out of scope

- Auto-sync liked → download (Phase 6).
- User-configurable storage cap / Settings screen (Phase 7).
- Tag embedding in files (no ffmpeg — by design).
- Speculative pre-cache of the next queued track.

## 9. Deliverables

Backend PR (manifest endpoint) + app PR (download core, playback integration, UI),
VM 101 redeploy of the backend, and a second-brain log entry on completion.
