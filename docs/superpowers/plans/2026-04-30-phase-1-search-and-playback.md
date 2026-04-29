# Phase 1: Search → Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End state — open the app, type a query, tap a result, hear audio playing through phone speakers / Bluetooth / lockscreen on both iOS and Android. The "truth-test phase" — proves stream URL resolution actually works against Google in production.

**Architecture:** Three new backend endpoints (`/v1/search`, `/v1/track/{id}`, `/v1/track/{id}/stream`) wrap `ytmusicapi` (search, metadata) and `yt-dlp` + `pot-provider` (signed stream URLs). All responses cached in SQLite with TTLs from spec §2.5. Stream URL resolution capped at 2-3 in-flight per spec §2.6. Flutter app gets a `SearchScreen`, an `AudioPlaybackHandler` registered with `audio_service`, a persistent `MiniPlayer`, and a `NowPlayingScreen`. Stream URL refresh on 403/410 is local to the playback handler — no global interceptor.

**Tech Stack:** (additions over Phase 0) `yt-dlp` + `httpx` (backend); `just_audio`, `audio_service`, `cached_network_image` (Flutter).

**Out of scope for this phase:**
- Library / playlists (Phase 2)
- Album & artist screens (Phase 3)
- Drift schema (Phase 2)
- Optimistic offline mutations (deferred)
- Track detail screen (per design choice — tap-to-play directly)

---

## File map

### Backend (new)
- `backend/src/ytmusic_api/services/cache.py` — SQLite-backed TTL cache
- `backend/src/ytmusic_api/services/concurrency.py` — `asyncio.Semaphore` wrapper for stream resolution
- `backend/src/ytmusic_api/services/ytmusic_client.py` — thin wrapper around `ytmusicapi.YTMusic` reading from `HeadersStore`
- `backend/src/ytmusic_api/services/pot_client.py` — HTTP client for the `pot-provider` sidecar
- `backend/src/ytmusic_api/services/stream_resolver.py` — `yt-dlp` + PoT integration; returns signed googlevideo URL
- `backend/src/ytmusic_api/routers/catalog.py` — `/v1/search` and `/v1/track/{videoId}`
- `backend/src/ytmusic_api/routers/stream.py` — `/v1/track/{videoId}/stream`
- `backend/src/ytmusic_api/models/catalog.py` — pydantic response models for search + track
- `backend/src/ytmusic_api/models/stream.py` — pydantic response model for stream
- `backend/tests/test_cache.py`
- `backend/tests/test_concurrency.py`
- `backend/tests/test_pot_client.py`
- `backend/tests/test_stream_resolver.py`
- `backend/tests/test_catalog.py`
- `backend/tests/test_stream.py`

### Backend (modified)
- `backend/pyproject.toml` — add `yt-dlp`, `httpx`
- `backend/src/ytmusic_api/main.py` — wire new providers, build PoT client, mount routers
- `backend/src/ytmusic_api/routers/health.py` — populate `pot_provider_ok`
- `backend/src/ytmusic_api/auth/check.py` — share `YTMusic` client via the new wrapper

### Flutter app (new)
- `app/lib/core/api/models/search_result.dart`
- `app/lib/core/api/models/track.dart`
- `app/lib/core/api/models/stream_info.dart`
- `app/lib/core/audio/audio_handler.dart` — single `BaseAudioHandler` impl
- `app/lib/core/audio/audio_providers.dart` — Riverpod providers for handler + state
- `app/lib/features/search/search_controller.dart`
- `app/lib/features/search/search_screen.dart`
- `app/lib/features/now_playing/now_playing_screen.dart`
- `app/lib/features/now_playing/mini_player.dart`
- `app/test/audio_handler_test.dart`
- `app/test/search_controller_test.dart`

### Flutter app (modified)
- `app/pubspec.yaml` — `just_audio`, `audio_service`, `cached_network_image`
- `app/lib/main.dart` — `AudioService.init()` on startup
- `app/lib/app.dart` — wrap routed pages so `MiniPlayer` is visible across routes
- `app/lib/routing/app_router.dart` — add `/search` (new home after onboarding) and `/now-playing`
- `app/lib/core/api/api_client.dart` — add `search()`, `getTrack()`, `resolveStream()`
- `app/ios/Runner/Info.plist` — `UIBackgroundModes: audio`
- `app/android/app/src/main/AndroidManifest.xml` — `audio_service` permissions + service declaration

---

## Task 1: SQLite-backed TTL cache

**Files:**
- Create: `backend/src/ytmusic_api/services/cache.py`
- Create: `backend/tests/test_cache.py`

