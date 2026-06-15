# Phase 6 — Auto-sync Liked Songs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically download newly-liked songs (evictable, `pinned=0`), triggered in the foreground (launch/resume/manual) and via a best-effort `workmanager` background task — activating Phase 5's LRU eviction.

**Architecture:** A headless, UI-free `LikedAutoSyncService` pulls liked songs, reconciles local likes (reusing `LibraryRepository`), and queues only **newly-liked** undownloaded tracks as `pinned=0` (the newly-liked delta prevents eviction thrash). The existing `DownloadCoordinator` downloads them and the eviction sweep caps them at 10 GB. Foreground triggers use Riverpod + a lifecycle observer; the background path runs the same service inside `workmanager`'s separate-isolate `callbackDispatcher`.

**Tech Stack:** Flutter + Riverpod + Drift + `background_downloader` (Phase 5) + `workmanager` (new). App-only — no backend change (`/library/liked` already exists).

**Codebase facts (verified):**
- `LibraryRepository.refreshLiked()` (`app/lib/core/library/library_repository.dart`) pulls `/library/liked`, upserts liked rows (download columns preserved via `insertOnConflictUpdate`), clears `isLiked` for unliked, and marks `sync_state['library_liked']`.
- `DownloadRepository.enqueue(List<String>, {bool pinned = true})` writes rows to `queued`; `runEviction()` already excludes `pinned=1` and caps at `kDefaultCapBytes` (10 GB).
- `SyncStateDao.isFresh(key, {ttl})` + `lastSyncedAt`/`mark` exist.
- `apiClientProvider` / `libraryRepositoryProvider` / `downloadRepositoryProvider` exist; `apiClientProvider` and `libraryRepositoryProvider` are **nullable** (null until configured).
- `SettingsRepository().read()` returns `ApiConfig?` from secure storage (used by the background isolate).
- The app root is `app/lib/app.dart` (`UichaaMusicApp`); `main.dart` builds a late `ProviderContainer` + `UncontrolledProviderScope`.
- Library repo tests mock the API with `mocktail` (`class _MockApi extends Mock implements ApiClient {}`), using `PagedLikedSongs`/`LikedSong` from `core/api/models/library_models.dart`.

---

## Part A — Core sync logic (no native; fully testable)

### Task 1: `refreshLiked` returns the newly-liked delta

**Files:**
- Modify: `app/lib/core/library/library_repository.dart`
- Test: `app/test/core/library/library_repository_test.dart`

> Keep one reconcile implementation (DRY). Add `refreshLikedReturningNew()` that
> computes `newlyLiked` (server ids minus the locally-liked ids captured **before**
> upsert) and have `refreshLiked()` delegate to it (preserving its `Future<void>`
> signature so existing callers are unaffected).

- [ ] **Step 1: Write the failing test**

Add to `app/test/core/library/library_repository_test.dart`:

```dart
  test('refreshLikedReturningNew returns only newly-liked ids', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [LikedSong(videoId: 'v1', title: 'One')],
      ),
    );
    final first = await repo.refreshLikedReturningNew();
    expect(first, {'v1'}); // v1 was not liked before

    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [
          LikedSong(videoId: 'v1', title: 'One'),
          LikedSong(videoId: 'v2', title: 'Two'),
        ],
      ),
    );
    final second = await repo.refreshLikedReturningNew();
    expect(second, {'v2'}); // v1 already liked; only v2 is new
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/library/library_repository_test.dart -p vm --plain-name "refreshLikedReturningNew returns only newly-liked ids"`
Expected: FAIL — method missing.

- [ ] **Step 3: Implement**

In `library_repository.dart`, replace the existing `refreshLiked()` method with:

