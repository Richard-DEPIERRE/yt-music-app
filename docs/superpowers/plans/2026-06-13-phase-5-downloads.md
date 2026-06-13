# Phase 5 — Manual Downloads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user manually download a song, album, or playlist for offline playback, with pinned-vs-evictable tracking and an LRU eviction sweep.

**Architecture:** A new backend `POST /v1/downloads/manifest` bulk-resolves stream URLs (reusing `StreamResolver` + the bounded runner + the stream cache). The Flutter app gains a download core: a `FileDownloaderGateway` over the `background_downloader` plugin, a Drift-backed `DownloadRepository`, and a `DownloadCoordinator` that watches `queued` rows, fetches a manifest, drives the gateway, updates Drift on completion, and runs eviction. Playback prefers a local file when a track is downloaded.

**Tech Stack:** FastAPI + pydantic + yt-dlp (backend); Flutter + Riverpod + Drift + dio + background_downloader + just_audio/audio_service (app).

**Codec note:** the app plays **AAC** (iOS AVPlayer cannot decode Opus-in-WebM — see `audio_handler.dart`). Downloads therefore default to `codec='aac'`, container `m4a`, stored as `{videoId}.m4a`.

**No DB migration:** all download columns and the `tracks_download_status` index already exist at `schemaVersion = 1` (Phase 2). Do not bump the schema version.

---

## Part A — Backend manifest endpoint

### Task 1: Add artwork to ResolvedStream

**Files:**
- Modify: `backend/src/ytmusic_api/services/stream_resolver.py`
- Test: `backend/tests/test_stream_resolver.py`

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_stream_resolver.py`:

```python
def test_resolved_stream_has_artwork_url():
    from ytmusic_api.services.stream_resolver import _best_thumbnail

    thumbnails = [
        {"url": "https://img/small.jpg", "width": 120, "height": 120},
        {"url": "https://img/big.jpg", "width": 600, "height": 600},
    ]
    assert _best_thumbnail(thumbnails) == "https://img/big.jpg"
    assert _best_thumbnail([]) is None
    assert _best_thumbnail(None) is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_stream_resolver.py::test_resolved_stream_has_artwork_url -v`
Expected: FAIL — `cannot import name '_best_thumbnail'`.

- [ ] **Step 3: Implement**

In `stream_resolver.py`, add the `artwork_url` field to the dataclass and a helper, and populate it in `_resolve_sync`:

```python
@dataclass(frozen=True)
class ResolvedStream:
    video_id: str
    url: str
    expires_at: datetime
    codec: str
    container: str
    bitrate: int  # bps
    approx_duration_ms: int
    content_length: int | None
    artwork_url: str | None = None


def _best_thumbnail(thumbnails: list[dict[str, Any]] | None) -> str | None:
    if not thumbnails:
        return None
    best = max(
        thumbnails,
        key=lambda t: int(t.get("width") or 0) * int(t.get("height") or 0),
    )
    return best.get("url")
```

Then in `_resolve_sync`, before the `return`, compute `artwork = _best_thumbnail(info.get("thumbnails"))` and pass `artwork_url=artwork` into the `ResolvedStream(...)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/pytest tests/test_stream_resolver.py -v`
Expected: PASS (all existing tests still pass — `artwork_url` defaults to `None`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/services/stream_resolver.py backend/tests/test_stream_resolver.py
git commit -m "feat(backend): surface best-thumbnail artwork on ResolvedStream"
```

---

### Task 2: Manifest models