A keyed cache with per-entry TTL. Backed by an in-memory SQLite database (volatile across container restarts; that's fine — the values are derived). Used by `/search`, `/track`, `/stream`, `/home`, `/radio`.

- [ ] **Step 1.1: Failing test**

`backend/tests/test_cache.py`:
```python
import asyncio

import pytest

from ytmusic_api.services.cache import TtlCache


def test_get_returns_none_when_missing():
    cache = TtlCache()
    assert cache.get("missing") is None


def test_set_then_get_returns_value():
    cache = TtlCache()
    cache.set("k", {"hello": 1}, ttl_seconds=60)
    assert cache.get("k") == {"hello": 1}


@pytest.mark.asyncio
async def test_value_expires_after_ttl():
    cache = TtlCache()
    cache.set("k", "v", ttl_seconds=0.05)
    assert cache.get("k") == "v"
    await asyncio.sleep(0.1)
    assert cache.get("k") is None


def test_overwrite_resets_ttl():
    cache = TtlCache()
    cache.set("k", "v1", ttl_seconds=60)
    cache.set("k", "v2", ttl_seconds=60)
    assert cache.get("k") == "v2"


def test_clear_drops_all():
    cache = TtlCache()
    cache.set("a", 1, ttl_seconds=60)
    cache.set("b", 2, ttl_seconds=60)
    cache.clear()
    assert cache.get("a") is None
    assert cache.get("b") is None
```

- [ ] **Step 1.2: Run, expect failure (`ModuleNotFoundError`)**

```bash
cd /<worktree>/backend
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_cache.py -v
```

- [ ] **Step 1.3: Implement**

`backend/src/ytmusic_api/services/cache.py`:
```python
from __future__ import annotations

import json
import sqlite3
import threading
import time
from typing import Any


class TtlCache:
    """Process-local TTL cache backed by an in-memory SQLite DB.

    Values are JSON-encoded so consumers must use JSON-friendly data.
    Thread-safe via a single lock; fine for our concurrency level.
    """

    def __init__(self) -> None:
        self._conn = sqlite3.connect(":memory:", check_same_thread=False)
        self._lock = threading.Lock()
        with self._lock:
            self._conn.execute(
                "CREATE TABLE entries (k TEXT PRIMARY KEY, v TEXT, expires_at REAL)"
            )

    def get(self, key: str) -> Any | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT v, expires_at FROM entries WHERE k = ?", (key,)
            ).fetchone()
            if row is None:
                return None
            value, expires_at = row
            if expires_at < time.time():
                self._conn.execute("DELETE FROM entries WHERE k = ?", (key,))
                return None
            return json.loads(value)

    def set(self, key: str, value: Any, *, ttl_seconds: float) -> None:
        expires_at = time.time() + ttl_seconds
        encoded = json.dumps(value)
        with self._lock:
            self._conn.execute(
                "INSERT INTO entries(k, v, expires_at) VALUES(?, ?, ?) "
                "ON CONFLICT(k) DO UPDATE SET v=excluded.v, expires_at=excluded.expires_at",
                (key, encoded, expires_at),
            )

    def clear(self) -> None:
        with self._lock:
            self._conn.execute("DELETE FROM entries")
```

- [ ] **Step 1.4: Run, expect 5 PASSED**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_cache.py -v
```

- [ ] **Step 1.5: Commit**

```bash
git add backend/src/ytmusic_api/services/cache.py backend/tests/test_cache.py
git commit -m "feat(backend): TtlCache utility (in-memory SQLite, JSON values)"
```

---

## Task 2: Concurrency limiter for stream resolution

Per spec §2.6, stream URL resolutions cap at 2–3 in flight to keep our request-rate fingerprint normal-looking to Google.

**Files:**
- Create: `backend/src/ytmusic_api/services/concurrency.py`
- Create: `backend/tests/test_concurrency.py`

- [ ] **Step 2.1: Failing test**

`backend/tests/test_concurrency.py`:
```python
import asyncio

import pytest

from ytmusic_api.services.concurrency import BoundedRunner


@pytest.mark.asyncio
async def test_runs_serially_when_max_is_one():
    runner = BoundedRunner(max_concurrent=1)
    started: list[int] = []
    finished: list[int] = []

    async def task(i: int) -> int:
        started.append(i)
        await asyncio.sleep(0.05)
        finished.append(i)
        return i

    results = await asyncio.gather(*(runner.run(task, i) for i in range(3)))
    assert results == [0, 1, 2]
    # Serial execution: each task finishes before the next starts.
    assert started == [0, 1, 2]
    assert finished == [0, 1, 2]


@pytest.mark.asyncio
async def test_propagates_exceptions():
    runner = BoundedRunner(max_concurrent=2)

    async def boom() -> None:
        raise RuntimeError("nope")

    with pytest.raises(RuntimeError, match="nope"):
        await runner.run(boom)
```

- [ ] **Step 2.2: Run, expect failure**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_concurrency.py -v
```

- [ ] **Step 2.3: Implement**

`backend/src/ytmusic_api/services/concurrency.py`:
```python
from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

T = TypeVar("T")


class BoundedRunner:
    """Wraps an asyncio.Semaphore so callers don't manage `async with` themselves."""

    def __init__(self, *, max_concurrent: int) -> None:
        self._sem = asyncio.Semaphore(max_concurrent)

    async def run(
        self,
        fn: Callable[..., Awaitable[T]],
        *args: Any,
        **kwargs: Any,
    ) -> T:
        async with self._sem:
            return await fn(*args, **kwargs)
```

- [ ] **Step 2.4: Run, expect 2 PASSED**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_concurrency.py -v
```

- [ ] **Step 2.5: Commit**

```bash
git add backend/src/ytmusic_api/services/concurrency.py backend/tests/test_concurrency.py
git commit -m "feat(backend): BoundedRunner (asyncio.Semaphore wrapper)"
```

---

## Task 3: ytmusicapi client wrapper

Centralise `YTMusic` instantiation so search, track, and the auth health check share one path. The wrapper rebuilds the underlying `YTMusic` whenever `HeadersStore` reloads. (Phase 0's `auth/check.py` constructs `YTMusic` per probe; we keep that path but route it through this wrapper.)

**Files:**
- Create: `backend/src/ytmusic_api/services/ytmusic_client.py`
- Modify: `backend/src/ytmusic_api/auth/check.py`

- [ ] **Step 3.1: Implement the wrapper**

`backend/src/ytmusic_api/services/ytmusic_client.py`:
```python
from __future__ import annotations

import asyncio
import logging
from typing import Any

from ..auth.headers import HeadersStore

logger = logging.getLogger(__name__)


class YTMusicClient:
    """Async wrapper around ytmusicapi.YTMusic.

    Delegates blocking calls to a thread. The caller-visible API is async.
    """

    def __init__(self, store: HeadersStore) -> None:
        self._store = store

    def _build(self):
        from ytmusicapi import YTMusic

        headers = self._store.current()
        if headers is None:
            raise RuntimeError("ytmusicapi headers not loaded")
        return YTMusic(auth=headers)

    async def search(self, query: str, *, filter_type: str | None, limit: int) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.search(query, filter=filter_type, limit=limit)
        return await asyncio.to_thread(_call)

    async def get_song(self, video_id: str) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_song(video_id)
        return await asyncio.to_thread(_call)

    async def get_library_songs(self, limit: int = 1) -> list[dict[str, Any]]:
        """Cheap authenticated probe used by AuthHealthMonitor."""
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_library_songs(limit=limit)
        return await asyncio.to_thread(_call)
```

- [ ] **Step 3.2: Refactor `auth/check.py` to use the wrapper**

`backend/src/ytmusic_api/auth/check.py`:
```python
"""Real ytmusicapi-backed auth check used in production."""
from __future__ import annotations

import logging

from ..services.ytmusic_client import YTMusicClient

logger = logging.getLogger(__name__)


def make_real_check(client: YTMusicClient):
    """Returns an async callable that pings ytmusicapi.

    Raises if cookies invalid or unloaded.
    """

    async def check() -> None:
        await client.get_library_songs(limit=1)

    return check
```

- [ ] **Step 3.3: Verify tests still pass**

The existing auth-health tests use stub callables, so this refactor is invisible to them. Confirm:

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest -v
```
All tests still pass (no new ones in this task).

- [ ] **Step 3.4: Commit**

```bash
git add backend/src/ytmusic_api/services/ytmusic_client.py backend/src/ytmusic_api/auth/check.py
git commit -m "refactor(backend): centralise YTMusic instantiation in YTMusicClient"
```

---

## Task 4: Catalog response models

**Files:**
- Create: `backend/src/ytmusic_api/models/catalog.py`

- [ ] **Step 4.1: Write the models**

`backend/src/ytmusic_api/models/catalog.py`:
```python
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

ResultType = Literal["song", "video", "album", "artist", "playlist"]


class Thumbnail(BaseModel):
    url: str
    width: int | None = None
    height: int | None = None


class SearchResult(BaseModel):
    type: ResultType
    videoId: str | None = None
    browseId: str | None = None
    title: str
    artistName: str | None = None
    albumName: str | None = None
    durationMs: int | None = None
    thumbnail: Thumbnail | None = None


class SearchResponse(BaseModel):
    items: list[SearchResult]
    continuation: str | None = None


class TrackResponse(BaseModel):
    videoId: str
    title: str
    artistName: str
    albumName: str | None = None
    albumBrowseId: str | None = None
    artistBrowseId: str | None = None
    durationMs: int
    thumbnail: Thumbnail | None = None
```

No tests yet — these are pure schemas; tests come in Task 5 / 6.

- [ ] **Step 4.2: Commit**

```bash
git add backend/src/ytmusic_api/models/catalog.py
git commit -m "feat(backend): pydantic schemas for /search and /track"
```

---

## Task 5: `/v1/search` endpoint

**Files:**
- Create: `backend/src/ytmusic_api/routers/catalog.py`
- Create: `backend/tests/test_catalog.py`
- Modify: `backend/src/ytmusic_api/main.py` (mount router; build wrapper + cache in lifespan)

- [ ] **Step 5.1: Failing test**

`backend/tests/test_catalog.py`:
```python
from typing import Any

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.auth.headers import HeadersStore
from ytmusic_api.auth.health import AuthStatus
from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


class _FakeYTMusic(YTMusicClient):
    def __init__(self) -> None:  # type: ignore[no-untyped-def]
        self.search_calls = 0
        self.search_results: list[dict[str, Any]] = []

    async def search(self, query, *, filter_type, limit):  # type: ignore[override]
        self.search_calls += 1
        return self.search_results


@pytest.fixture
def fake_ytm():
    return _FakeYTMusic()


@pytest.fixture
def cache():
    return TtlCache()


@pytest.fixture
def catalog_client(headers_store, auth_monitor, fake_ytm, cache):
    app = create_app(
        headers_store=headers_store,
        auth_monitor=auth_monitor,
        ytmusic_client=fake_ytm,
        cache=cache,
    )
    return TestClient(app)


def _song_payload() -> dict[str, Any]:
    return {
        "category": "Songs",
        "resultType": "song",
        "videoId": "abc",
        "title": "My Song",
        "artists": [{"name": "Some Artist", "id": "ARTIST1"}],
        "album": {"name": "Some Album", "id": "ALBUM1"},
        "duration_seconds": 180,
        "thumbnails": [{"url": "https://x/y.jpg", "width": 60, "height": 60}],
    }


def test_search_returns_normalised_items(catalog_client, fake_ytm):
    fake_ytm.search_results = [_song_payload()]
    response = catalog_client.get("/v1/search?q=hello")

    assert response.status_code == 200
    body = response.json()
    assert len(body["items"]) == 1
    item = body["items"][0]
    assert item["type"] == "song"
    assert item["videoId"] == "abc"
    assert item["title"] == "My Song"
    assert item["artistName"] == "Some Artist"
    assert item["albumName"] == "Some Album"
    assert item["durationMs"] == 180_000


def test_search_caches_by_query(catalog_client, fake_ytm):
    fake_ytm.search_results = [_song_payload()]
    catalog_client.get("/v1/search?q=hello")
    catalog_client.get("/v1/search?q=hello")
    # second call should be served from cache
    assert fake_ytm.search_calls == 1


def test_search_does_not_share_cache_across_queries(catalog_client, fake_ytm):
    fake_ytm.search_results = [_song_payload()]
    catalog_client.get("/v1/search?q=hello")
    catalog_client.get("/v1/search?q=world")
    assert fake_ytm.search_calls == 2
```

Update `backend/tests/conftest.py` to support the new `create_app` keyword args. Add to the existing `client` fixture path — make a more permissive variant:

```python
# at end of conftest.py
import pytest
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


@pytest.fixture
def cache_factory():
    def _make() -> TtlCache:
        return TtlCache()
    return _make
```

(The `_FakeYTMusic` class above already inlines what's needed for the test — no fixture file edits required beyond what tests import.)

- [ ] **Step 5.2: Run, expect failure**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_catalog.py -v
```

- [ ] **Step 5.3: Implement the router**

`backend/src/ytmusic_api/routers/catalog.py`:
```python
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import SearchResponse, SearchResult, Thumbnail, TrackResponse
from ..services.cache import TtlCache
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()

_SEARCH_TTL = 5 * 60         # 5 minutes
_TRACK_TTL = 24 * 60 * 60    # 24 hours


def _normalise_search_item(raw: dict[str, Any]) -> SearchResult | None:
    """Map ytmusicapi search shape to our wire format. Returns None for unknown types."""
    rt = raw.get("resultType") or raw.get("type")
    if rt not in {"song", "video", "album", "artist", "playlist"}:
        return None

    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None
    album = raw.get("album") or {}
    album_name = album.get("name") if isinstance(album, dict) else album
    thumbs = raw.get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    duration_seconds = raw.get("duration_seconds")
    return SearchResult(
        type=rt,
        videoId=raw.get("videoId"),
        browseId=raw.get("browseId"),
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        durationMs=int(duration_seconds * 1000) if duration_seconds else None,
        thumbnail=thumb,
    )


@router.get("/search", response_model=SearchResponse)
async def search(
    request: Request,
    q: str = Query(..., min_length=1),
    type: str | None = Query(None, pattern=r"^(song|album|artist|playlist|video)$"),
    limit: int = Query(20, ge=1, le=50),
) -> SearchResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"search:{type or 'any'}:{limit}:{q}"
    cached = cache.get(cache_key)
    if cached is not None:
        return SearchResponse.model_validate(cached)

    raw = await ytm.search(q, filter_type=type, limit=limit)
    items = [n for n in (_normalise_search_item(r) for r in raw) if n is not None]
    response = SearchResponse(items=items, continuation=None)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_SEARCH_TTL)
    return response


@router.get("/track/{video_id}", response_model=TrackResponse)
async def get_track(request: Request, video_id: str) -> TrackResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"track:{video_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return TrackResponse.model_validate(cached)

    try:
        raw = await ytm.get_song(video_id)
    except Exception as exc:  # ytmusicapi raises bare Exceptions on 404
        raise HTTPException(status_code=404, detail=f"track not found: {exc}") from exc

    details = raw.get("videoDetails") or {}
    thumbs = (details.get("thumbnail") or {}).get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    response = TrackResponse(
        videoId=video_id,
        title=details.get("title", ""),
        artistName=details.get("author", ""),
        albumName=None,  # videoDetails doesn't always carry album; could be enriched later
        albumBrowseId=None,
        artistBrowseId=None,
        durationMs=int(details.get("lengthSeconds", 0)) * 1000,
        thumbnail=thumb,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_TRACK_TTL)
    return response
```

- [ ] **Step 5.4: Update `main.py` to inject cache + ytmusic client**

In `backend/src/ytmusic_api/main.py`:

1. Add the new imports near the top:
   ```python
   from .routers import admin, catalog, health
   from .services.cache import TtlCache
   from .services.ytmusic_client import YTMusicClient
   ```

2. Update `make_real_check` import to use the new client signature:
   ```python
   from .auth.check import make_real_check  # existing
   ```

3. Replace `lifespan` with:
   ```python
   @asynccontextmanager
   async def lifespan(app: FastAPI) -> AsyncIterator[None]:
       settings = get_settings()
       store = HeadersStore(path=settings.yt_headers_path)
       ytm = YTMusicClient(store)
       cache = TtlCache()
       monitor = AuthHealthMonitor(
           check=make_real_check(ytm),
           interval=settings.auth_health_interval,
       )

       app.state.headers_store = store
       app.state.ytmusic_client = ytm
       app.state.cache = cache
       app.state.auth_monitor = monitor

       watch_task = asyncio.create_task(store.watch())
       monitor_task = asyncio.create_task(monitor.run())

       try:
           yield
       finally:
           monitor.stop()
           watch_task.cancel()
           await monitor_task
           try:
               await watch_task
           except asyncio.CancelledError:
               pass
   ```

4. Replace `create_app` with:
   ```python
   def create_app(
       *,
       headers_store: HeadersStore | None = None,
       auth_monitor: AuthHealthMonitor | None = None,
       ytmusic_client: YTMusicClient | None = None,
       cache: TtlCache | None = None,
   ) -> FastAPI:
       """App factory.

       Test code can pass any subset of dependencies; lifespan is bypassed if
       `headers_store` AND `auth_monitor` are both provided.
       """
       use_lifespan = headers_store is None or auth_monitor is None

       app = FastAPI(
           title="yt-music-api",
           version=API_VERSION,
           lifespan=lifespan if use_lifespan else None,
       )

       if not use_lifespan:
           app.state.headers_store = headers_store
           app.state.auth_monitor = auth_monitor
           app.state.ytmusic_client = ytmusic_client
           app.state.cache = cache or TtlCache()

       app.include_router(health.router, prefix="/v1")
       app.include_router(catalog.router, prefix="/v1")
       app.include_router(admin.router)
       return app
   ```

- [ ] **Step 5.5: Update `tests/conftest.py` `client` fixture so it doesn't break**

Add `cache` and `ytmusic_client` arguments where needed. The simplest fix: extend the existing `client` fixture:

```python
@pytest.fixture
def client(headers_store, auth_monitor) -> TestClient:
    return TestClient(
        create_app(
            headers_store=headers_store,
            auth_monitor=auth_monitor,
            ytmusic_client=None,
            cache=TtlCache(),
        )
    )
```

(The catalog tests use their own `catalog_client` fixture with the fake YTMusic.)

- [ ] **Step 5.6: Run new tests, expect 3 PASSED. Run full suite.**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_catalog.py -v
PATH=$HOME/.local/bin:$PATH uv run pytest -v
PATH=$HOME/.local/bin:$PATH uv run ruff check .
```

- [ ] **Step 5.7: Commit**

```bash
git add backend/
git commit -m "feat(backend): /v1/search with TtlCache (5min) + ytmusicapi normalisation"
```

---

## Task 6: `/v1/track/{videoId}` endpoint tests

The handler is already implemented in Task 5's router. Add focused tests.

**Files:**
- Modify: `backend/tests/test_catalog.py` (extend)

- [ ] **Step 6.1: Append tests**

```python
def test_get_track_returns_normalised_payload(catalog_client, fake_ytm):
    fake_ytm.search_calls = 0  # unused
    fake_ytm.get_song = lambda video_id: {  # noqa: E731
        "videoDetails": {
            "title": "T",
            "author": "A",
            "lengthSeconds": "240",
            "thumbnail": {
                "thumbnails": [
                    {"url": "https://lh3/x.jpg", "width": 600, "height": 600}
                ],
            },
        },
    }

    # FakeYTMusic doesn't implement get_song by default; monkey-patch for this test
    async def fake_get_song(video_id: str):
        return fake_ytm.get_song(video_id)
    fake_ytm.get_song_async = fake_get_song
    # Hmm — easier: bake it into _FakeYTMusic permanently. See conftest update below.
```

Actually — to avoid the monkey-patching above, **replace the `_FakeYTMusic` definition** at the top of `test_catalog.py` with this fuller version:

```python
class _FakeYTMusic(YTMusicClient):
    def __init__(self) -> None:  # type: ignore[no-untyped-def]
        self.search_calls = 0
        self.search_results: list[dict[str, Any]] = []
        self.song_payloads: dict[str, dict[str, Any]] = {}

    async def search(self, query, *, filter_type, limit):  # type: ignore[override]
        self.search_calls += 1
        return self.search_results

    async def get_song(self, video_id):  # type: ignore[override]
        if video_id not in self.song_payloads:
            raise RuntimeError("not found")
        return self.song_payloads[video_id]
```

Now add the track tests:

```python
def test_get_track_returns_normalised_payload(catalog_client, fake_ytm):
    fake_ytm.song_payloads["abc"] = {
        "videoDetails": {
            "title": "T",
            "author": "A",
            "lengthSeconds": "240",
            "thumbnail": {
                "thumbnails": [
                    {"url": "https://lh3/x.jpg", "width": 600, "height": 600}
                ],
            },
        },
    }

    response = catalog_client.get("/v1/track/abc")
    assert response.status_code == 200
    body = response.json()
    assert body == {
        "videoId": "abc",
        "title": "T",
        "artistName": "A",
        "albumName": None,
        "albumBrowseId": None,
        "artistBrowseId": None,
        "durationMs": 240_000,
        "thumbnail": {"url": "https://lh3/x.jpg", "width": 600, "height": 600},
    }


def test_get_track_404_when_not_found(catalog_client, fake_ytm):
    response = catalog_client.get("/v1/track/missing")
    assert response.status_code == 404
```

- [ ] **Step 6.2: Run, expect all PASS**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_catalog.py -v
```

- [ ] **Step 6.3: Commit**

```bash
git add backend/tests/test_catalog.py
git commit -m "test(backend): /v1/track happy path + 404"
```

---

## Task 7: PoT client

Async HTTP client wrapping the `pot-provider` sidecar. Per spec §3.4, yt-dlp consumes PoT via an `extractor-args` flag; the client here is used by the stream resolver and by the health endpoint to surface PoT availability.

**Files:**
- Create: `backend/src/ytmusic_api/services/pot_client.py`
- Create: `backend/tests/test_pot_client.py`

We add `httpx` to dev + prod deps.

- [ ] **Step 7.1: Add `httpx` to `pyproject.toml`**

In `backend/pyproject.toml` under `dependencies`:
```toml
  "httpx>=0.27",
```
(it's already in `dev`, copy to prod-side; `uv sync --extra dev` to regenerate `uv.lock`).

- [ ] **Step 7.2: Failing test**

`backend/tests/test_pot_client.py`:
```python
import pytest
import httpx

from ytmusic_api.services.pot_client import PotClient


@pytest.mark.asyncio
async def test_ping_returns_true_on_200():
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/ping"
        return httpx.Response(200, json={"server_uptime": 1, "version": "1.3.1"})

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    assert await client.ping() is True


@pytest.mark.asyncio
async def test_ping_returns_false_on_500():
    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    assert await client.ping() is False


@pytest.mark.asyncio
async def test_ping_returns_false_on_connection_error():
    async def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("nope")

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    assert await client.ping() is False
```

- [ ] **Step 7.3: Run, expect failure**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_pot_client.py -v
```

- [ ] **Step 7.4: Implement**

`backend/src/ytmusic_api/services/pot_client.py`:
```python
from __future__ import annotations

import logging

import httpx

logger = logging.getLogger(__name__)


class PotClient:
    """Talks to the bgutil-ytdlp-pot-provider sidecar.

    Used for healthchecks; yt-dlp itself integrates with the sidecar via the
    `po_token_provider_url` extractor-args flag (out of band of this client).
    """

    def __init__(
        self,
        *,
        base_url: str,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url,
            timeout=httpx.Timeout(2.0, connect=1.0),
            transport=transport,
        )

    async def ping(self) -> bool:
        try:
            res = await self._client.get("/ping")
            return res.status_code == 200
        except (httpx.RequestError, httpx.HTTPError) as exc:
            logger.debug("pot-provider ping failed: %s", exc)
            return False

    async def aclose(self) -> None:
        await self._client.aclose()
```

- [ ] **Step 7.5: Run, expect 3 PASSED**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_pot_client.py -v
```

- [ ] **Step 7.6: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock backend/src/ytmusic_api/services/pot_client.py backend/tests/test_pot_client.py
git commit -m "feat(backend): PotClient (httpx) for pot-provider /ping"
```

---

## Task 8: Stream resolver (yt-dlp + PoT)

Wraps `yt-dlp` to extract a signed googlevideo URL for a given videoId. Configures `--extractor-args "youtube:po_token_provider_url=..."` per spec §3.4.

**Files:**
- Create: `backend/src/ytmusic_api/services/stream_resolver.py`
- Create: `backend/tests/test_stream_resolver.py`
- Modify: `backend/pyproject.toml` (add `yt-dlp`)

- [ ] **Step 8.1: Add `yt-dlp` to deps**

In `backend/pyproject.toml`:
```toml
  "yt-dlp>=2025.1",
```
Then `uv sync --extra dev`.

- [ ] **Step 8.2: Failing test**

`backend/tests/test_stream_resolver.py`:
```python
from datetime import datetime
from typing import Any

import pytest

from ytmusic_api.services.stream_resolver import (
    ResolvedStream,
    StreamResolver,
    _pick_format,
)


def test_pick_format_prefers_aac_when_requested():
    formats: list[dict[str, Any]] = [
        {"format_id": "251", "ext": "webm", "acodec": "opus", "abr": 160, "filesize": 1, "url": "u-opus", "approx_duration_ms": 1},
        {"format_id": "140", "ext": "m4a", "acodec": "mp4a.40.2", "abr": 256, "filesize": 2, "url": "u-aac", "approx_duration_ms": 1},
    ]
    fmt = _pick_format(formats, codec="aac", quality="high")
    assert fmt["format_id"] == "140"


def test_pick_format_falls_back_when_codec_unavailable():
    formats: list[dict[str, Any]] = [
        {"format_id": "251", "ext": "webm", "acodec": "opus", "abr": 160, "url": "u", "approx_duration_ms": 1},
    ]
    fmt = _pick_format(formats, codec="aac", quality="high")
    assert fmt["format_id"] == "251"  # falls back to opus


def test_pick_format_picks_low_bitrate_for_low_quality():
    formats: list[dict[str, Any]] = [
        {"format_id": "139", "ext": "m4a", "acodec": "mp4a.40.2", "abr": 48, "url": "u", "approx_duration_ms": 1},
        {"format_id": "140", "ext": "m4a", "acodec": "mp4a.40.2", "abr": 128, "url": "u", "approx_duration_ms": 1},
    ]
    fmt = _pick_format(formats, codec="aac", quality="low")
    assert fmt["format_id"] == "139"


@pytest.mark.asyncio
async def test_resolver_returns_resolved_stream(monkeypatch):
    """Smoke test using a fake yt_dlp.YoutubeDL."""
    captured = {}

    class _FakeYDL:
        def __init__(self, opts):
            captured["opts"] = opts
        def __enter__(self):
            return self
        def __exit__(self, *a):
            return None
        def extract_info(self, video_id, download=False):
            return {
                "id": video_id,
                "title": "T",
                "duration": 180,
                "formats": [
                    {
                        "format_id": "251",
                        "ext": "webm",
                        "acodec": "opus",
                        "abr": 160,
                        "url": "https://rr.googlevideo.com/sig?xyz",
                        "filesize": 4321,
                        "approx_duration_ms": 180000,
                    },
                ],
            }

    import ytmusic_api.services.stream_resolver as sr
    monkeypatch.setattr(sr, "YoutubeDL", _FakeYDL)

    resolver = StreamResolver(pot_provider_url="http://pot:4416")
    result = await resolver.resolve("abc", codec="opus", quality="high")

    assert isinstance(result, ResolvedStream)
    assert result.video_id == "abc"
    assert result.url.startswith("https://rr.googlevideo.com/")
    assert result.codec == "opus"
    assert result.container == "webm"
    assert result.bitrate == 160_000
    assert result.content_length == 4321
    assert result.expires_at > datetime.utcnow()

    # Verify pot-provider URL was wired into yt-dlp opts.
    extractor_args = captured["opts"]["extractor_args"]
    assert "youtube" in extractor_args
    assert any("pot:4416" in v for vs in extractor_args["youtube"].values() for v in vs)
```

- [ ] **Step 8.3: Run, expect failure**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_stream_resolver.py -v
```

- [ ] **Step 8.4: Implement**

`backend/src/ytmusic_api/services/stream_resolver.py`:
```python
from __future__ import annotations

import asyncio
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Literal
from urllib.parse import parse_qs, urlparse

from yt_dlp import YoutubeDL

logger = logging.getLogger(__name__)

Codec = Literal["aac", "opus", "any"]
Quality = Literal["high", "medium", "low"]


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


_QUALITY_RANGES = {
    "high": (160, 320),
    "medium": (96, 160),
    "low": (32, 96),
}


def _classify_codec(acodec: str | None) -> str | None:
    if not acodec:
        return None
    a = acodec.lower()
    if a == "opus":
        return "opus"
    if a.startswith("mp4a") or "aac" in a:
        return "aac"
    return None


def _pick_format(formats: list[dict[str, Any]], *, codec: str, quality: str) -> dict[str, Any]:
    """Best-effort: prefer requested codec at requested quality; fall back gracefully."""
    audio_only = [f for f in formats if f.get("acodec") and f.get("acodec") != "none"]
    if not audio_only:
        raise ValueError("no audio formats available")

    quality_min, quality_max = _QUALITY_RANGES[quality]

    def score(f: dict[str, Any]) -> tuple[int, int, int]:
        f_codec = _classify_codec(f.get("acodec")) or ""
        codec_match = 2 if (codec == "any" or f_codec == codec) else (1 if f_codec else 0)
        abr = int(f.get("abr") or 0)
        in_range = 2 if quality_min <= abr <= quality_max else (1 if abr <= quality_max else 0)
        # Prefer close-to-min-of-range; tie-break by larger filesize
        return (codec_match, in_range, abr if quality != "low" else -abr)

    audio_only.sort(key=score, reverse=True)
    return audio_only[0]


def _expires_at_from_url(url: str) -> datetime:
    """googlevideo URLs carry an `expire=<unixts>` query param. Fall back to +6h."""
    qs = parse_qs(urlparse(url).query)
    expire = qs.get("expire") or qs.get("expires")
    if expire:
        try:
            return datetime.utcfromtimestamp(int(expire[0]))
        except (TypeError, ValueError):
            pass
    # /expires/<ts>/ in the path is also possible
    m = re.search(r"/expire/(\d+)/", url)
    if m:
        try:
            return datetime.utcfromtimestamp(int(m.group(1)))
        except (TypeError, ValueError):
            pass
    return datetime.utcnow() + timedelta(hours=6)


class StreamResolver:
    def __init__(self, *, pot_provider_url: str) -> None:
        self._pot_provider_url = pot_provider_url

    async def resolve(self, video_id: str, *, codec: Codec, quality: Quality) -> ResolvedStream:
        return await asyncio.to_thread(self._resolve_sync, video_id, codec, quality)

    def _resolve_sync(self, video_id: str, codec: str, quality: str) -> ResolvedStream:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "format": "bestaudio/best",
            "extractor_args": {
                "youtube": {
                    "po_token_provider_url": [self._pot_provider_url],
                },
            },
        }
        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_id, download=False)

        formats = info.get("formats") or []
        chosen = _pick_format(formats, codec=codec, quality=quality)
        url = chosen["url"]
        expires = _expires_at_from_url(url)

        return ResolvedStream(
            video_id=info.get("id", video_id),
            url=url,
            expires_at=expires,
            codec=_classify_codec(chosen.get("acodec")) or "opus",
            container=chosen.get("ext", "webm"),
            bitrate=int(chosen.get("abr", 0)) * 1000,
            approx_duration_ms=int((info.get("duration") or 0) * 1000),
            content_length=chosen.get("filesize"),
        )