```dart
  Future<void> refreshLiked() async {
    await refreshLikedReturningNew();
  }

  /// Reconciles local likes with the server and returns the set of videoIds
  /// that became liked in this sync (present on the server, not liked locally
  /// before). Used by auto-sync to decide what to auto-download.
  Future<Set<String>> refreshLikedReturningNew() async {
    final page = await api.getLikedSongs();
    final now = DateTime.now().toUtc();
    final newIds = page.items.map((s) => s.videoId).toSet();

    final previouslyLikedRows = await db.tracksDao.watchLiked().first;
    final previouslyLiked =
        previouslyLikedRows.map((t) => t.videoId).toSet();

    await db.transaction(() async {
      if (newIds.isEmpty) {
        await db.customStatement(
          'UPDATE tracks SET is_liked = 0 WHERE is_liked = 1',
        );
      } else {
        final placeholders = List<String>.filled(newIds.length, '?').join(',');
        await db.customStatement(
          'UPDATE tracks SET is_liked = 0 '
          'WHERE is_liked = 1 AND video_id NOT IN ($placeholders)',
          newIds.toList(),
        );
      }
      for (final s in page.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: s.videoId,
          title: s.title,
          artistName: Value(s.artistName),
          albumName: Value(s.albumName),
          albumBrowseId: Value(s.albumBrowseId),
          durationMs: Value(s.durationMs),
          artworkUrl: Value(s.thumbnail?.url),
          isLiked: const Value(true),
          likedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_liked', at: now);
    });

    return newIds.difference(previouslyLiked);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && fvm flutter test test/core/library/library_repository_test.dart`