**Files:**
- Create: `backend/src/ytmusic_api/models/downloads.py`
- Test: `backend/tests/test_downloads_manifest.py` (created here, expanded in Task 3)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_downloads_manifest.py`:

```python
def test_manifest_request_defaults():
    from ytmusic_api.models.downloads import ManifestRequest

    req = ManifestRequest(videoIds=["a", "b"])
    assert req.codec == "aac"
    assert req.quality == "high"
    assert req.videoIds == ["a", "b"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_downloads_manifest.py::test_manifest_request_defaults -v`
Expected: FAIL — `ModuleNotFoundError: ytmusic_api.models.downloads`.

- [ ] **Step 3: Implement**

Create `backend/src/ytmusic_api/models/downloads.py`:

```python
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ManifestRequest(BaseModel):
    videoIds: list[str] = Field(..., min_length=1, max_length=50)
    codec: Literal["any", "aac", "opus"] = "aac"
    quality: Literal["high", "medium", "low"] = "high"


class ManifestItem(BaseModel):
    videoId: str
    url: str
    expiresAt: datetime
    codec: str
    container: str
    bitrate: int
    contentLength: int | None = None
    artworkUrl: str | None = None


class ManifestError(BaseModel):
    videoId: str
    error: str


class ManifestResponse(BaseModel):
    items: list[ManifestItem]
    errors: list[ManifestError]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/pytest tests/test_downloads_manifest.py::test_manifest_request_defaults -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/models/downloads.py backend/tests/test_downloads_manifest.py
git commit -m "feat(backend): manifest request/response models"
```

---

### Task 3: Manifest router

**Files:**
- Create: `backend/src/ytmusic_api/routers/downloads.py`
- Modify: `backend/src/ytmusic_api/main.py:15` (import) and `:103` (include_router)
- Test: `backend/tests/test_downloads_manifest.py`

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_downloads_manifest.py`:

```python
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.concurrency import BoundedRunner
from ytmusic_api.services.stream_resolver import ResolvedStream


class _MapResolver:
    """Resolves per-id from a payload map; missing ids raise."""

    def __init__(self, payloads=None, errors=None):
        self.payloads = payloads or {}
        self.errors = errors or {}
        self.calls = []

    async def resolve(self, video_id, *, codec, quality):
        self.calls.append((video_id, codec, quality))
        if video_id in self.errors:
            raise self.errors[video_id]
        return self.payloads[video_id]


def _payload(video_id):
    return ResolvedStream(
        video_id=video_id,
        url=f"https://rr.googlevideo.com/{video_id}",
        expires_at=datetime.utcnow() + timedelta(hours=6),
        codec="aac",
        container="m4a",
        bitrate=160_000,
        approx_duration_ms=180_000,
        content_length=4321,
        artwork_url="https://img/big.jpg",
    )


def _client(resolver):
    from ytmusic_api.auth.headers import HeadersStore
    from tests.conftest import StubMonitor
    from ytmusic_api.auth.health import AuthStatus

    app = create_app(
        headers_store=HeadersStore(path="/tmp/h.json"),
        auth_monitor=StubMonitor(status=AuthStatus(label="ok", last_ok_at=None)),
        cache=TtlCache(),
        stream_resolver=resolver,
        stream_runner=BoundedRunner(max_concurrent=3),
    )
    return TestClient(app)


def test_manifest_resolves_all_items():
    resolver = _MapResolver(payloads={"a": _payload("a"), "b": _payload("b")})
    client = _client(resolver)
    res = client.post("/v1/downloads/manifest", json={"videoIds": ["a", "b"]})
    assert res.status_code == 200
    body = res.json()
    assert {i["videoId"] for i in body["items"]} == {"a", "b"}
    assert body["errors"] == []
    item = body["items"][0]
    assert item["artworkUrl"] == "https://img/big.jpg"
    assert item["container"] == "m4a"


def test_manifest_isolates_per_item_errors():
    resolver = _MapResolver(
        payloads={"a": _payload("a")},
        errors={"bad": RuntimeError("boom")},
    )
    client = _client(resolver)
    res = client.post("/v1/downloads/manifest", json={"videoIds": ["a", "bad"]})
    assert res.status_code == 200
    body = res.json()
    assert [i["videoId"] for i in body["items"]] == ["a"]
    assert body["errors"] == [{"videoId": "bad", "error": "upstream_breakage"}]


def test_manifest_uses_stream_cache():
    resolver = _MapResolver(payloads={"a": _payload("a")})
    client = _client(resolver)
    client.post("/v1/downloads/manifest", json={"videoIds": ["a"], "codec": "aac"})
    client.post("/v1/downloads/manifest", json={"videoIds": ["a"], "codec": "aac"})
    assert len(resolver.calls) == 1  # second call served from cache


def test_manifest_rejects_empty_list():
    client = _client(_MapResolver())
    res = client.post("/v1/downloads/manifest", json={"videoIds": []})
    assert res.status_code == 422
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_downloads_manifest.py -v`
Expected: FAIL — 404 on POST (route not registered).

- [ ] **Step 3: Implement the router**

Create `backend/src/ytmusic_api/routers/downloads.py`:

```python
from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Request

from ..models.downloads import (
    ManifestError,
    ManifestItem,
    ManifestRequest,
    ManifestResponse,
)
from ..services.cache import TtlCache
from ..services.concurrency import BoundedRunner
from ..services.stream_resolver import StreamResolver

logger = logging.getLogger(__name__)
router = APIRouter()

_STREAM_TTL = 25 * 60  # match the single-track stream cache


@router.post("/downloads/manifest", response_model=ManifestResponse)
async def manifest(request: Request, body: ManifestRequest) -> ManifestResponse:
    cache: TtlCache = request.app.state.cache
    resolver: StreamResolver = request.app.state.stream_resolver
    runner: BoundedRunner = request.app.state.stream_runner

    async def resolve_one(video_id: str) -> ManifestItem | ManifestError:
        cache_key = f"stream:{video_id}:{body.codec}:{body.quality}"
        cached = cache.get(cache_key)
        if cached is not None:
            return ManifestItem(
                videoId=cached["videoId"],
                url=cached["url"],
                expiresAt=cached["expiresAt"],
                codec=cached["codec"],
                container=cached["container"],
                bitrate=cached["bitrate"],
                contentLength=cached.get("contentLength"),
                artworkUrl=cached.get("artworkUrl"),
            )
        try:
            resolved = await runner.run(
                resolver.resolve, video_id, codec=body.codec, quality=body.quality
            )
        except Exception as exc:  # noqa: BLE001 - per-item isolation
            logger.warning("Manifest resolution failed for %s: %s", video_id, exc)
            return ManifestError(videoId=video_id, error="upstream_breakage")

        item = ManifestItem(
            videoId=resolved.video_id,
            url=resolved.url,
            expiresAt=resolved.expires_at,
            codec=resolved.codec,
            container=resolved.container,
            bitrate=resolved.bitrate,
            contentLength=resolved.content_length,
            artworkUrl=resolved.artwork_url,
        )
        cache.set(cache_key, item.model_dump(mode="json"), ttl_seconds=_STREAM_TTL)
        return item

    results = await asyncio.gather(*(resolve_one(v) for v in body.videoIds))
    items = [r for r in results if isinstance(r, ManifestItem)]
    errors = [r for r in results if isinstance(r, ManifestError)]
    return ManifestResponse(items=items, errors=errors)
```

- [ ] **Step 4: Register the router**

In `backend/src/ytmusic_api/main.py`, add `downloads` to the import on line 15:

```python
from .routers import admin, catalog, discovery, downloads, health, library, stream
```

and add after the `stream` include (line ~102):

```python
    app.include_router(downloads.router, prefix="/v1")
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && .venv/bin/pytest tests/test_downloads_manifest.py -v`
Expected: PASS (4 tests).

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && .venv/bin/pytest -q`
Expected: all pass (was 78 + new).

- [ ] **Step 7: Commit**

```bash
git add backend/src/ytmusic_api/routers/downloads.py backend/src/ytmusic_api/main.py backend/tests/test_downloads_manifest.py
git commit -m "feat(backend): POST /v1/downloads/manifest bulk URL resolver"
```

---

## Part B — App: dependency, models, ApiClient

### Task 4: Add background_downloader dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `app/pubspec.yaml` under `dependencies:` (alphabetical, before `cached_network_image`):

```yaml
  background_downloader: ^9.0.0
```

(Use whatever the latest 9.x resolves to; verify exact API against Context7 `/781flyingdutchman/background_downloader` while implementing Task 8.)

- [ ] **Step 2: Fetch packages**

Run: `cd app && fvm flutter pub get`
Expected: resolves without conflict.

- [ ] **Step 3: iOS pods**

Run: `cd app/ios && fvm flutter precache --ios >/dev/null 2>&1; pod install`
Expected: pod install succeeds (downloads the native plugin). If it fails because the simulator/runner is mid-build, note it and continue — pods are only needed for a device/simulator run, not for `flutter test`.

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/ios/Podfile.lock
git commit -m "build(app): add background_downloader dependency"
```

---

### Task 5: Download manifest model (app)

**Files:**
- Create: `app/lib/core/api/models/download_manifest.dart`
- Test: `app/test/core/api/download_manifest_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/api/download_manifest_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';

void main() {
  test('parses items and errors', () {
    final json = {
      'items': [
        {
          'videoId': 'a',
          'url': 'https://cdn/a',
          'expiresAt': '2026-06-13T15:00:00Z',
          'codec': 'aac',
          'container': 'm4a',
          'bitrate': 160000,
          'contentLength': 4321,
          'artworkUrl': 'https://img/a.jpg',
        },
      ],
      'errors': [
        {'videoId': 'b', 'error': 'upstream_breakage'},
      ],
    };

    final manifest = DownloadManifest.fromJson(json);
    expect(manifest.items.single.videoId, 'a');
    expect(manifest.items.single.container, 'm4a');
    expect(manifest.items.single.contentLength, 4321);
    expect(manifest.errors.single.videoId, 'b');
  });

  test('tolerates null contentLength and artwork', () {
    final manifest = DownloadManifest.fromJson({
      'items': [
        {
          'videoId': 'a',
          'url': 'u',
          'expiresAt': '2026-06-13T15:00:00Z',
          'codec': 'aac',
          'container': 'm4a',
          'bitrate': 160000,
        },
      ],
      'errors': <dynamic>[],
    });
    expect(manifest.items.single.contentLength, isNull);
    expect(manifest.items.single.artworkUrl, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/api/download_manifest_test.dart`
Expected: FAIL — file/class missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/api/models/download_manifest.dart`:

```dart
class ManifestItem {
  ManifestItem({
    required this.videoId,
    required this.url,
    required this.expiresAt,
    required this.codec,
    required this.container,
    required this.bitrate,
    this.contentLength,
    this.artworkUrl,
  });

  factory ManifestItem.fromJson(Map<String, dynamic> json) => ManifestItem(
        videoId: json['videoId'] as String,
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        codec: json['codec'] as String,
        container: json['container'] as String,
        bitrate: json['bitrate'] as int,
        contentLength: json['contentLength'] as int?,
        artworkUrl: json['artworkUrl'] as String?,
      );

  final String videoId;
  final String url;
  final DateTime expiresAt;
  final String codec;
  final String container;
  final int bitrate;
  final int? contentLength;
  final String? artworkUrl;
}

class ManifestError {
  ManifestError({required this.videoId, required this.error});

  factory ManifestError.fromJson(Map<String, dynamic> json) => ManifestError(
        videoId: json['videoId'] as String,
        error: json['error'] as String,
      );

  final String videoId;
  final String error;
}

class DownloadManifest {
  DownloadManifest({required this.items, required this.errors});

  factory DownloadManifest.fromJson(Map<String, dynamic> json) =>
      DownloadManifest(
        items: (json['items'] as List)
            .map((e) => ManifestItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        errors: (json['errors'] as List)
            .map((e) => ManifestError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final List<ManifestItem> items;
  final List<ManifestError> errors;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd app && fvm flutter test test/core/api/download_manifest_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/api/models/download_manifest.dart app/test/core/api/download_manifest_test.dart
git commit -m "feat(app): DownloadManifest model"
```

---

### Task 6: ApiClient.getManifest

**Files:**
- Modify: `app/lib/core/api/api_client.dart` (add import + method)
- Test: `app/test/core/api/api_client_manifest_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/api/api_client_manifest_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;
  RequestOptions? captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('getManifest posts videoIds and parses response', () async {
    final client = ApiClient(
      config: const ApiConfig(
        baseUrl: 'https://example.com',
        cfAccessClientId: 'id',
        cfAccessClientSecret: 'secret',
      ),
    );
    final adapter = _StubAdapter(
      '{"items":[{"videoId":"a","url":"u","expiresAt":"2026-06-13T15:00:00Z",'
      '"codec":"aac","container":"m4a","bitrate":160000}],"errors":[]}',
    );
    client.dio.httpClientAdapter = adapter;

    final manifest = await client.getManifest(['a'], codec: 'aac');

    expect(manifest.items.single.videoId, 'a');
    expect(adapter.captured!.path, '/v1/downloads/manifest');
    expect(adapter.captured!.method, 'POST');
    expect((adapter.captured!.data as Map)['videoIds'], ['a']);
    expect((adapter.captured!.data as Map)['codec'], 'aac');
  });
}
```

(If `ApiConfig`'s constructor signature differs, match the real one in `app/lib/core/api/api_config.dart`.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/api/api_client_manifest_test.dart`
Expected: FAIL — `getManifest` undefined.

- [ ] **Step 3: Implement**

In `app/lib/core/api/api_client.dart`, add the import near the other model imports:

```dart
import 'package:ytmusic/core/api/models/download_manifest.dart';
```

and add this method inside the `ApiClient` class (e.g. after `getHome`):

```dart
  Future<DownloadManifest> getManifest(
    List<String> videoIds, {
    String codec = 'aac',
    String quality = 'high',
  }) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/downloads/manifest',
        data: {
          'videoIds': videoIds,
          'codec': codec,
          'quality': quality,
        },
      );
      return DownloadManifest.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd app && fvm flutter test test/core/api/api_client_manifest_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/api/api_client.dart app/test/core/api/api_client_manifest_test.dart
git commit -m "feat(app): ApiClient.getManifest"
```

---

## Part C — App: download gateway + repository

### Task 7: Gateway interface + value types

**Files:**
- Create: `app/lib/core/downloads/download_gateway.dart`
- Test: covered indirectly; no standalone test (pure interface + data classes).

- [ ] **Step 1: Create the interface**

Create `app/lib/core/downloads/download_gateway.dart`:

```dart
/// What the coordinator asks the gateway to fetch.
class DownloadRequest {
  const DownloadRequest({
    required this.videoId,
    required this.url,
    required this.ext, // 'm4a' | 'webm'
  });

  final String videoId;
  final String url;
  final String ext;
}

enum DownloadEventKind { progress, complete, failed, urlExpired }

/// A normalized event emitted by the gateway for one videoId.
class DownloadEvent {
  const DownloadEvent({
    required this.videoId,
    required this.kind,
    this.progress = 0,
    this.filePath,
  });

  final String videoId;
  final DownloadEventKind kind;
  final double progress; // 0..1, only for progress events
  final String? filePath; // absolute path, only for complete events
}

/// Abstraction over background_downloader so the coordinator is testable
/// with a fake.
abstract class FileDownloaderGateway {
  Future<void> configure({int maxConcurrent = 3});

  /// Begin (or resume) a download. Uses videoId as the task id.
  Future<void> enqueue(DownloadRequest req);

  /// Re-point an in-flight/partial download at a fresh URL and resume.
  Future<void> resume(DownloadRequest req);

  Future<void> cancel(String videoId);

  /// videoIds the downloader still has live/persisted tasks for
  /// (used for launch reconciliation).
  Future<Set<String>> activeVideoIds();

  Stream<DownloadEvent> get events;
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd app && fvm flutter analyze lib/core/downloads/download_gateway.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/downloads/download_gateway.dart
git commit -m "feat(app): FileDownloaderGateway interface + event types"
```

---

### Task 8: background_downloader gateway implementation

**Files:**
- Create: `app/lib/core/downloads/background_downloader_gateway.dart`

> Verify the exact `background_downloader` API against Context7
> (`/781flyingdutchman/background_downloader`) before writing this. The shapes
> below match v9.x: `DownloadTask`, `FileDownloader().enqueue/start/updates`,
> `TaskStatusUpdate`/`TaskProgressUpdate`, `pause/resume`,
> `BaseDirectory.applicationDocuments`, `TaskHttpException.httpResponseCode`.

- [ ] **Step 1: Implement**

Create `app/lib/core/downloads/background_downloader_gateway.dart`:

```dart
import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'package:ytmusic/core/downloads/download_gateway.dart';

const String _kGroup = 'audio';

class BackgroundDownloaderGateway implements FileDownloaderGateway {
  BackgroundDownloaderGateway() {
    _sub = FileDownloader().updates.listen(_onUpdate);
  }

  final _controller = StreamController<DownloadEvent>.broadcast();
  late final StreamSubscription<TaskUpdate> _sub;

  @override
  Stream<DownloadEvent> get events => _controller.stream;

  @override
  Future<void> configure({int maxConcurrent = 3}) async {
    final tq = MemoryTaskQueue()..maxConcurrent = maxConcurrent;
    FileDownloader().addTaskQueue(tq);
    _queue = tq;
    FileDownloader().start();
  }

  MemoryTaskQueue? _queue;

  DownloadTask _task(DownloadRequest req) => DownloadTask(
        taskId: req.videoId,
        url: req.url,
        filename: '${req.videoId}.${req.ext}',
        directory: 'audio',
        baseDirectory: BaseDirectory.applicationDocuments,
        group: _kGroup,
        updates: Updates.statusAndProgress,
        allowPause: true,
        retries: 0, // retry/backoff handled by the coordinator
      );

  @override
  Future<void> enqueue(DownloadRequest req) async {
    final task = _task(req);
    final tq = _queue;
    if (tq != null) {
      tq.add(task);
    } else {
      await FileDownloader().enqueue(task);
    }
  }

  @override
  Future<void> resume(DownloadRequest req) async {
    // background_downloader keeps the .partial file keyed by taskId; a fresh
    // enqueue with the same taskId + new URL resumes via HTTP Range.
    await FileDownloader().enqueue(_task(req));
  }

  @override
  Future<void> cancel(String videoId) async {
    await FileDownloader().cancelTasksWithIds([videoId]);
  }

  @override
  Future<Set<String>> activeVideoIds() async {
    final records = await FileDownloader().database.allRecords();
    return records.map((r) => r.taskId).toSet();
  }

  void _onUpdate(TaskUpdate update) {
    final videoId = update.task.taskId;
    if (update is TaskProgressUpdate) {
      _controller.add(DownloadEvent(
        videoId: videoId,
        kind: DownloadEventKind.progress,
        progress: update.progress,
      ));
      return;
    }
    if (update is TaskStatusUpdate) {
      switch (update.status) {
        case TaskStatus.complete:
          unawaited(_emitComplete(update.task, videoId));
        case TaskStatus.failed:
          final exc = update.exception;
          final expired = exc is TaskHttpException &&
              (exc.httpResponseCode == 403 || exc.httpResponseCode == 410);
          _controller.add(DownloadEvent(
            videoId: videoId,
            kind: expired
                ? DownloadEventKind.urlExpired
                : DownloadEventKind.failed,
          ));
        case TaskStatus.canceled:
        case TaskStatus.paused:
        case TaskStatus.notFound:
        case TaskStatus.waitingToRetry:
        case TaskStatus.enqueued:
        case TaskStatus.running:
          break;
      }
    }
  }

  Future<void> _emitComplete(Task task, String videoId) async {
    final path = await task.filePath();
    _controller.add(DownloadEvent(
      videoId: videoId,
      kind: DownloadEventKind.complete,
      filePath: path,
    ));
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd app && fvm flutter analyze lib/core/downloads/background_downloader_gateway.dart`
Expected: No issues. (If any enum/member name differs from the installed plugin version, fix to match — this file is the only place that touches the plugin API.)

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/downloads/background_downloader_gateway.dart
git commit -m "feat(app): background_downloader gateway implementation"
```

---

### Task 9: DownloadsDao

**Files:**
- Create: `app/lib/core/db/daos/downloads_dao.dart`
- Modify: `app/lib/core/db/database.dart` (import + register dao)
- Test: `app/test/core/db/downloads_dao_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/db/downloads_dao_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(String id, {String status = 'not_downloaded'}) {
    return db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: id,
        title: 'T $id',
        downloadStatus: Value(status),
      ),
    );
  }

  test('enqueue sets queued + pinned for existing tracks', () async {
    await seed('a');
    await db.downloadsDao.enqueue(['a'], pinned: true);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'queued');
    expect(row.pinned, true);
  });

  test('watchQueued emits queued rows', () async {
    await seed('a', status: 'queued');
    final rows = await db.downloadsDao.watchQueued().first;
    expect(rows.map((r) => r.videoId), ['a']);
  });

  test('markDownloaded records file fields', () async {
    await seed('a', status: 'downloading');
    await db.downloadsDao.markDownloaded(
      'a',
      localPath: '/docs/audio/a.m4a',
      sizeBytes: 1000,
      codec: 'aac',
      bitrate: 160000,
    );
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloaded');
    expect(row.localPath, '/docs/audio/a.m4a');
    expect(row.sizeBytes, 1000);
    expect(row.downloadedAt, isNotNull);
  });

  test('unpinnedDownloadedBytes sums only unpinned downloaded', () async {
    await seed('p', status: 'downloading');
    await db.downloadsDao.markDownloaded('p',
        localPath: '/p', sizeBytes: 500, codec: 'aac', bitrate: 1);
    await db.downloadsDao.setPinned(['p'], true);
    await seed('u', status: 'downloading');
    await db.downloadsDao.markDownloaded('u',
        localPath: '/u', sizeBytes: 700, codec: 'aac', bitrate: 1);
    expect(await db.downloadsDao.unpinnedDownloadedBytes(), 700);
  });

  test('lruUnpinned orders by lastPlayedAt ascending (nulls first)', () async {
    await seed('old', status: 'downloading');
    await db.downloadsDao.markDownloaded('old',
        localPath: '/old', sizeBytes: 1, codec: 'aac', bitrate: 1);
    final rows = await db.downloadsDao.lruUnpinned();
    expect(rows.first.videoId, 'old');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/db/downloads_dao_test.dart`
Expected: FAIL — `downloadsDao` undefined.

- [ ] **Step 3: Implement the DAO**

Create `app/lib/core/db/daos/downloads_dao.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'downloads_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  Future<void> enqueue(List<String> videoIds, {required bool pinned}) async {
    await (update(tracks)..where((t) => t.videoId.isIn(videoIds))).write(
      TracksCompanion(
        downloadStatus: const Value('queued'),
        pinned: Value(pinned),
        lastDownloadError: const Value(null),
      ),
    );
  }

  Stream<List<Track>> watchQueued() =>
      (select(tracks)..where((t) => t.downloadStatus.equals('queued'))).watch();

  Stream<List<Track>> watchDownloaded() => (select(tracks)
        ..where((t) => t.downloadStatus.equals('downloaded'))
        ..orderBy([
          (t) => OrderingTerm(
              expression: t.downloadedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<Track>> orphanedDownloading() =>
      (select(tracks)..where((t) => t.downloadStatus.equals('downloading')))
          .get();

  Future<void> markDownloading(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(downloadStatus: Value('downloading')),
      );

  Future<void> markDownloaded(
    String videoId, {
    required String localPath,
    required int sizeBytes,
    required String codec,
    required int bitrate,
  }) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        TracksCompanion(
          downloadStatus: const Value('downloaded'),
          localPath: Value(localPath),
          sizeBytes: Value(sizeBytes),
          downloadedCodec: Value(codec),
          downloadedBitrate: Value(bitrate),
          downloadedAt: Value(DateTime.now()),
          lastDownloadError: const Value(null),
        ),
      );

  Future<void> markFailed(String videoId, String error, int attempts) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        TracksCompanion(
          downloadStatus: const Value('failed'),
          lastDownloadError: Value(error),
          downloadAttempts: Value(attempts),
        ),
      );

  Future<void> requeue(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(downloadStatus: Value('queued')),
      );

  Future<void> setPinned(List<String> videoIds, bool pinned) =>
      (update(tracks)..where((t) => t.videoId.isIn(videoIds)))
          .write(TracksCompanion(pinned: Value(pinned)));

  Future<int> unpinnedDownloadedBytes() async {
    final sum = tracks.sizeBytes.sum();
    final q = selectOnly(tracks)
      ..addColumns([sum])
      ..where(tracks.downloadStatus.equals('downloaded') &
          tracks.pinned.equals(false));
    final row = await q.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<List<Track>> lruUnpinned() => (select(tracks)
        ..where((t) =>
            t.downloadStatus.equals('downloaded') & t.pinned.equals(false))
        ..orderBy([
          (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                mode: OrderingMode.asc,
                nulls: NullsOrder.first,
              ),
        ]))
      .get();

  Future<void> clearDownload(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(
          downloadStatus: Value('not_downloaded'),
          pinned: Value(false),
          localPath: Value(null),
          sizeBytes: Value(null),
          downloadedCodec: Value(null),
          downloadedBitrate: Value(null),
          downloadedAt: Value(null),
        ),
      );
}
```

- [ ] **Step 4: Register the DAO**

In `app/lib/core/db/database.dart`: add import

```dart
import 'package:ytmusic/core/db/daos/downloads_dao.dart';
```

and add `DownloadsDao` to the `daos:` list in the `@DriftDatabase(...)` annotation.

- [ ] **Step 5: Run codegen**

Run: `cd app && fvm dart run build_runner build --delete-conflicting-outputs`
Expected: generates `downloads_dao.g.dart` and updates `database.g.dart`.

- [ ] **Step 6: Run tests**

Run: `cd app && fvm flutter test test/core/db/downloads_dao_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/db/daos/downloads_dao.dart app/lib/core/db/daos/downloads_dao.g.dart app/lib/core/db/database.dart app/lib/core/db/database.g.dart app/test/core/db/downloads_dao_test.dart
git commit -m "feat(app): DownloadsDao (enqueue, state, eviction queries)"
```

---

### Task 10: DownloadRepository (DAO + filesystem)

**Files:**
- Create: `app/lib/core/downloads/download_repository.dart`
- Test: `app/test/core/downloads/download_repository_test.dart`

> The repository owns filesystem side effects (deleting evicted files). To keep
> it testable, file deletion goes through an injectable `Future<void>
> Function(String path)` defaulting to real `File(path).delete()`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/downloads/download_repository_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

void main() {
  late AppDatabase db;
  late List<String> deleted;
  late DownloadRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deleted = [];
    repo = DownloadRepository(
      db,
      capBytes: 1000,
      deleteFile: (p) async => deleted.add(p),
    );
  });
  tearDown(() => db.close());

  Future<void> downloaded(String id, int size, {bool pinned = false}) async {
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(videoId: id, title: id),
    );
    await db.downloadsDao.markDownloaded(id,
        localPath: '/audio/$id.m4a', sizeBytes: size, codec: 'aac', bitrate: 1);
    if (pinned) await db.downloadsDao.setPinned([id], true);
  }

  test('eviction deletes LRU unpinned until under cap', () async {
    await downloaded('a', 600); // unpinned, oldest
    await downloaded('b', 600); // unpinned
    // total unpinned = 1200 > cap 1000 -> evict oldest (a, 600) -> 600 <= 1000
    await repo.runEviction();
    expect(deleted, ['/audio/a.m4a']);
    final a = await db.tracksDao.getById('a');
    expect(a!.downloadStatus, 'not_downloaded');
    expect(a.localPath, isNull);
  });

  test('eviction never touches pinned tracks', () async {
    await downloaded('p', 5000, pinned: true);
    await repo.runEviction();
    expect(deleted, isEmpty);
  });

  test('removeDownload deletes file and clears row', () async {
    await downloaded('a', 100);
    await repo.removeDownload('a');
    expect(deleted, ['/audio/a.m4a']);
    final a = await db.tracksDao.getById('a');
    expect(a!.downloadStatus, 'not_downloaded');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/downloads/download_repository_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/downloads/download_repository.dart`:

```dart
import 'dart:io';

import 'package:ytmusic/core/db/database.dart';

const int kDefaultCapBytes = 10 * 1024 * 1024 * 1024; // 10 GB

typedef DeleteFile = Future<void> Function(String path);

Future<void> _realDelete(String path) async {
  final f = File(path);
  if (f.existsSync()) await f.delete();
}

class DownloadRepository {
  DownloadRepository(
    this._db, {
    int capBytes = kDefaultCapBytes,
    DeleteFile deleteFile = _realDelete,
  })  : _capBytes = capBytes,
        _deleteFile = deleteFile;

  final AppDatabase _db;
  final int _capBytes;
  final DeleteFile _deleteFile;

  DownloadsDao get _dao => _db.downloadsDao;

  Future<void> enqueue(List<String> videoIds, {bool pinned = true}) =>
      _dao.enqueue(videoIds, pinned: pinned);

  Stream<List<Track>> watchQueued() => _dao.watchQueued();
  Stream<List<Track>> watchDownloaded() => _dao.watchDownloaded();
  Future<List<Track>> orphanedDownloading() => _dao.orphanedDownloading();

  Future<void> markDownloading(String videoId) => _dao.markDownloading(videoId);

  Future<void> markDownloaded(
    String videoId, {
    required String localPath,
    required int sizeBytes,
    required String codec,
    required int bitrate,
  }) =>
      _dao.markDownloaded(videoId,
          localPath: localPath,
          sizeBytes: sizeBytes,
          codec: codec,
          bitrate: bitrate);

  Future<void> markFailed(String videoId, String error, int attempts) =>
      _dao.markFailed(videoId, error, attempts);

  Future<void> requeue(String videoId) => _dao.requeue(videoId);

  Future<void> removeDownload(String videoId) async {
    final row = await _db.tracksDao.getById(videoId);
    if (row?.localPath != null) await _deleteFile(row!.localPath!);
    await _dao.clearDownload(videoId);
  }

  /// LRU-evict unpinned downloaded tracks until total size <= cap.
  Future<void> runEviction() async {
    var total = await _dao.unpinnedDownloadedBytes();
    if (total <= _capBytes) return;
    final lru = await _dao.lruUnpinned();
    for (final track in lru) {
      if (total <= _capBytes) break;
      if (track.localPath != null) await _deleteFile(track.localPath!);
      await _dao.clearDownload(track.videoId);
      total -= track.sizeBytes ?? 0;
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test test/core/downloads/download_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/downloads/download_repository.dart app/test/core/downloads/download_repository_test.dart
git commit -m "feat(app): DownloadRepository with LRU eviction"
```

---

## Part D — Coordinator

### Task 11: DownloadCoordinator

**Files:**
- Create: `app/lib/core/downloads/download_coordinator.dart`
- Test: `app/test/core/downloads/download_coordinator_test.dart`

> The coordinator depends on `DownloadRepository`, a `FileDownloaderGateway`,
> and a manifest fetcher `Future<DownloadManifest> Function(List<String>)`.
> Tests pass a fake gateway and a fake fetcher. Real wiring uses
> `ApiClient.getManifest`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/downloads/download_coordinator_test.dart`:

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

class FakeGateway implements FileDownloaderGateway {
  final _controller = StreamController<DownloadEvent>.broadcast();
  final List<DownloadRequest> enqueued = [];
  final List<DownloadRequest> resumed = [];
  Set<String> active = {};

  @override
  Stream<DownloadEvent> get events => _controller.stream;
  @override
  Future<void> configure({int maxConcurrent = 3}) async {}
  @override
  Future<void> enqueue(DownloadRequest req) async => enqueued.add(req);
  @override
  Future<void> resume(DownloadRequest req) async => resumed.add(req);
  @override
  Future<void> cancel(String videoId) async {}
  @override
  Future<Set<String>> activeVideoIds() async => active;

  void emit(DownloadEvent e) => _controller.add(e);
}

ManifestItem _item(String id) => ManifestItem(
      videoId: id,
      url: 'https://cdn/$id',
      expiresAt: DateTime(2026, 6, 13, 15),
      codec: 'aac',
      container: 'm4a',
      bitrate: 160000,
      contentLength: 100,
    );

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late DownloadRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repo = DownloadRepository(db, deleteFile: (_) async {});
  });
  tearDown(() => db.close());

  Future<void> seedQueued(String id) async {
    await db.tracksDao.upsertTrack(TracksCompanion.insert(videoId: id, title: id));
    await db.downloadsDao.enqueue([id], pinned: true);
  }

  DownloadCoordinator make({
    Future<DownloadManifest> Function(List<String>)? fetch,
  }) =>
      DownloadCoordinator(
        repository: repo,
        gateway: gateway,
        fetchManifest: fetch ??
            (ids) async => DownloadManifest(
                  items: ids.map(_item).toList(),
                  errors: [],
                ),
      );

  test('queued rows are resolved and enqueued into the gateway', () async {
    await seedQueued('a');
    final coord = make();
    await coord.processQueueOnce();
    expect(gateway.enqueued.map((r) => r.videoId), ['a']);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloading');
  });

  test('manifest per-item error marks the track failed', () async {
    await seedQueued('bad');
    final coord = make(
      fetch: (ids) async => DownloadManifest(
        items: [],
        errors: [ManifestError(videoId: 'bad', error: 'upstream_breakage')],
      ),
    );
    await coord.processQueueOnce();
    final row = await db.tracksDao.getById('bad');
    expect(row!.downloadStatus, 'failed');
  });

  test('complete event marks downloaded', () async {
    await seedQueued('a');
    final coord = make()..start();
    await coord.processQueueOnce();
    gateway.emit(DownloadEvent(
      videoId: 'a',
      kind: DownloadEventKind.complete,
      filePath: '/audio/a.m4a',
    ));
    await Future<void>.delayed(Duration.zero);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloaded');
    expect(row.localPath, '/audio/a.m4a');
    coord.dispose();
  });

  test('urlExpired event re-resolves and resumes', () async {
    await seedQueued('a');
    final coord = make()..start();
    await coord.processQueueOnce();
    gateway.emit(
        DownloadEvent(videoId: 'a', kind: DownloadEventKind.urlExpired));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.resumed.map((r) => r.videoId), ['a']);
    coord.dispose();
  });

  test('reconcile requeues orphaned downloading rows', () async {
    await db.tracksDao.upsertTrack(TracksCompanion.insert(videoId: 'a', title: 'a'));
    await db.downloadsDao.markDownloading('a');
    gateway.active = {}; // downloader lost the task
    final coord = make();
    await coord.reconcile();
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'queued');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/downloads/download_coordinator_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement**

Create `app/lib/core/downloads/download_coordinator.dart`:

```dart
import 'dart:async';

import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

typedef FetchManifest = Future<DownloadManifest> Function(List<String> ids);

const int _kBatchSize = 8;
const int _kMaxAttempts = 3;

class DownloadCoordinator {
  DownloadCoordinator({
    required DownloadRepository repository,
    required FileDownloaderGateway gateway,
    required FetchManifest fetchManifest,
  })  : _repo = repository,
        _gateway = gateway,
        _fetch = fetchManifest;

  final DownloadRepository _repo;
  final FileDownloaderGateway _gateway;
  final FetchManifest _fetch;

  StreamSubscription<List<dynamic>>? _queueSub;
  StreamSubscription<DownloadEvent>? _eventSub;
  // last resolved URL per videoId, for resume on expiry
  final Map<String, ManifestItem> _resolved = {};
  bool _busy = false;

  /// Start watching the queue + gateway events. Call once at app startup
  /// after `reconcile()`.
  void start() {
    _eventSub = _gateway.events.listen(_onEvent);
    _queueSub = _repo.watchQueued().listen((_) => unawaited(processQueueOnce()));
  }

  Future<void> reconcile() async {
    final active = await _gateway.activeVideoIds();
    for (final row in await _repo.orphanedDownloading()) {
      if (!active.contains(row.videoId)) {
        await _repo.requeue(row.videoId);
      }
    }
  }

  /// Resolve + enqueue all currently-queued tracks, in batches of 8.
  Future<void> processQueueOnce() async {
    if (_busy) return;
    _busy = true;
    try {
      final queued = await _repo.watchQueued().first;
      for (var i = 0; i < queued.length; i += _kBatchSize) {
        final batch = queued.skip(i).take(_kBatchSize).toList();
        final ids = batch.map((t) => t.videoId).toList();
        final manifest = await _fetch(ids);
        for (final err in manifest.errors) {
          await _repo.markFailed(err.videoId, err.error, _kMaxAttempts);
        }
        for (final item in manifest.items) {
          _resolved[item.videoId] = item;
          await _repo.markDownloading(item.videoId);
          await _gateway.enqueue(_requestFor(item));
        }
      }
    } finally {
      _busy = false;
    }
  }

  DownloadRequest _requestFor(ManifestItem item) => DownloadRequest(
        videoId: item.videoId,
        url: item.url,
        ext: item.container, // 'm4a' | 'webm'
      );

  Future<void> _onEvent(DownloadEvent e) async {
    switch (e.kind) {
      case DownloadEventKind.complete:
        final item = _resolved[e.videoId];
        final size = item?.contentLength ?? 0;
        await _repo.markDownloaded(
          e.videoId,
          localPath: e.filePath ?? '',
          sizeBytes: size,
          codec: item?.codec ?? 'aac',
          bitrate: item?.bitrate ?? 0,
        );
        _resolved.remove(e.videoId);
        await _repo.runEviction();
      case DownloadEventKind.urlExpired:
        await _reResolveAndResume(e.videoId);
      case DownloadEventKind.failed:
        await _repo.markFailed(e.videoId, 'download_failed', _kMaxAttempts);
        _resolved.remove(e.videoId);
      case DownloadEventKind.progress:
        break;
    }
  }

  Future<void> _reResolveAndResume(String videoId) async {
    try {
      final manifest = await _fetch([videoId]);
      final item = manifest.items
          .where((i) => i.videoId == videoId)
          .cast<ManifestItem?>()
          .firstWhere((_) => true, orElse: () => null);
      if (item == null) {
        await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
        return;
      }
      _resolved[videoId] = item;
      await _gateway.resume(_requestFor(item));
    } on Object {
      await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
    }
  }

  void dispose() {
    _queueSub?.cancel();
    _eventSub?.cancel();
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test test/core/downloads/download_coordinator_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/downloads/download_coordinator.dart app/test/core/downloads/download_coordinator_test.dart
git commit -m "feat(app): DownloadCoordinator (queue, manifest, events, eviction)"
```

---

### Task 12: Download providers + app startup wiring

**Files:**
- Create: `app/lib/core/downloads/download_providers.dart`
- Modify: `app/lib/main.dart` (start coordinator after app init) — adapt to the real bootstrap file if named differently.

- [ ] **Step 1: Create providers**

Create `app/lib/core/downloads/download_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/background_downloader_gateway.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(appDatabaseProvider));
});

final fileDownloaderGatewayProvider = Provider<FileDownloaderGateway>((ref) {
  final gateway = BackgroundDownloaderGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

final downloadCoordinatorProvider = Provider<DownloadCoordinator>((ref) {
  final coordinator = DownloadCoordinator(
    repository: ref.watch(downloadRepositoryProvider),
    gateway: ref.watch(fileDownloaderGatewayProvider),
    fetchManifest: (ids) {
      final api = ref.read(apiClientProvider);
      return api.getManifest(ids);
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
```

> Check `api_providers.dart` for the real provider name; it may be
> `apiClientProvider` returning `ApiClient?`. If nullable, throw/guard before
> calling `getManifest`. Adjust the closure accordingly.

- [ ] **Step 2: Start the coordinator at app launch**

In the app bootstrap (`app/lib/main.dart` or the root widget's `initState`/a
startup provider), after the database and API are ready, run:

```dart
final coordinator = ref.read(downloadCoordinatorProvider);
await coordinator.configureGatewayAndStart();
```

Add this convenience method to `DownloadCoordinator` (so callers don't touch the
gateway directly):

```dart
  Future<void> configureGatewayAndStart() async {
    await _gateway.configure(maxConcurrent: 3);
    await reconcile();
    start();
    await processQueueOnce();
  }
```

(Re-run the coordinator test file after adding the method to confirm nothing broke.)

- [ ] **Step 3: Analyze**

Run: `cd app && fvm flutter analyze lib/core/downloads`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add app/lib/core/downloads/download_providers.dart app/lib/core/downloads/download_coordinator.dart app/lib/main.dart
git commit -m "feat(app): download providers + startup wiring"
```

---

## Part E — Playback integration

### Task 13: Prefer local file for downloaded tracks

**Files:**
- Modify: `app/lib/core/audio/audio_handler.dart`
- Modify: `app/lib/core/audio/audio_providers.dart` (inject the local-source lookup)
- Test: `app/test/core/audio/local_source_test.dart`

> Keep the handler decoupled from Drift: inject two optional callbacks —
> `localFileFor(videoId) -> Future<String?>` (absolute path if downloaded and
> the file exists; else null) and `onPlayed(videoId)` (touch `lastPlayedAt`).

- [ ] **Step 1: Write the failing test**

Create `app/test/core/audio/local_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

void main() {
  test('chooseSource returns file uri when local path present', () async {
    final src = await AudioPlaybackHandler.chooseSource(
      videoId: 'a',
      localFileFor: (id) async => '/audio/a.m4a',
      resolveStreamUrl: (id) async => 'https://cdn/a',
    );
    expect(src, 'file:///audio/a.m4a');
  });

  test('chooseSource falls back to stream url when no local file', () async {
    final src = await AudioPlaybackHandler.chooseSource(
      videoId: 'a',
      localFileFor: (id) async => null,
      resolveStreamUrl: (id) async => 'https://cdn/a',
    );
    expect(src, 'https://cdn/a');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/core/audio/local_source_test.dart`
Expected: FAIL — `chooseSource` undefined.

- [ ] **Step 3: Implement the source-selection helper + wire it in**

In `audio_handler.dart`, add fields and a static helper, then use it in `playTrack`:

```dart
  // new fields on AudioPlaybackHandler
  final Future<String?> Function(String videoId)? localFileFor;
  final void Function(String videoId)? onPlayed;

  static Future<String> chooseSource({
    required String videoId,
    required Future<String?> Function(String) localFileFor,
    required Future<String> Function(String) resolveStreamUrl,
  }) async {
    final local = await localFileFor(videoId);
    if (local != null) return Uri.file(local).toString();
    return resolveStreamUrl(videoId);
  }
```

Add the two callbacks to the constructor (optional, default null). In
`playTrack`, replace the direct `resolveStream` + `setAudioSource` block with:

```dart
  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    final api = _requireApi();
    final sourceUrl = await chooseSource(
      videoId: track.videoId,
      localFileFor: localFileFor ?? (_) async => null,
      resolveStreamUrl: (id) async =>
          (await api.resolveStream(id, codec: 'aac')).url,
    );
    mediaItem.add(_toMediaItem(track));
    await _player.setAudioSource(AudioSource.uri(Uri.parse(sourceUrl)));
    onPlayed?.call(track.videoId);
    await _player.play();
  }
```

- [ ] **Step 4: Wire the callbacks in `audio_providers.dart`**

Where the `AudioPlaybackHandler` is constructed, pass:

```dart
        localFileFor: (videoId) async {
          final row = await ref.read(appDatabaseProvider).tracksDao.getById(videoId);
          if (row?.downloadStatus == 'downloaded' && row?.localPath != null) {
            return File(row!.localPath!).existsSync() ? row.localPath : null;
          }
          return null;
        },
        onPlayed: (videoId) {
          ref.read(appDatabaseProvider).tracksDao.touchLastPlayed(videoId);
        },
```

Add `touchLastPlayed` to `TracksDao`:

```dart
  Future<void> touchLastPlayed(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId)))
          .write(TracksCompanion(lastPlayedAt: Value(DateTime.now())));
```

(Add `import 'dart:io';` and the db_providers import to `audio_providers.dart`
as needed. Match the existing provider/construction style in that file.)

- [ ] **Step 5: Run tests**

Run: `cd app && fvm flutter test test/core/audio/local_source_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full app suite + analyze**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: all pass, analyze clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/audio/audio_handler.dart app/lib/core/audio/audio_providers.dart app/lib/core/db/daos/tracks_dao.dart app/test/core/audio/local_source_test.dart
git commit -m "feat(app): play downloaded tracks from local file"
```

---

## Part F — UI

### Task 14: Download status provider + enqueue helper

**Files:**
- Create: `app/lib/features/downloads/download_status_provider.dart`
- Test: `app/test/features/downloads/download_status_provider_test.dart`

> A `StreamProvider.family<String, String>` (videoId -> status string) so any
> widget can watch one track's download status reactively. Plus a small action
> object to enqueue a list of videoIds (used by album/playlist/track buttons).

- [ ] **Step 1: Write the failing test**

Create `app/test/features/downloads/download_status_provider_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/downloads/download_status_provider.dart';

void main() {
  test('downloadStatus emits the track status', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'a',
        title: 'a',
        downloadStatus: const Value('downloaded'),
      ),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final status =
        await container.read(downloadStatusProvider('a').future);
    expect(status, 'downloaded');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/features/downloads/download_status_provider_test.dart`
Expected: FAIL — provider missing.

- [ ] **Step 3: Implement**

Create `app/lib/features/downloads/download_status_provider.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';

/// Reactive download status for a single track ('not_downloaded', 'queued',
/// 'downloading', 'downloaded', 'failed').
final downloadStatusProvider =
    StreamProvider.family<String, String>((ref, videoId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.tracksDao.select(db.tracksDao.tracks)
    ..where((t) => t.videoId.equals(videoId));
  return query
      .watchSingleOrNull()
      .map((row) => row?.downloadStatus ?? 'not_downloaded');
});

/// Enqueue a set of tracks for download (pinned manual download).
final enqueueDownloadsProvider =
    Provider<Future<void> Function(List<String>)>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  final coordinator = ref.watch(downloadCoordinatorProvider);
  return (videoIds) async {
    await repo.enqueue(videoIds, pinned: true);
    await coordinator.processQueueOnce();
  };
});
```

> `db.tracksDao.tracks` / `.select(...)` access: if the DAO doesn't expose the
> table publicly, add a `watchStatus(videoId)` method to `TracksDao` returning
> `Stream<String>` and call that instead. Prefer the DAO method for cleanliness.

- [ ] **Step 4: Run test**

Run: `cd app && fvm flutter test test/features/downloads/download_status_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/downloads/download_status_provider.dart app/test/features/downloads/download_status_provider_test.dart
git commit -m "feat(app): download status provider + enqueue action"
```

---

### Task 15: DownloadButton widget

**Files:**
- Create: `app/lib/features/downloads/widgets/download_button.dart`
- Test: `app/test/features/downloads/download_button_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/downloads/download_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/features/downloads/download_status_provider.dart';
import 'package:ytmusic/features/downloads/widgets/download_button.dart';

void main() {
  testWidgets('shows download icon when not downloaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadStatusProvider('a')
              .overrideWith((ref) => Stream.value('not_downloaded')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadButton(videoIds: ['a'])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('shows check when downloaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadStatusProvider('a')
              .overrideWith((ref) => Stream.value('downloaded')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadButton(videoIds: ['a'])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/features/downloads/download_button_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement**

Create `app/lib/features/downloads/widgets/download_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/features/downloads/download_status_provider.dart';

/// A download control for one track (single videoId) or a collection
/// (album/playlist — all videoIds). Reflects the status of the *first* id for
/// the icon; tapping enqueues all ids.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({required this.videoIds, super.key});

  final List<String> videoIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstId = videoIds.isNotEmpty ? videoIds.first : '';
    final status = ref.watch(downloadStatusProvider(firstId));

    final statusStr = status.valueOrNull ?? 'not_downloaded';
    final enqueue = ref.read(enqueueDownloadsProvider);

    switch (statusStr) {
      case 'downloaded':
        return const IconButton(
          icon: Icon(Icons.download_done),
          onPressed: null,
          tooltip: 'Downloaded',
        );
      case 'queued':
      case 'downloading':
        return const IconButton(
          icon: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          onPressed: null,
          tooltip: 'Downloading…',
        );
      case 'failed':
        return IconButton(
          icon: const Icon(Icons.error_outline, color: Colors.redAccent),
          tooltip: 'Failed — tap to retry',
          onPressed: () => enqueue(videoIds),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: 'Download',
          onPressed: () => enqueue(videoIds),
        );
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test test/features/downloads/download_button_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/downloads/widgets/download_button.dart app/test/features/downloads/download_button_test.dart
git commit -m "feat(app): DownloadButton widget"
```

---

### Task 16: Downloads screen

**Files:**
- Create: `app/lib/features/downloads/downloads_screen.dart`
- Modify: `app/lib/routing/app_router.dart` (add `/downloads` route)
- Test: `app/test/features/downloads/downloads_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/downloads/downloads_screen_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/downloads/downloads_screen.dart';

void main() {
  testWidgets('lists downloaded tracks', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'a',
        title: 'Song A',
        downloadStatus: const Value('downloaded'),
        sizeBytes: const Value(1000000),
        downloadedAt: Value(DateTime(2026, 6, 13)),
      ),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Song A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && fvm flutter test test/features/downloads/downloads_screen_test.dart`
Expected: FAIL — screen missing.

- [ ] **Step 3: Implement the screen**

Create `app/lib/features/downloads/downloads_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';

final _downloadedProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloaded();
});

String _fmtBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) {
    return '${(bytes / (1024 * mb)).toStringAsFixed(2)} GB';
  }
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_downloadedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No downloads yet'));
          }
          final total =
              tracks.fold<int>(0, (sum, t) => sum + (t.sizeBytes ?? 0));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${tracks.length} tracks • ${_fmtBytes(total)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text(t.artistName ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove download',
                        onPressed: () => ref
                            .read(downloadRepositoryProvider)
                            .removeDownload(t.videoId),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route**

In `app/lib/routing/app_router.dart`, add a `GoRoute` for `/downloads` returning
`const DownloadsScreen()` (match the existing route-declaration style and import
the screen).

- [ ] **Step 5: Run tests**

Run: `cd app && fvm flutter test test/features/downloads/downloads_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/downloads/downloads_screen.dart app/lib/routing/app_router.dart app/test/features/downloads/downloads_screen_test.dart
git commit -m "feat(app): Downloads screen + route"
```

---

### Task 17: Wire DownloadButton into album, playlist, now-playing + library link

**Files:**
- Modify: `app/lib/features/album/...` (album detail screen — AppBar action)
- Modify: `app/lib/features/library/...` (playlist detail screen — AppBar action; library hub — Downloads entry)
- Modify: `app/lib/features/now_playing/...` (now-playing — download action for current track)

> These are small integration edits. For each screen, locate where it has the
> list of `Track`s (or `videoId`s) and add a `DownloadButton(videoIds: [...])`
> to the AppBar `actions:` (collections) or the track row (single track). Add
> the import:
> `import 'package:ytmusic/features/downloads/widgets/download_button.dart';`

- [ ] **Step 1: Album detail — download whole album**

In the album detail screen, in the `AppBar(actions: [...])`, add:

```dart
DownloadButton(videoIds: album.tracks.map((t) => t.videoId).toList()),
```

(Use the real field names from the album-detail model/screen.)

- [ ] **Step 2: Playlist detail — download whole playlist**

Same pattern in the playlist detail screen's AppBar actions, mapping the
playlist's tracks to their `videoId`s.

- [ ] **Step 3: Now-playing — download current track**

In the now-playing screen, add `DownloadButton(videoIds: [track.videoId])` near
the playback controls (single-track download), using the current track's id.

- [ ] **Step 4: Library hub — link to Downloads screen**

In the library hub screen, add a `ListTile`/entry:

```dart
ListTile(
  leading: const Icon(Icons.download_done),
  title: const Text('Downloads'),
  onTap: () => context.push('/downloads'),
),
```

- [ ] **Step 5: Analyze + full suite**

Run: `cd app && fvm flutter analyze && fvm flutter test`
Expected: analyze clean, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features
git commit -m "feat(app): wire download actions into album, playlist, now-playing, library"
```

---

## Part G — Verification & deploy

### Task 18: Full verification

- [ ] **Step 1: Backend suite**

Run: `cd backend && .venv/bin/pytest -q`
Expected: all pass.

- [ ] **Step 2: App suite + analyze**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: all pass, analyze clean.

- [ ] **Step 3: Manual smoke (simulator)**

Use the run skill / `fvm flutter run` on the iOS simulator. Verify: tapping
Download on a track shows progress → check; the Downloads screen lists it with a
size; killing & relaunching the app keeps the track downloaded; playing a
downloaded track works (ideally in airplane mode to confirm it's the local
file). Capture a screenshot of the Downloads screen.

- [ ] **Step 4: Deploy backend to VM 101**

Follow the existing redeploy flow (rebuild `yt-music-api` on VM 101 via the
compose file in `~/docker/yt-music-app/`). Then verify through CF Access:

```bash
curl -s -X POST \
  -H "CF-Access-Client-Id: $CFID" -H "CF-Access-Client-Secret: $CFSECRET" \
  -H 'Content-Type: application/json' \
  -d '{"videoIds":["<known-good-id>"],"codec":"aac"}' \
  https://ytmusic.richarddepierre.com/v1/downloads/manifest
```

Expected: 200 with one item carrying a `googlevideo.com` URL.

### Task 19: PRs + second-brain log

- [ ] **Step 1: Open PR(s)**

Push the branch and open a PR (backend + app together, or split if preferred).
PR body: no Claude co-author/footer trailer (per project CLAUDE.md).

- [ ] **Step 2: Update project notes + add a change log**

- Update `~/Documents/development-second-brain/.../Projects/yt-music.md`: mark
  Phase 5 status, add `/downloads/manifest` to the implemented endpoint list,
  note downloads in the Flutter feature list.
- Add `~/Documents/development-second-brain/.../yt-music-logs/2026-06-13-phase-5-downloads.md`
  (frontmatter `type: project-log`, `project: "[[yt-music]]"`, `date:`).

---

## Self-review notes

- **Spec coverage:** §6.2 manifest → Tasks 1–3. §5.3 state machine → DownloadsDao
  + coordinator (Tasks 9, 11). §5.4 on-disk layout → gateway target dir (Task 8).
  §5.5 eviction → repository `runEviction` (Task 10). §6.3 worker pipeline →
  coordinator (Task 11). §6.4 URL expiry → `urlExpired` event + re-resolve
  (Tasks 8, 11). §3 downloaded→local playback → Task 13. UI → Tasks 14–17.
- **Deferred (documented, not built here):** auto-sync (§6.5, Phase 6),
  Settings cap UI (Phase 7), retry exponential-backoff *timers* (attempts are
  counted and capped; long-delay scheduling is best-effort on next
  coordinator/queue tick).
- **Codec:** AAC/m4a chosen over the spec's opus default, to match the app's
  iOS-AVPlayer playback reality. Documented in the plan header.
- **Type consistency:** `DownloadEvent`/`DownloadEventKind`/`DownloadRequest`,
  `markDownloading/markDownloaded/markFailed/requeue/clearDownload`,
  `unpinnedDownloadedBytes`/`lruUnpinned`, `getManifest`,
  `downloadStatusProvider`/`enqueueDownloadsProvider` used consistently across
  tasks.