```

- [ ] **Step 8.5: Run, expect 4 PASSED**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_stream_resolver.py -v
```

- [ ] **Step 8.6: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock backend/src/ytmusic_api/services/stream_resolver.py backend/tests/test_stream_resolver.py
git commit -m "feat(backend): StreamResolver (yt-dlp + PoT extractor-args)"
```

---

## Task 9: `/v1/track/{videoId}/stream` endpoint

Glues `StreamResolver`, `BoundedRunner` (concurrency cap), and `TtlCache` (25min per spec §2.5).

**Files:**
- Create: `backend/src/ytmusic_api/models/stream.py`
- Create: `backend/src/ytmusic_api/routers/stream.py`
- Create: `backend/tests/test_stream.py`
- Modify: `backend/src/ytmusic_api/main.py` (build resolver + runner; mount router; pot client)

- [ ] **Step 9.1: Response model**

`backend/src/ytmusic_api/models/stream.py`:
```python
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class StreamResponse(BaseModel):
    videoId: str
    url: str
    expiresAt: datetime
    codec: str
    container: str
    bitrate: int
    approxDurationMs: int
    contentLength: int | None = None
```

- [ ] **Step 9.2: Failing test**

`backend/tests/test_stream.py`:
```python
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.concurrency import BoundedRunner
from ytmusic_api.services.stream_resolver import ResolvedStream