Expected: PASS (the new test + all existing liked/playlist/etc. tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/library/library_repository.dart app/test/core/library/library_repository_test.dart
git commit -m "feat(app): refreshLiked returns newly-liked delta"
```

---

### Task 2: `LikedAutoSyncService`

**Files:**
- Create: `app/lib/core/sync/liked_auto_sync_service.dart`
- Test: `app/test/core/sync/liked_auto_sync_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/core/sync/liked_auto_sync_service_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;
  late LibraryRepository library;
  late List<({List<String> ids, bool pinned})> enqueued;
  late LikedAutoSyncService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    library = LibraryRepository(db: db, api: api);
    enqueued = [];
    service = LikedAutoSyncService(
      library: library,
      db: db,
      enqueue: (ids, {bool pinned = false}) async =>
          enqueued.add((ids: ids, pinned: pinned)),
    );
  });
  tearDown(() async => db.close());

  void likedReturns(List<String> ids) {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [for (final id in ids) LikedSong(videoId: id, title: id)],
      ),
    );
  }

  test('newly-liked undownloaded track is queued as evictable (pinned=0)',
      () async {
    likedReturns(['v1']);
    final result = await service.run();
    expect(enqueued.length, 1);
    expect(enqueued.single.ids, ['v1']);
    expect(enqueued.single.pinned, false);
    expect(result.newlyQueued, 1);
    expect(result.liked, 1);
  });

  test('already-downloaded newly-liked track is NOT queued', () async {
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'v2',
        title: 'Two',
        downloadStatus: const Value('downloaded'),
        pinned: const Value(true),
      ),
    );
    likedReturns(['v2']);
    final result = await service.run();
    expect(enqueued, isEmpty);
    expect(result.newlyQueued, 0);
  });

  test('evicted-but-still-liked track is NOT re-queued (no thrash)', () async {
    // First sync likes + queues v1.
    likedReturns(['v1']);
    await service.run();
    enqueued.clear();
    // Simulate: v1 was downloaded then evicted -> back to not_downloaded,
    // but it stays liked.
    await db.downloadsDao.clearDownload('v1');
    final v1 = await db.tracksDao.getById('v1');
    expect(v1!.isLiked, true);
    expect(v1.downloadStatus, 'not_downloaded');
    // Second sync: v1 still liked (not newly-liked) -> must NOT be re-queued.
    likedReturns(['v1']);
    final result = await service.run();
    expect(enqueued, isEmpty);
    expect(result.newlyQueued, 0);
  });

  test('unliked tracks have isLiked cleared', () async {
    likedReturns(['v1', 'v2']);
    await service.run();
    likedReturns(['v1']);
    await service.run();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked.map((t) => t.videoId), ['v1']);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/sync/liked_auto_sync_service_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/sync/liked_auto_sync_service.dart`:

```dart
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';

typedef EnqueueDownloads = Future<void> Function(
  List<String> videoIds, {
  bool pinned,
});

class LikedSyncResult {
  const LikedSyncResult({required this.liked, required this.newlyQueued});

  /// Total liked tracks after the sync.
  final int liked;

  /// Newly-liked, not-yet-downloaded tracks queued for download this run.
  final int newlyQueued;
}

/// Headless (UI-free) liked-songs auto-sync. Runs identically in the foreground
/// and inside the workmanager background isolate.
class LikedAutoSyncService {
  LikedAutoSyncService({
    required LibraryRepository library,
    required AppDatabase db,
    required EnqueueDownloads enqueue,
  })  : _library = library,
        _db = db,
        _enqueue = enqueue;

  final LibraryRepository _library;
  final AppDatabase _db;
  final EnqueueDownloads _enqueue;

  Future<LikedSyncResult> run() async {
    final newlyLiked = await _library.refreshLikedReturningNew();

    final toQueue = <String>[];
    for (final id in newlyLiked) {
      final row = await _db.tracksDao.getById(id);
      if (row != null && row.downloadStatus == 'not_downloaded') {
        toQueue.add(id);
      }
    }
    if (toQueue.isNotEmpty) {
      await _enqueue(toQueue, pinned: false);
    }

    final likedCount = (await _db.tracksDao.watchLiked().first).length;
    return LikedSyncResult(liked: likedCount, newlyQueued: toQueue.length);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && fvm flutter test test/core/sync/liked_auto_sync_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/sync/liked_auto_sync_service.dart app/test/core/sync/liked_auto_sync_service_test.dart
git commit -m "feat(app): LikedAutoSyncService (newly-liked delta, no thrash)"
```

---

### Task 3: Eviction integration test (mixed pinned/unpinned)

**Files:**
- Test: `app/test/core/downloads/download_repository_test.dart`

> The eviction code already exists (Phase 5). Add one integration test proving
> auto-downloaded (`pinned=0`) tracks evict LRU-first while manual (`pinned=1`)
> tracks are never evicted, even when the cap is exceeded by the pinned set.

- [ ] **Step 1: Write the failing test**

Add to `app/test/core/downloads/download_repository_test.dart` (inside the existing
`main()`, matching its `setUp`/helpers — `repo` has `capBytes: 1000`, injected `deleteFile`
recording into `deleted`):

```dart
  test('eviction removes unpinned LRU but keeps pinned even over cap', () async {
    // pinned (manual) downloads totalling 1200 > cap 1000 — must be untouched.
    await downloaded('m1', 600, pinned: true);
    await downloaded('m2', 600, pinned: true);
    // unpinned (auto) downloads — oldest first by insertion (lastPlayedAt null).
    await downloaded('a1', 600); // unpinned, total unpinned = 600 <= 1000
    await downloaded('a2', 600); // unpinned, total unpinned = 1200 > 1000
    await repo.runEviction();
    // Only the LRU unpinned track is evicted to get unpinned under cap.
    expect(deleted, ['/audio/a1.m4a']);
    expect((await db.tracksDao.getById('m1'))!.downloadStatus, 'downloaded');
    expect((await db.tracksDao.getById('m2'))!.downloadStatus, 'downloaded');
    expect((await db.tracksDao.getById('a1'))!.downloadStatus, 'not_downloaded');
    expect((await db.tracksDao.getById('a2'))!.downloadStatus, 'downloaded');
  });
```

(If the existing `downloaded(...)` helper signature differs, match it. It seeds a row,
calls `markDownloaded` with `localPath: '/audio/$id.m4a'`, and sets `pinned` when asked.)

- [ ] **Step 2: Run to verify it fails (or confirm it passes)**

Run: `cd app && fvm flutter test test/core/downloads/download_repository_test.dart --plain-name "keeps pinned even over cap"`
Expected: PASS (eviction already behaves this way) — this test documents/locks the
auto-vs-manual contract. If it fails, the eviction logic has a bug; fix `runEviction`.

- [ ] **Step 3: Commit**

```bash
git add app/test/core/downloads/download_repository_test.dart
git commit -m "test(app): eviction keeps pinned (manual) over cap, evicts unpinned (auto)"
```

---

## Part B — Foreground triggers

### Task 4: Auto-sync providers + debounced trigger

**Files:**
- Create: `app/lib/core/sync/auto_sync_providers.dart`
- Test: `app/test/core/sync/auto_sync_providers_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/sync/auto_sync_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
  });
  tearDown(() async => db.close());

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(api),
      ]);

  test('trigger runs the sync when nothing synced yet', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final result = await c.read(triggerLikedAutoSyncProvider)();
    expect(result, isNotNull);
    verify(() => api.getLikedSongs(limit: any(named: 'limit'))).called(1);
  });

  test('trigger is debounced when library_liked is fresh', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(triggerLikedAutoSyncProvider)(); // marks fresh
    clearInteractions(api);
    final result = await c.read(triggerLikedAutoSyncProvider)(); // within ttl
    expect(result, isNull);
    verifyNever(() => api.getLikedSongs(limit: any(named: 'limit')));
  });

  test('force bypasses the debounce', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(triggerLikedAutoSyncProvider)();
    clearInteractions(api);
    final result = await c.read(triggerLikedAutoSyncProvider)(force: true);
    expect(result, isNotNull);
    verify(() => api.getLikedSongs(limit: any(named: 'limit'))).called(1);
  });

  test('no-op (null) when api is not configured', () async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(null),
    ]);
    addTearDown(c.dispose);
    final result = await c.read(triggerLikedAutoSyncProvider)();
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/sync/auto_sync_providers_test.dart`
Expected: FAIL — providers missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/sync/auto_sync_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

/// Minimum spacing between automatic (non-forced) liked syncs.
const Duration kAutoSyncMinInterval = Duration(minutes: 30);

/// Null when the backend isn't configured yet.
final likedAutoSyncProvider = Provider<LikedAutoSyncService?>((ref) {
  final library = ref.watch(libraryRepositoryProvider);
  if (library == null) return null;
  final repo = ref.watch(downloadRepositoryProvider);
  return LikedAutoSyncService(
    library: library,
    db: ref.watch(appDatabaseProvider),
    enqueue: (ids, {bool pinned = false}) => repo.enqueue(ids, pinned: pinned),
  );
});

/// Returns a callback that runs the liked auto-sync, debounced to
/// [kAutoSyncMinInterval] unless `force` is true. Returns the result, or null
/// if skipped (debounced) or the backend isn't configured.
final triggerLikedAutoSyncProvider =
    Provider<Future<LikedSyncResult?> Function({bool force})>((ref) {
  return ({bool force = false}) async {
    final service = ref.read(likedAutoSyncProvider);
    if (service == null) return null;
    if (!force) {
      final fresh = await ref
          .read(appDatabaseProvider)
          .syncStateDao
          .isFresh('library_liked', ttl: kAutoSyncMinInterval);
      if (fresh) return null;
    }
    return service.run();
  };
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && fvm flutter test test/core/sync/auto_sync_providers_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/sync/auto_sync_providers.dart app/test/core/sync/auto_sync_providers_test.dart
git commit -m "feat(app): liked auto-sync providers + debounced trigger"
```

