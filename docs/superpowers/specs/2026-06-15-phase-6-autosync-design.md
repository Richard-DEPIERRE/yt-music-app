# Phase 6 — Auto-sync Liked Songs → Download (design)

**Date:** 2026-06-15
**Status:** Approved
**Roadmap:** Phase 6 of the yt-music-app design spec
(`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`, §6.5). Builds on Phase 5
(manual downloads, PR #75).

## Goal

Automatically download the user's liked songs for offline playback. Auto-downloaded
tracks are **evictable** (`pinned=0`), so they finally exercise Phase 5's LRU eviction
sweep (10 GB cap). Synced both in the foreground (reliable) and via a best-effort
background task.

## Decisions (locked)

- **Trigger: both.** Foreground (app launch + resume + manual button) as the reliable
  path; `workmanager` periodic background task as best-effort.
- **Network: any connection.** Auto-download on Wi-Fi or cellular. No `connectivity_plus`
  dependency — if offline, the liked pull / manifest fetch fails and is caught; the next
  trigger retries. (Manual Phase 5 downloads already work on any connection.)
- **Storage cap:** the existing 10 GB constant; user-configurable UI deferred to Phase 7.
- **Scope:** liked songs only (not playlists/albums).

## 1. Correctness: no eviction thrash

Auto-downloaded tracks are `pinned=0` and eviction goes live this phase. If we re-queued
*every* liked-but-not-downloaded track on each sync, eviction would delete LRU tracks and
the next sync would immediately re-queue them — an infinite thrash loop.

**Rule:** only **newly-liked** tracks are auto-queued — those in the server's liked set
that were **not previously liked locally**. Computed *before* the upsert. A track that was
liked, downloaded, then evicted remains liked (not newly-liked) and is **not** re-queued.
This is the delta the current `LibraryRepository.refreshLiked()` does not compute.

## 2. Headless sync service — `LikedAutoSyncService`

A pure, UI-free unit so it runs identically in the foreground and in the background
isolate, and is fully unit-testable.

```dart
class LikedAutoSyncService {
  LikedAutoSyncService({
    required AppDatabase db,
    required ApiClient api,
    required Future<void> Function(List<String> videoIds, {bool pinned}) enqueue,
  });

  /// Pull liked, reconcile local likes, auto-queue newly-liked undownloaded
  /// tracks as evictable, then let the coordinator download them.
  Future<LikedSyncResult> run();
}

class LikedSyncResult {
  final int liked;        // total liked after sync
  final int newlyQueued;  // newly-liked, not-downloaded tracks queued this run
}
```

`run()` steps:
1. `serverLiked = api.getLikedSongs()` (full pull).
2. `previouslyLiked = SELECT videoId FROM tracks WHERE isLiked = 1` (snapshot **before** upsert).
3. Upsert all liked rows + clear `isLiked` for tracks no longer liked — reusing the exact
   logic that lives in `LibraryRepository.refreshLiked()` today (which preserves download
   columns via `insertOnConflictUpdate`). Mark `sync_state['library_liked']`.
4. `newlyLiked = serverIds − previouslyLiked`.
5. For each `newlyLiked` videoId whose current `downloadStatus == 'not_downloaded'`:
   `enqueue([id], pinned: false)`. (Already-downloaded or pinned tracks are skipped — the
   `not_downloaded` guard covers both.)
6. The queued rows are picked up by the `DownloadCoordinator` (resolve manifest → gateway →
   download); the eviction sweep runs after each completion and now meaningfully caps
   `pinned=0` tracks.

**Who triggers the coordinator after queueing:** `LikedAutoSyncService` only writes rows to
`queued` (via the `enqueue` callback = `DownloadRepository.enqueue`, `pinned:false`); it does
**not** itself drive the coordinator. The trigger differs per path:
- **Foreground:** the live `DownloadCoordinator` is already watching the `queued` stream, so
  the DB write auto-triggers `processQueueOnce()` — no extra call needed.
- **Background isolate:** no stream watcher is running, so the `callbackDispatcher` must
  explicitly call `coordinator.processQueueOnce()` after `run()` so the queued rows are
  resolved and handed to the gateway within that wake.

**Refactor:** extract the steps-3 reconcile from `LibraryRepository.refreshLiked()` into a
shared method (e.g. `reconcileLiked(serverPage)` returning the set of previously-liked ids)
so both `refreshLiked()` and `LikedAutoSyncService` use one implementation — no duplicated
SQL. `refreshLiked()` keeps its current behaviour (no auto-queue); only the auto-sync
service adds the queue step.

**Dependencies:** `db`, `api`, and an `enqueue` callback (so tests inject a fake and the
real wiring passes `DownloadRepository.enqueue`). No Riverpod inside the service.

## 3. Foreground triggers (reliable path)

- **`likedAutoSyncProvider`** — a `Provider<LikedAutoSyncService>` built from the app's
  existing `appDatabaseProvider`, `apiClientProvider` (nullable — no-op if unconfigured),
  and `downloadRepositoryProvider.enqueue`.
- **On launch + resume:** a small `ConsumerStatefulWidget` (`AutoSyncObserver`) near the
  app root observes `AppLifecycleState`. On `resumed` (and once at startup after config is
  ready) it triggers a **debounced** sync.
- **Debounce:** skip if `sync_state['library_liked']` was updated within the last
  `_autoSyncMinInterval` (e.g. 30 min) — reuses the existing `sync_state` table and
  `SyncStateDao.isFresh`. A manual sync bypasses the debounce.
- **Manual "Sync liked" action:** an icon button on the Downloads screen app bar that runs
  the sync immediately and surfaces a SnackBar with the result (`newlyQueued`).

## 4. Background trigger (best-effort, `workmanager`)

- Add `workmanager`. Register a periodic task in `main()`:
  - Android: period ~6h, `Constraints(networkType: NetworkType.connected)`, no charging
    constraint (aggressive, per "any connection").
  - iOS: `BGProcessingTask` (OS-decided cadence; throttled — foreground is the dependable
    path).
- **Top-level `callbackDispatcher`** (required by workmanager — runs in a separate isolate
  with no Riverpod). It constructs its own dependencies headlessly:
  - Open a Drift `AppDatabase` (its own connection on the same file).
  - Build `ApiClient` from config read out of `flutter_secure_storage` (same source the app
    uses). If config is absent → return success (nothing to do).
  - Build the `BackgroundDownloaderGateway` + `DownloadRepository` + a `DownloadCoordinator`,
    run `LikedAutoSyncService.run()`, then call `coordinator.processQueueOnce()` (see §2 —
    no stream watcher runs in this isolate). `background_downloader` (URLSession on iOS /
    WorkManager on Android) continues file fetches across OS wakes regardless of which
    isolate enqueued them.
  - Return `Future.value(true)` on success so workmanager doesn't treat it as failed.
- **Drift multi-isolate note:** the background isolate opens a second connection to the
  same sqlite file. With WAL this is safe for the brief, mostly-write-light sync; the task
  runs when the app is backgrounded (not actively writing). Open and **close** the DB within
  the dispatcher to release the connection promptly.
- **iOS native config:** `Info.plist` — `BGTaskSchedulerPermittedIdentifiers` (the task id)
  + `UIBackgroundModes` (`processing`, `fetch`); `AppDelegate` registers the task per the
  workmanager iOS setup. Android needs no extra manifest entries beyond the plugin's.
- Document clearly: iOS background execution is OS-throttled and not guaranteed; the
  foreground triggers are what make the feature reliable.

## 5. Eviction goes live

No code change to the sweep — Phase 5 already excludes `pinned=1` and caps at 10 GB. This
phase produces the first `pinned=0` (auto-downloaded) tracks, which become the evictable
set. One new integration test proves: with a cap exceeded, auto-downloaded (`pinned=0`)
tracks evict LRU-first while manually-downloaded (`pinned=1`) tracks are never evicted.

## 6. Testing

- **`LikedAutoSyncService`** (in-memory Drift + fake api + fake enqueue):
  - newly-liked, not-downloaded → queued `pinned=0`.
  - already-downloaded liked track → NOT queued (no thrash).
  - **evicted-then-still-liked track → NOT re-queued** (the thrash guard — seed a liked
    track as `not_downloaded` that was *already* liked previously; assert it is not queued).
  - unliked tracks → `isLiked` cleared.
  - manually-pinned liked track → left pinned, not touched.
  - `LikedSyncResult` counts correct.
- **Debounce:** sync skipped when `library_liked` is fresh; manual bypasses.
- **Eviction integration:** mixed pinned/unpinned under cap (from §5).
- **Shared reconcile refactor:** existing `LibraryRepository.refreshLiked` tests still pass.
- The background `callbackDispatcher` is kept thin (dependency construction only) so its
  core logic is the already-tested `LikedAutoSyncService`.

## 7. Files (planned)

- `app/lib/core/sync/liked_auto_sync_service.dart` — the service + `LikedSyncResult`.
- `app/lib/core/sync/auto_sync_providers.dart` — `likedAutoSyncProvider` + a trigger action.
- `app/lib/core/sync/auto_sync_observer.dart` — lifecycle observer widget (launch/resume).
- `app/lib/core/sync/background_sync.dart` — top-level `callbackDispatcher` + workmanager
  registration helper.
- `app/lib/core/library/library_repository.dart` — extract shared `reconcileLiked`.
- `app/lib/main.dart` — register workmanager + mount `AutoSyncObserver`.
- `app/lib/features/downloads/downloads_screen.dart` — "Sync liked" app-bar action.
- iOS `Info.plist` / `AppDelegate.swift` — background task registration.
- `app/pubspec.yaml` — add `workmanager`.
- Tests under `app/test/core/sync/`.

## 8. Out of scope

- User-configurable storage cap / settings UI (Phase 7).
- Wi-Fi-only / charging-only gating (chose "any connection").
- Auto-sync of playlists or albums (liked songs only).
- Optimistic offline like/unlike writes (Phase 4 territory; not part of this).

## 9. Deliverables

App-only PR (no backend change — `/library/liked` already exists). CI green
(app analyze + test). Second-brain log + project-note update on completion. No VM 101
redeploy needed.