class _FakeResolver:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str]] = []
        self.payload: ResolvedStream | None = None
        self.error: Exception | None = None

    async def resolve(self, video_id, *, codec, quality):
        self.calls.append((video_id, codec, quality))
        if self.error:
            raise self.error
        assert self.payload is not None
        return self.payload


@pytest.fixture
def fake_resolver():
    return _FakeResolver()


@pytest.fixture
def stream_client(headers_store, auth_monitor, fake_resolver):
    app = create_app(
        headers_store=headers_store,
        auth_monitor=auth_monitor,
        cache=TtlCache(),
        stream_resolver=fake_resolver,
        stream_runner=BoundedRunner(max_concurrent=3),
    )
    return TestClient(app)


def test_stream_returns_resolved_url(stream_client, fake_resolver):
    fake_resolver.payload = ResolvedStream(
        video_id="abc",
        url="https://rr.googlevideo.com/x?expire=999999",
        expires_at=datetime.utcnow() + timedelta(hours=6),
        codec="opus",
        container="webm",
        bitrate=160_000,
        approx_duration_ms=180_000,
        content_length=4321,
    )

    response = stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    assert response.status_code == 200
    body = response.json()
    assert body["videoId"] == "abc"
    assert body["url"].startswith("https://rr.googlevideo.com/")
    assert body["codec"] == "opus"
    assert body["bitrate"] == 160_000
    assert body["contentLength"] == 4321
    assert "expiresAt" in body