---

### Task 5: Lifecycle observer + mount at app root

**Files:**
- Create: `app/lib/core/sync/auto_sync_observer.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/core/sync/auto_sync_observer_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/sync/auto_sync_observer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/sync/auto_sync_observer.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

void main() {
  testWidgets('triggers a sync on mount and on resume', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          triggerLikedAutoSyncProvider.overrideWithValue(({bool force = false}) async {
            calls++;
            return const LikedSyncResult(liked: 0, newlyQueued: 0);
          }),
        ],
        child: const MaterialApp(
          home: AutoSyncObserver(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump(); // post-frame mount trigger
    expect(calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/sync/auto_sync_observer_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/sync/auto_sync_observer.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/sync/auto_sync_providers.dart';

/// Triggers a (debounced) liked auto-sync when the app starts and each time it
/// returns to the foreground. Renders [child] unchanged.
class AutoSyncObserver extends ConsumerStatefulWidget {
  const AutoSyncObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoSyncObserver> createState() => _AutoSyncObserverState();
}

class _AutoSyncObserverState extends ConsumerState<AutoSyncObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    unawaited(ref.read(triggerLikedAutoSyncProvider)());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 4: Mount at app root**

In `app/lib/app.dart`, wrap the returned `MaterialApp.router` with `AutoSyncObserver`
and add the import `import 'package:ytmusic/core/sync/auto_sync_observer.dart';`:

```dart
    return AutoSyncObserver(
      child: MaterialApp.router(
        // ...unchanged...
      ),
    );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd app && fvm flutter test test/core/sync/auto_sync_observer_test.dart && fvm flutter test test/widget_test.dart`
Expected: PASS (observer test + the existing boot test — the observer is a no-op there
because `triggerLikedAutoSyncProvider` returns null when the api is unconfigured).

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/sync/auto_sync_observer.dart app/lib/app.dart app/test/core/sync/auto_sync_observer_test.dart
git commit -m "feat(app): AutoSyncObserver triggers liked sync on launch/resume"
```

---

## Part C — Background trigger (best-effort, workmanager)

### Task 6: Add workmanager dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `app/pubspec.yaml` under `dependencies:` (alphabetical):

```yaml
  workmanager: ^0.5.2
```

(Use the latest 0.5.x that resolves; verify the current API against Context7
`/fluttercommunity/flutter_workmanager` in Task 7.)

- [ ] **Step 2: Fetch + pods**