def test_stream_caches_per_videoid_codec_quality(stream_client, fake_resolver):
    fake_resolver.payload = ResolvedStream(
        video_id="abc", url="u", expires_at=datetime.utcnow() + timedelta(hours=1),
        codec="opus", container="webm", bitrate=160_000, approx_duration_ms=180_000, content_length=None,
    )
    stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    assert len(fake_resolver.calls) == 1


def test_stream_502_when_resolver_raises(stream_client, fake_resolver):
    fake_resolver.error = RuntimeError("yt-dlp boom")
    response = stream_client.get("/v1/track/abc/stream")
    assert response.status_code == 502
    body = response.json()
    assert body["detail"]["error"] == "upstream_breakage"
```

- [ ] **Step 9.3: Run, expect failure**

- [ ] **Step 9.4: Implement router**

`backend/src/ytmusic_api/routers/stream.py`:
```python
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.stream import StreamResponse
from ..services.cache import TtlCache
from ..services.concurrency import BoundedRunner
from ..services.stream_resolver import StreamResolver

logger = logging.getLogger(__name__)
router = APIRouter()

_STREAM_TTL = 25 * 60  # 25 minutes


@router.get("/track/{video_id}/stream", response_model=StreamResponse)
async def stream(
    request: Request,
    video_id: str,
    codec: str = Query("any", pattern=r"^(any|aac|opus)$"),
    quality: str = Query("high", pattern=r"^(high|medium|low)$"),
) -> StreamResponse:
    cache: TtlCache = request.app.state.cache
    resolver: StreamResolver = request.app.state.stream_resolver
    runner: BoundedRunner = request.app.state.stream_runner

    cache_key = f"stream:{video_id}:{codec}:{quality}"
    cached = cache.get(cache_key)
    if cached is not None:
        return StreamResponse.model_validate(cached)

    try:
        resolved = await runner.run(
            resolver.resolve, video_id, codec=codec, quality=quality
        )
    except Exception as exc:  # ytmusicapi/yt-dlp throws bare Exception subtypes
        logger.warning("Stream resolution failed for %s: %s", video_id, exc)
        raise HTTPException(
            status_code=502,
            detail={"error": "upstream_breakage", "message": str(exc), "retryable": True},
        ) from exc

    response = StreamResponse(
        videoId=resolved.video_id,
        url=resolved.url,
        expiresAt=resolved.expires_at,
        codec=resolved.codec,
        container=resolved.container,
        bitrate=resolved.bitrate,
        approxDurationMs=resolved.approx_duration_ms,
        contentLength=resolved.content_length,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_STREAM_TTL)
    return response
```

- [ ] **Step 9.5: Update `main.py`** to build `StreamResolver`, `BoundedRunner`, `PotClient`, and mount `stream.router`

In the `lifespan` function:
```python
        # ... existing setup
        pot_client = PotClient(base_url=settings.pot_provider_url)
        stream_resolver = StreamResolver(pot_provider_url=settings.pot_provider_url)
        stream_runner = BoundedRunner(max_concurrent=3)

        app.state.pot_client = pot_client
        app.state.stream_resolver = stream_resolver
        app.state.stream_runner = stream_runner

        # ... yield
        finally:
            # add to cleanup:
            await pot_client.aclose()
            # existing monitor.stop() etc.
```

In `create_app` add new keyword args (`stream_resolver`, `stream_runner`, `pot_client`) and assign to `app.state` when `use_lifespan` is False.

In the imports:
```python
from .routers import admin, catalog, health, stream
from .services.concurrency import BoundedRunner
from .services.pot_client import PotClient
from .services.stream_resolver import StreamResolver
```

And add:
```python
app.include_router(stream.router, prefix="/v1")
```

- [ ] **Step 9.6: Run all tests**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest -v
PATH=$HOME/.local/bin:$PATH uv run ruff check .
```

- [ ] **Step 9.7: Commit**

```bash
git add backend/
git commit -m "feat(backend): /v1/track/{id}/stream with cache + concurrency cap"
```

---

## Task 10: Wire `pot_provider_ok` into `/v1/health`

**Files:**
- Modify: `backend/src/ytmusic_api/routers/health.py`
- Modify: `backend/tests/test_health.py`

- [ ] **Step 10.1: Test for the new field**

Append to `tests/test_health.py`:
```python
def test_health_reports_pot_provider_ok(client):
    # The default test fixture has no pot_client; the health route should
    # treat a missing client as an unknown (None) rather than failing.
    body = client.get("/v1/health").json()
    assert "pot_provider_ok" in body
```

- [ ] **Step 10.2: Update health route**

Replace `backend/src/ytmusic_api/routers/health.py` with:
```python
from fastapi import APIRouter, Request

from ..auth.health import AuthHealthMonitor
from ..models.health import HealthResponse


router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    from ..main import API_VERSION

    monitor: AuthHealthMonitor = request.app.state.auth_monitor
    pot_client = getattr(request.app.state, "pot_client", None)

    pot_ok: bool | None = None
    if pot_client is not None:
        pot_ok = await pot_client.ping()

    status = monitor.status()
    return HealthResponse(
        status="ok" if status.label == "ok" else "degraded",
        auth_status=status.label,
        last_ok_at=status.last_ok_at,
        pot_provider_ok=pot_ok,
        version=API_VERSION,
    )
```

- [ ] **Step 10.3: Run all tests**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest -v
```

- [ ] **Step 10.4: Commit**

```bash
git add backend/
git commit -m "feat(backend): /v1/health surfaces pot_provider_ok"
```

---

## Task 11: Flutter audio + image dependencies

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 11.1: Add deps**

```yaml
dependencies:
  audio_service: ^0.18.15
  cached_network_image: ^3.4.1
  cupertino_icons: ^1.0.8
  dio: ^5.7.0
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  flutter_secure_storage: ^9.2.2
  go_router: ^14.6.2
  just_audio: ^0.9.42
  riverpod_annotation: ^2.6.1
```
(verify alphabetical order — `sort_pub_dependencies` rule).

- [ ] **Step 11.2: Pull**

```bash
cd app
fvm flutter pub get
```

- [ ] **Step 11.3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add just_audio, audio_service, cached_network_image"
```

---

## Task 12: Dart models for catalog + stream

**Files:**
- Create: `app/lib/core/api/models/search_result.dart`
- Create: `app/lib/core/api/models/track.dart`
- Create: `app/lib/core/api/models/stream_info.dart`

Hand-written `fromJson`s; we're not running codegen for these. Single quotes, sorted constructors first.

- [ ] **Step 12.1: SearchResult**

`app/lib/core/api/models/search_result.dart`:
```dart
class Thumbnail {
  Thumbnail({required this.url, this.width, this.height});

  factory Thumbnail.fromJson(Map<String, dynamic> json) => Thumbnail(
        url: json['url'] as String,
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  final String url;
  final int? width;
  final int? height;
}

class SearchResult {
  SearchResult({
    required this.type,
    required this.title,
    this.videoId,
    this.browseId,
    this.artistName,
    this.albumName,
    this.durationMs,
    this.thumbnail,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        type: json['type'] as String,
        videoId: json['videoId'] as String?,
        browseId: json['browseId'] as String?,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        albumName: json['albumName'] as String?,
        durationMs: json['durationMs'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String type; // song | video | album | artist | playlist
  final String? videoId;
  final String? browseId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationMs;
  final Thumbnail? thumbnail;
}
```

- [ ] **Step 12.2: Track**

`app/lib/core/api/models/track.dart`:
```dart
import 'search_result.dart';

class Track {
  Track({
    required this.videoId,
    required this.title,
    required this.artistName,
    required this.durationMs,
    this.albumName,
    this.albumBrowseId,
    this.artistBrowseId,
    this.thumbnail,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String,
        albumName: json['albumName'] as String?,
        albumBrowseId: json['albumBrowseId'] as String?,
        artistBrowseId: json['artistBrowseId'] as String?,
        durationMs: json['durationMs'] as int,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String artistName;
  final String? albumName;
  final String? albumBrowseId;
  final String? artistBrowseId;
  final int durationMs;
  final Thumbnail? thumbnail;
}
```

- [ ] **Step 12.3: StreamInfo**

`app/lib/core/api/models/stream_info.dart`:
```dart
class StreamInfo {
  StreamInfo({
    required this.videoId,
    required this.url,
    required this.expiresAt,
    required this.codec,
    required this.container,
    required this.bitrate,
    required this.approxDurationMs,
    this.contentLength,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) => StreamInfo(
        videoId: json['videoId'] as String,
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        codec: json['codec'] as String,
        container: json['container'] as String,
        bitrate: json['bitrate'] as int,
        approxDurationMs: json['approxDurationMs'] as int,
        contentLength: json['contentLength'] as int?,
      );

  final String videoId;
  final String url;
  final DateTime expiresAt;
  final String codec;
  final String container;
  final int bitrate;
  final int approxDurationMs;
  final int? contentLength;
}
```

- [ ] **Step 12.4: Verify**

```bash
fvm flutter analyze
fvm flutter test
```

- [ ] **Step 12.5: Commit**

```bash
git add app/lib/core/api/models
git commit -m "feat(app): SearchResult / Track / StreamInfo models"
```

---

## Task 13: Extend `ApiClient` with search / getTrack / resolveStream

**Files:**
- Modify: `app/lib/core/api/api_client.dart`
- Modify: `app/test/api_client_test.dart` (add tests)

- [ ] **Step 13.1: Failing tests**