Run: `cd app && fvm flutter pub get && cd ios && pod install`
Expected: resolves; pods install. If `pod install` fails on the deployment target, the
project is already at iOS 14 (Phase 5) so it should pass; if a higher floor is required,
note it and bump consistently.

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/ios/Podfile.lock
git commit -m "build(app): add workmanager dependency"
```

---

### Task 7: Background sync entry point

**Files:**
- Create: `app/lib/core/sync/background_sync.dart`

> No unit test — this file wires plugins that only run on a device, so the gate is
> `fvm flutter analyze` (zero issues) plus the already-tested `LikedAutoSyncService`.
> **Verify the workmanager 0.5.x API against Context7 `/fluttercommunity/flutter_workmanager`
> before writing** (the `initialize`/`registerPeriodicTask`/iOS-task method names and the
> `@pragma('vm:entry-point')` requirement). Adapt the code below to the installed API.

- [ ] **Step 1: Implement**

Create `app/lib/core/sync/background_sync.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/background_downloader_gateway.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';
import 'package:ytmusic/core/library/library_repository.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

const String kLikedSyncTask = 'com.richarddepierre.ytmusic.likedSync';
const String _kLikedSyncUniqueName = 'liked-sync-periodic';

/// Runs in a SEPARATE isolate (no Riverpod). Builds its own dependencies from
/// secure storage and runs the same LikedAutoSyncService used in the foreground.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = await SettingsRepository().read();
    if (config == null) return true; // not configured -> nothing to do

    final db = AppDatabase();
    try {
      final api = ApiClient(config: config);
      final repo = DownloadRepository(db);
      final gateway = BackgroundDownloaderGateway();
      await gateway.configure(maxConcurrent: 3);

      final service = LikedAutoSyncService(
        library: LibraryRepository(db: db, api: api),
        db: db,
        enqueue: (ids, {bool pinned = false}) =>
            repo.enqueue(ids, pinned: pinned),
      );
      await service.run();

      // No stream watcher runs in this isolate, so drive the coordinator once.
      final coordinator = DownloadCoordinator(
        repository: repo,
        gateway: gateway,
        fetchManifest: (ids) => api.getManifest(ids),
      );
      await coordinator.reconcile();
      await coordinator.processQueueOnce();
      coordinator.dispose();
      gateway.dispose();
    } finally {
      await db.close();
    }
    return true;
  });
}

/// Initialize workmanager and register the periodic liked-sync task.
/// Call once from main().
Future<void> registerLikedAutoSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _kLikedSyncUniqueName,
    kLikedSyncTask,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `cd app && fvm flutter analyze lib/core/sync/background_sync.dart`
Expected: No issues. (Fix any symbol mismatches against the installed workmanager API.)

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/sync/background_sync.dart
git commit -m "feat(app): workmanager background liked-sync entry point"
```

---

### Task 8: Register background task + iOS native config

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Register in main()**

In `app/lib/main.dart`, add imports and call registration (fire-and-forget) after the
container is built and before/around `runApp` (do not block startup):

```dart
import 'package:ytmusic/core/sync/background_sync.dart';
// ...
  unawaited(registerLikedAutoSync());
```

(`unawaited` is already imported in main.dart from Phase 5; confirm.)

- [ ] **Step 2: iOS Info.plist**

In `app/ios/Runner/Info.plist`, add (inside the top-level `<dict>`):

```xml
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>com.richarddepierre.ytmusic.likedSync</string>
	</array>
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>processing</string>
	</array>
```

(If `UIBackgroundModes` already exists — Phase 5 may have added `audio` for playback —
merge the strings into the existing array rather than duplicating the key.)

- [ ] **Step 3: iOS AppDelegate registration**

In `app/ios/Runner/AppDelegate.swift`, register the task per the workmanager iOS setup
docs (verify exact calls via Context7). Typical form:

```swift
import workmanager
// inside application(_:didFinishLaunchingWithOptions:)
WorkmanagerPlugin.registerTask(withIdentifier: "com.richarddepierre.ytmusic.likedSync")
```

Adapt to the installed plugin's documented API.

- [ ] **Step 4: Verify analyze + boot**

Run: `cd app && fvm flutter analyze && fvm flutter test test/widget_test.dart`
Expected: analyze clean; the boot test still passes (registration is fire-and-forget and
guarded by config). Note: actual background execution can only be confirmed on a device.

- [ ] **Step 5: Commit**

```bash
git add app/lib/main.dart app/ios/Runner/Info.plist app/ios/Runner/AppDelegate.swift
git commit -m "feat(app): register workmanager periodic liked-sync + iOS background config"
```

---

## Part D — Manual control + verification

### Task 9: "Sync liked" action on the Downloads screen

**Files:**
- Modify: `app/lib/features/downloads/downloads_screen.dart`
- Test: `app/test/features/downloads/downloads_sync_action_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/downloads/downloads_sync_action_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';
import 'package:ytmusic/features/downloads/downloads_screen.dart';