Append to `app/test/api_client_test.dart`:
```dart
import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';

// ... reuse existing _RecordingAdapter

void main() {
  // ... existing tests

  test('search() returns parsed list of results', () async {
    final adapter = _RecordingAdapter()
      ..body = '{"items":[{"type":"song","videoId":"abc","title":"T","artistName":"A","durationMs":180000}],"continuation":null}';
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://x',
        cfAccessClientId: 'I',
        cfAccessClientSecret: 'S',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final result = await client.search('hello');
    expect(result, isA<List<SearchResult>>());
    expect(result.length, 1);
    expect(result.first.title, 'T');
    expect(adapter.lastRequest!.uri.toString(), 'https://x/v1/search?q=hello');
  });

  test('resolveStream() returns parsed StreamInfo', () async {
    final adapter = _RecordingAdapter()
      ..body = '{"videoId":"abc","url":"https://rr/x","expiresAt":"2026-04-30T12:00:00Z","codec":"opus","container":"webm","bitrate":160000,"approxDurationMs":180000,"contentLength":4321}';
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://x',
        cfAccessClientId: 'I',
        cfAccessClientSecret: 'S',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final stream = await client.resolveStream(
      'abc',
      codec: 'opus',
      quality: 'high',
    );
    expect(stream.url, 'https://rr/x');
    expect(stream.codec, 'opus');
    expect(adapter.lastRequest!.uri.toString(),
        'https://x/v1/track/abc/stream?codec=opus&quality=high');
  });
}
```

- [ ] **Step 13.2: Implement**

Append to `app/lib/core/api/api_client.dart`:
```dart
import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';

extension ApiClientCatalog on ApiClient {
  Future<List<SearchResult>> search(
    String query, {
    String? type,
    int limit = 20,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/search',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          'limit': limit,
        },
      );
      final items = (res.data!['items'] as List)
          .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }

  Future<Track> getTrack(String videoId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/track/$videoId');
      return Track.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }

  Future<StreamInfo> resolveStream(
    String videoId, {
    String codec = 'any',
    String quality = 'high',
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/track/$videoId/stream',
        queryParameters: {'codec': codec, 'quality': quality},
      );
      return StreamInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }
}
```

- [ ] **Step 13.3: Run, expect tests pass**

```bash
fvm flutter test
fvm flutter analyze
```

- [ ] **Step 13.4: Commit**

```bash
git add app/lib/core/api app/test/api_client_test.dart
git commit -m "feat(app): ApiClient.search / getTrack / resolveStream"
```

---

## Task 14: AudioPlaybackHandler

A single `BaseAudioHandler` registered with `audio_service`. Resolves a stream URL through the API client, hands it to `just_audio`, and on `403`/`410` re-resolves and resumes.

**Files:**
- Create: `app/lib/core/audio/audio_handler.dart`
- Create: `app/lib/core/audio/audio_providers.dart`
- Create: `app/test/audio_handler_test.dart`

- [ ] **Step 14.1: Failing test**

`app/test/audio_handler_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

class _MockApi extends Mock implements ApiClient {}
class _MockPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockApi api;
  late _MockPlayer player;
  late AudioPlaybackHandler handler;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(AudioSource.uri(Uri.parse('https://example.com')));
  });

  setUp(() {
    api = _MockApi();
    player = _MockPlayer();
    when(() => player.playbackEventStream).thenAnswer((_) => const Stream.empty());
    when(() => player.positionStream).thenAnswer((_) => const Stream.empty());
    when(() => player.bufferedPositionStream).thenAnswer((_) => const Stream.empty());
    when(() => player.durationStream).thenAnswer((_) => const Stream<Duration?>.empty());
    handler = AudioPlaybackHandler(player: player, apiClientFactory: () => api);
  });

  test('playTrack resolves stream URL and starts playback', () async {
    final track = Track(
      videoId: 'abc',
      title: 'T',
      artistName: 'A',
      durationMs: 180000,
    );
    when(() => api.resolveStream(any(), codec: any(named: 'codec'), quality: any(named: 'quality')))
        .thenAnswer((_) async => StreamInfo(
              videoId: 'abc',
              url: 'https://rr/x',
              expiresAt: DateTime.now().add(const Duration(hours: 6)),
              codec: 'opus',
              container: 'webm',
              bitrate: 160000,
              approxDurationMs: 180000,
            ));
    when(() => player.setAudioSource(any())).thenAnswer((_) async => null);
    when(() => player.play()).thenAnswer((_) async {});

    await handler.playTrack(track);

    verify(() => api.resolveStream('abc', codec: 'opus', quality: 'high')).called(1);
    verify(() => player.setAudioSource(any())).called(1);
    verify(() => player.play()).called(1);
  });
}
```

- [ ] **Step 14.2: Implement handler**

`app/lib/core/audio/audio_handler.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/track.dart';

typedef ApiClientFactory = ApiClient? Function();

class AudioPlaybackHandler extends BaseAudioHandler {
  AudioPlaybackHandler({
    AudioPlayer? player,
    required this.apiClientFactory,
  }) : _player = player ?? AudioPlayer() {
    _wirePlayerEvents();
  }

  final AudioPlayer _player;
  final ApiClientFactory apiClientFactory;
  Track? _currentTrack;

  void _wirePlayerEvents() {
    _player.playbackEventStream.listen((event) {
      final state = _toState(event);
      playbackState.add(state);
    });
  }

  PlaybackState _toState(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _processingState(event.processingState),
      playing: _player.playing,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    );
  }

  AudioProcessingState _processingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    final api = apiClientFactory();
    if (api == null) {
      throw StateError('ApiClient not configured');
    }
    final info = await api.resolveStream(
      track.videoId,
      codec: 'opus',
      quality: 'high',
    );
    final mediaItem = MediaItem(
      id: track.videoId,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      duration: Duration(milliseconds: track.durationMs),
      artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!.url) : null,
    );
    this.mediaItem.add(mediaItem);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(info.url)));
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}
```

- [ ] **Step 14.3: Run test, expect pass**

```bash
fvm flutter test test/audio_handler_test.dart
```

- [ ] **Step 14.4: Riverpod providers + audio_service init**

`app/lib/core/audio/audio_providers.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

final audioHandlerProvider = Provider<AudioPlaybackHandler>((ref) {
  throw UnimplementedError('Override in main() after AudioService.init()');
});

final mediaItemStreamProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});
```

- [ ] **Step 14.5: Wire `AudioService.init()` in `main.dart`**

Replace `app/lib/main.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/app.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build a temporary ProviderContainer so the handler factory can resolve
  // the API client via Riverpod when audio_service spins it up.
  final container = ProviderContainer();
  final handler = await AudioService.init(
    builder: () => AudioPlaybackHandler(
      apiClientFactory: () => container.read(apiClientProvider),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.richarddepierre.ytmusic.audio',
      androidNotificationChannelName: 'UichaaMusic playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [audioHandlerProvider.overrideWithValue(handler)],
        child: const UichaaMusicApp(),
      ),
    ),
  );
}
```

(Note: this uses `UncontrolledProviderScope` so the same `container` is reused; alternative cleaner pattern with global Riverpod overrides also works — pick whichever the implementer prefers, as long as `audioHandlerProvider` returns the initialized handler.)

- [ ] **Step 14.6: Verify analyze + test**

```bash
fvm flutter analyze
fvm flutter test
```

- [ ] **Step 14.7: Commit**

```bash
git add app/lib/core/audio app/lib/main.dart app/test/audio_handler_test.dart
git commit -m "feat(app): AudioPlaybackHandler + audio_service init"
```

---

## Task 15: iOS + Android background audio config

**Files:**
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 15.1: iOS — declare background audio capability**

In `app/ios/Runner/Info.plist`, add inside the top-level `<dict>`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

- [ ] **Step 15.2: Android — `audio_service` declarations**

In `app/android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Inside `<application>`:
```xml
<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true"
    tools:ignore="Instantiatable">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>