void main() {
  testWidgets('Sync liked action runs sync and shows a SnackBar', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    var forced = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          triggerLikedAutoSyncProvider.overrideWithValue(({bool force = false}) async {
            forced = force;
            return const LikedSyncResult(liked: 3, newlyQueued: 2);
          }),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pump(); // let the SnackBar appear
    expect(forced, true);
    expect(find.textContaining('2'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/features/downloads/downloads_sync_action_test.dart`
Expected: FAIL — no sync icon.

- [ ] **Step 3: Implement**

In `app/lib/features/downloads/downloads_screen.dart`, add the import:

```dart
import 'package:ytmusic/core/sync/auto_sync_providers.dart';
```

and replace the `AppBar(title: const Text('Downloads'))` with one carrying a sync action:

```dart
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync liked songs',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result =
                  await ref.read(triggerLikedAutoSyncProvider)(force: true);
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text(result == null
                    ? 'Sync unavailable'
                    : 'Synced — ${result.newlyQueued} new queued'),
              ));
            },
          ),
        ],
      ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && fvm flutter test test/features/downloads/`
Expected: PASS (the new action test + the existing Downloads screen tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/downloads/downloads_screen.dart app/test/features/downloads/downloads_sync_action_test.dart
git commit -m "feat(app): manual 'Sync liked' action on Downloads screen"
```

---

### Task 10: Full verification

- [ ] **Step 1: Full app suite + analyze**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: all tests pass; analyze clean.

- [ ] **Step 2: Confirm no backend change needed**

This phase touches no backend code. (`/library/liked` already exists and is deployed.)
No VM 101 redeploy.

- [ ] **Step 3: Push + open PR**

```bash
git push -u origin worktree-phase-6-autosync
gh pr create --base main --title "feat(phase-6): auto-sync liked songs (download newly-liked, eviction live)" --body-file <(...)
```

PR body: no Claude co-author/footer trailer (per project CLAUDE.md). Summarize the
service, triggers (foreground + workmanager), the newly-liked thrash guard, eviction going
live, and that iOS background execution is OS-throttled (foreground is the reliable path).

- [ ] **Step 4: Second-brain update**

- Update `~/Documents/development-second-brain/.../Projects/yt-music.md`: mark Phase 6
  status, note auto-sync in the Flutter feature list.
- Add `~/Documents/.../yt-music-logs/2026-06-15-phase-6-autosync.md`
  (frontmatter `type: project-log`, `project: "[[yt-music]]"`, `date:`).

---

## Self-review notes

- **Spec coverage:** §1 thrash guard → Task 1 (delta) + Task 2 (guard test). §2 service →
  Task 2. §3 foreground triggers → Tasks 4 (debounced trigger) + 5 (observer). §4 background
  → Tasks 6–8. §5 eviction live → Task 3. §6 testing → Tasks 1–5, 9. UI sync action → Task 9.
- **Deferred (documented):** user-configurable cap (Phase 7); wifi/charging gating (chose
  any-connection — workmanager keeps only a `NetworkType.connected` constraint); playlist
  auto-sync; optimistic offline writes (Phase 4).
- **No-test-by-design:** `background_sync.dart` (Task 7) + iOS native config (Task 8) run
  only on-device; gated by `flutter analyze` + the tested `LikedAutoSyncService`. Real
  background execution needs an on-device check (noted, like Phase 5's smoke test).
- **Type consistency:** `refreshLikedReturningNew(): Future<Set<String>>`,
  `LikedAutoSyncService.run(): Future<LikedSyncResult>`, `EnqueueDownloads = Future<void>
  Function(List<String>, {bool pinned})`, `triggerLikedAutoSyncProvider: Future<LikedSyncResult?>
  Function({bool force})`, `LikedSyncResult{liked, newlyQueued}` — used consistently across tasks.
- **DRY:** one reconcile implementation (`refreshLikedReturningNew`), reused by `refreshLiked`
  and the service. Eviction code unchanged (Phase 5), only a new contract test added.