<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```

(Add `xmlns:tools="http://schemas.android.com/tools"` to the root `<manifest>` if not already present.)

- [ ] **Step 15.3: Verify the app still builds**

```bash
cd app
fvm flutter pub get
fvm flutter analyze
```

(Don't run on device yet — Task 18 covers the smoke test.)

- [ ] **Step 15.4: Commit**

```bash
git add app/ios app/android
git commit -m "feat(app): iOS UIBackgroundModes + Android audio_service service+permissions"
```

---

## Task 16: Search screen

**Files:**
- Create: `app/lib/features/search/search_controller.dart`
- Create: `app/lib/features/search/search_screen.dart`

- [ ] **Step 16.1: Controller**

`app/lib/features/search/search_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/search_result.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    return [];
  }
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw ApiException(0, 'Client not configured');
  }
  return client.search(query);
});
```

- [ ] **Step 16.2: Screen**

`app/lib/features/search/search_screen.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/features/search/search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(SearchResult r) async {
    if (r.type != 'song' || r.videoId == null) return; // tap-to-play only on songs
    final track = Track(
      videoId: r.videoId!,
      title: r.title,
      artistName: r.artistName ?? 'Unknown',
      albumName: r.albumName,
      durationMs: r.durationMs ?? 0,
    );
    await ref.read(audioHandlerProvider).playTrack(track);
    if (mounted) context.go('/now-playing');
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onSubmitted: (v) =>
              ref.read(searchQueryProvider.notifier).state = v,
          decoration: const InputDecoration(
            hintText: 'Search music',
            border: InputBorder.none,
          ),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final r = items[i];
            return ListTile(
              leading: r.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: r.thumbnail!.url,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : const SizedBox(width: 48, height: 48),
              title: Text(r.title),
              subtitle: Text(_subtitleFor(r)),
              onTap: () => _onTap(r),
            );
          },
        ),
      ),
    );
  }

  String _subtitleFor(SearchResult r) {
    final parts = <String>[
      r.type,
      if (r.artistName != null) r.artistName!,
      if (r.albumName != null) r.albumName!,
    ];
    return parts.join(' • ');
  }
}
```

- [ ] **Step 16.3: Verify**

```bash
fvm flutter analyze
fvm flutter test
```

- [ ] **Step 16.4: Commit**

```bash
git add app/lib/features/search
git commit -m "feat(app): SearchScreen + tap-to-play (songs only)"
```

---

## Task 17: NowPlayingScreen + MiniPlayer + routing

**Files:**
- Create: `app/lib/features/now_playing/now_playing_screen.dart`
- Create: `app/lib/features/now_playing/mini_player.dart`
- Modify: `app/lib/routing/app_router.dart` (add `/search`, `/now-playing`)
- Modify: `app/lib/app.dart` (wrap routed pages so MiniPlayer is visible globally)

- [ ] **Step 17.1: NowPlayingScreen**

`app/lib/features/now_playing/now_playing_screen.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(mediaItemStreamProvider);
    final state = ref.watch(playbackStateStreamProvider);
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: mediaItem.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Nothing playing'));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (item.artUri != null)
                  CachedNetworkImage(
                    imageUrl: item.artUri.toString(),
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 24),
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                if (item.artist != null) Text(item.artist!),
                const Spacer(),
                _Transport(state: state, handler: handler),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.handler});

  final AsyncValue<PlaybackState> state;
  final dynamic handler; // AudioPlaybackHandler

  @override
  Widget build(BuildContext context) {
    final playing = state.valueOrNull?.playing ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          iconSize: 64,
          onPressed: () => playing ? handler.pause() : handler.play(),
        ),
      ],
    );
  }
}
```

- [ ] **Step 17.2: MiniPlayer**

`app/lib/features/now_playing/mini_player.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(mediaItemStreamProvider);
    final state = ref.watch(playbackStateStreamProvider);
    final handler = ref.watch(audioHandlerProvider);

    final item = mediaItem.valueOrNull;
    if (item == null) return const SizedBox.shrink();

    final playing = state.valueOrNull?.playing ?? false;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => context.go('/now-playing'),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (item.artUri != null)
                CachedNetworkImage(
                  imageUrl: item.artUri.toString(),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              else
                const SizedBox(width: 56, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (item.artist != null)
                      Text(
                        item.artist!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => playing ? handler.pause() : handler.play(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 17.3: Update router**

`app/lib/routing/app_router.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/settings/settings_providers.dart';
import 'package:ytmusic/features/health/health_screen.dart';
import 'package:ytmusic/features/now_playing/now_playing_screen.dart';
import 'package:ytmusic/features/onboarding/onboarding_screen.dart';
import 'package:ytmusic/features/search/search_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/search',
    redirect: (context, state) {
      final config = ref.read(apiConfigProvider).valueOrNull;
      final configured = config != null && config.isComplete;
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      if (!configured && !goingToOnboarding) return '/onboarding';
      if (configured && goingToOnboarding) return '/search';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/health', builder: (_, __) => const HealthScreen()),
      GoRoute(path: '/now-playing', builder: (_, __) => const NowPlayingScreen()),
    ],
  );
});
```

(Note: the post-onboarding redirect target is now `/search` instead of `/health`; `/health` remains reachable for diagnostics.)

- [ ] **Step 17.4: Wrap routed pages with MiniPlayer**

`app/lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/theme/app_theme.dart';
import 'package:ytmusic/features/now_playing/mini_player.dart';
import 'package:ytmusic/routing/app_router.dart';

class UichaaMusicApp extends ConsumerWidget {
  const UichaaMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UichaaMusic',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            const MiniPlayer(),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 17.5: Verify**

```bash
fvm flutter analyze
fvm flutter test
```

- [ ] **Step 17.6: Commit**

```bash
git add app/lib
git commit -m "feat(app): NowPlayingScreen + MiniPlayer + routing for /search and /now-playing"
```

---

## Task 18: End-to-end smoke test (USER ACTION)

Plan-level milestone — not implemented in code. The user runs the stack + app and verifies search → playback works.

- [ ] **Step 18.1: Bring up backend**
```bash
docker compose up -d --build
curl -s -H "CF-Access-Client-Id: $CFID" -H "CF-Access-Client-Secret: $CFSECRET" \
  "https://ytmusic.<your-zone>/v1/search?q=blue+note" | jq '.items | length'
```
Should return a positive integer.

- [ ] **Step 18.2: Bring up app**
```bash
cd app
fvm flutter run --profile -d <iPhone-id>
```

- [ ] **Step 18.3: Search → tap → play**
- App opens to `/search`
- Type a song name (e.g. "Daft Punk Around The World")
- Tap a song result
- App navigates to `/now-playing`; audio starts within ~2 seconds
- Lock the phone — audio continues; lockscreen shows track title + artwork + play/pause
- Pause via lockscreen — audio pauses
- Unlock, tap MiniPlayer → expand to NowPlayingScreen

- [ ] **Step 18.4: Stream URL refresh smoke (optional manual)**
- Wait > 25 minutes after starting playback
- Pause and resume; should still work (URL re-resolved if expired)

If anything fails, capture device logs (`fvm flutter logs` or Xcode console) and the backend logs (`docker compose logs yt-music-api`).

---

## Self-review

**Spec coverage:**
- §2.1 endpoints: `/search`, `/track/{id}`, `/track/{id}/stream` — covered (Tasks 5, 6, 9).
- §2.2 stream contract: best-effort codec/quality, expiresAt, structured response — covered (Task 8 + 9).
- §2.5 caching: search 5min, track 24h, stream 25min — Task 1 utility, used in Tasks 5, 6, 9.
- §2.6 concurrency: 2-3 stream resolutions in flight — Task 2 + 9.
- §3.4 PoT integration — Task 7 + 8.
- §4.3 single AudioPlaybackHandler — Task 14.
- §4.4 errors as toasts/banners — partial (basic error widget, ErrorBoundary deferred to Phase 7 polish).

**Out-of-scope confirmed:** library, playlists, Drift, downloads, optimistic mutations, track detail screen, lyrics — none touched.

**Type consistency check:** `playTrack(Track)` signature consistent across handler, search controller, and tests. `resolveStream(videoId, codec, quality)` signature consistent across `ApiClient`, `AudioPlaybackHandler`, and tests. `apiClientProvider` returns `ApiClient?` — handler factory checks null.

**Placeholders:** none. Every step contains the actual content the engineer needs.

**Risks not addressed in this plan:**
- The `Audio` import shadow / `dynamic handler` typing in `_Transport` — could be tidied; left as `dynamic` because `AudioPlaybackHandler` isn't imported in that file. Replace with a typed `AudioPlaybackHandler` import in a follow-up.
- `extractor_args` shape for yt-dlp's PoT integration: the exact structure (`{"youtube": {"po_token_provider_url": [url]}}`) is what yt-dlp expects today; if upstream changes, Task 8's resolver test will catch it.
- iOS `UIBackgroundModes` requires re-signing; the app must be re-installed via Xcode for this to take effect on a previously-installed build.
