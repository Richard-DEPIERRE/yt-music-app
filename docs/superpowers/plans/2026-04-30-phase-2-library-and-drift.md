# Phase 2: Library Reads + Drift Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End state — open the app, hit the Library tab, see your liked songs / playlists / subscriptions / history streamed from a local Drift database while a background sync writes through from the backend `/v1/library/*` endpoints. Pull-to-refresh re-syncs each list. Tap a track on any list to play it.

**Architecture:** Five new paginated GET endpoints on the backend, each a thin wrapper over `ytmusicapi`'s library calls. Per spec §2.5 these are **never cached server-side** — Drift on the phone is the real cache. On the app side, introduce `drift` + `drift_dev` + `path_provider`, implement the schema in spec §5 (tables + indexes), build DAOs, and put a `LibraryRepository` between the screens and the network: screens watch Drift; the repository upserts on sync. A `sync_state` table tracks per-resource `lastSyncedAt` + opaque etag. Pagination uses opaque continuation tokens passed through unchanged from `ytmusicapi` (spec §2.3).

**Tech Stack:** (additions over Phase 1) `drift ^2.20`, `drift_dev ^2.20`, `path_provider ^2.1`, `sqlite3_flutter_libs ^0.5` (Flutter); no new backend deps — `ytmusicapi` already covers all library methods.

**Out of scope for this phase (per spec):**
- Optimistic offline writes / mutation queue (deferred — option B)
- Album / artist detail screens (Phase 3)
- `/library/snapshot` (Phase 4 prerequisite)
- Library write endpoints — `POST/DELETE /library/like`, playlist CRUD (Phase 4)
- Lyrics, track detail screen
- `/home`, `/radio`, `/up-next` (Phase 3)

**Locked decisions (do not reopen unless the user does):**
- Online-only writes (option A); no `pending_mutations` table in v1.
- Tap-to-play directly from list rows; no track-detail screen.
- AAC default for playback on iOS (`PlatformException -11828` on Opus-in-WebM).
- `videoId` is the canonical track identity. Liking flips a bit; never duplicates rows.
- `playlist_tracks` PK is `(playlistBrowseId, setVideoId)` — YT permits the same track twice and removal needs the per-occurrence id.

---

## File map

### Backend (new)
- `backend/src/ytmusic_api/routers/library.py` — all five `/v1/library/*` GET endpoints
- `backend/src/ytmusic_api/models/library.py` — pydantic response models
- `backend/tests/test_library.py`

### Backend (modified)
- `backend/src/ytmusic_api/services/ytmusic_client.py` — add `get_liked_songs`, `get_library_playlists`, `get_playlist`, `get_library_subscriptions`, `get_history`
- `backend/src/ytmusic_api/main.py` — mount library router

### Flutter app (new)
- `app/lib/core/db/database.dart` — Drift `@DriftDatabase` (will generate `database.g.dart`)
- `app/lib/core/db/tables.dart` — table definitions
- `app/lib/core/db/connection.dart` — `LazyDatabase` opener using `path_provider`
- `app/lib/core/db/db_providers.dart` — Riverpod `Provider<AppDatabase>`
- `app/lib/core/db/daos/tracks_dao.dart`
- `app/lib/core/db/daos/playlists_dao.dart`
- `app/lib/core/db/daos/artists_dao.dart`
- `app/lib/core/db/daos/recently_played_dao.dart`
- `app/lib/core/db/daos/sync_state_dao.dart`
- `app/lib/core/api/models/library_models.dart` — `LikedSongPage`, `PlaylistSummary`, `PlaylistDetailPage`, `ArtistSubscription`, `HistoryItem`
- `app/lib/core/library/library_repository.dart` — read-from-Drift, write-through-from-API
- `app/lib/core/library/library_providers.dart` — Riverpod providers (repo + watch streams)
- `app/lib/features/library/library_hub_screen.dart` — landing page with four tiles
- `app/lib/features/library/liked_songs_screen.dart`
- `app/lib/features/library/playlists_screen.dart`
- `app/lib/features/library/playlist_detail_screen.dart`
- `app/lib/features/library/subscriptions_screen.dart`
- `app/lib/features/library/history_screen.dart`
- `app/lib/features/library/widgets/track_list_tile.dart` — shared row used across all list screens
- `app/test/core/db/database_test.dart`
- `app/test/core/db/daos/tracks_dao_test.dart`
- `app/test/core/db/daos/playlists_dao_test.dart`
- `app/test/core/db/daos/sync_state_dao_test.dart`
- `app/test/core/library/library_repository_test.dart`
- `app/test/features/library/liked_songs_screen_test.dart`

### Flutter app (modified)
- `app/pubspec.yaml` — add drift deps
- `app/lib/core/api/api_client.dart` — add five library methods
- `app/lib/routing/app_router.dart` — add `/library`, `/library/liked`, `/library/playlists`, `/library/playlists/:id`, `/library/subscriptions`, `/library/history`
- `app/lib/features/search/search_screen.dart` — add a Library tab/button (or add a bottom nav scaffold — see Task 21)

---

## Sanity-test commands (used throughout)

Backend (run from worktree root):

```bash
cd backend && PATH=$HOME/.local/bin:$PATH uv sync --extra dev
PATH=$HOME/.local/bin:$PATH uv run pytest -q
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
```

Flutter (run from `app/`):

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
fvm flutter test
```

---

## Task 1: Backend — extend `YTMusicClient` with library methods

**Files:**
- Modify: `backend/src/ytmusic_api/services/ytmusic_client.py`
- Modify: `backend/tests/test_catalog.py` is unrelated; library client is unit-tested through the router in Task 3+.

There are no behavioural tests for `YTMusicClient` in isolation today (it's a 1-line `to_thread` wrapper). Per the Phase 1 pattern, we exercise it through the router tests. This task is **additive plumbing**; library router tests in later tasks cover the new methods.

- [ ] **Step 1: Add the five new wrapper methods**

In `backend/src/ytmusic_api/services/ytmusic_client.py`, append to the `YTMusicClient` class:

```python
    async def get_liked_songs(self, *, limit: int = 100) -> dict[str, Any]:
        """Returns ytmusicapi's full liked-songs payload (a playlist-shaped dict)."""

        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_liked_songs(limit=limit)

        return await asyncio.to_thread(_call)

    async def get_library_playlists(self, *, limit: int = 100) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_library_playlists(limit=limit)

        return await asyncio.to_thread(_call)

    async def get_playlist(
        self, playlist_id: str, *, limit: int = 100
    ) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_playlist(playlist_id, limit=limit)

        return await asyncio.to_thread(_call)

    async def get_library_subscriptions(
        self, *, limit: int = 100
    ) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_library_subscriptions(limit=limit)

        return await asyncio.to_thread(_call)

    async def get_history(self) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_history()

        return await asyncio.to_thread(_call)
```

- [ ] **Step 2: Verify it imports cleanly**

```bash
PATH=$HOME/.local/bin:$PATH uv run python -c "from ytmusic_api.services.ytmusic_client import YTMusicClient; print('ok')"
```
Expected: `ok`.

- [ ] **Step 3: Lint**

```bash
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add backend/src/ytmusic_api/services/ytmusic_client.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): YTMusicClient wrappers for /library/* endpoints

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Backend — pydantic library response models

**Files:**
- Create: `backend/src/ytmusic_api/models/library.py`
- Test: covered through router tests in Tasks 3–7

Continuation tokens are opaque strings passed through unchanged. Every list endpoint returns `{ items: [...], continuation: <str|null> }` per spec §2.3. We reuse `Thumbnail` from `models/catalog.py`.

- [ ] **Step 1: Write the model file**

```python
# backend/src/ytmusic_api/models/library.py
from __future__ import annotations

from pydantic import BaseModel

from .catalog import Thumbnail


class LikedSong(BaseModel):
    videoId: str
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None


class LikedSongsResponse(BaseModel):
    items: list[LikedSong]
    continuation: str | None = None


class PlaylistSummary(BaseModel):
    browseId: str
    title: str
    description: str | None
    trackCount: int | None
    thumbnail: Thumbnail | None
    isOwn: bool


class PlaylistsResponse(BaseModel):
    items: list[PlaylistSummary]
    continuation: str | None = None


class PlaylistTrack(BaseModel):
    videoId: str
    setVideoId: str | None
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None


class PlaylistDetailResponse(BaseModel):
    browseId: str
    title: str
    description: str | None
    ownerName: str | None
    trackCount: int | None
    items: list[PlaylistTrack]
    continuation: str | None = None


class ArtistSubscription(BaseModel):
    browseId: str
    name: str
    thumbnail: Thumbnail | None
    subscriberCount: str | None  # ytmusicapi returns a human string like "1.2M"


class SubscriptionsResponse(BaseModel):
    items: list[ArtistSubscription]
    continuation: str | None = None


class HistoryItem(BaseModel):
    videoId: str
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None
    playedSection: str | None  # ytmusicapi groups by "Today", "Yesterday", etc.


class HistoryResponse(BaseModel):
    items: list[HistoryItem]
    continuation: str | None = None
```

- [ ] **Step 2: Verify import**

```bash
PATH=$HOME/.local/bin:$PATH uv run python -c "from ytmusic_api.models.library import LikedSongsResponse, PlaylistsResponse, PlaylistDetailResponse, SubscriptionsResponse, HistoryResponse; print('ok')"
```
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add backend/src/ytmusic_api/models/library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): pydantic models for library list responses

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Backend — `/v1/library/liked` (TDD)

**Files:**
- Create: `backend/src/ytmusic_api/routers/library.py`
- Create: `backend/tests/test_library.py`
- Modify: `backend/src/ytmusic_api/main.py` (mount router)

`ytmusicapi.get_liked_songs(limit)` returns a *playlist-shaped dict* — `{ tracks: [...], trackCount, continuation? }`. We extract `tracks`. ytmusicapi exposes a `get_continuations`-style flow internally; for v1 we don't paginate liked songs (the user's library fits in one round-trip with `limit=500`). Endpoint accepts `?limit=` (default 100, max 500); continuation is reserved for future use and always `null` in the response.

- [ ] **Step 1: Write the failing tests**

```python
# backend/tests/test_library.py
from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


class _FakeYTMusic(YTMusicClient):  # type: ignore[misc]
    def __init__(self) -> None:
        self.liked_payload: dict[str, Any] = {"tracks": [], "trackCount": 0}
        self.playlists_payload: list[dict[str, Any]] = []
        self.playlist_payloads: dict[str, dict[str, Any]] = {}
        self.subs_payload: list[dict[str, Any]] = []
        self.history_payload: list[dict[str, Any]] = []

    async def get_liked_songs(self, *, limit: int = 100):  # type: ignore[override]
        return self.liked_payload

    async def get_library_playlists(self, *, limit: int = 100):  # type: ignore[override]
        return self.playlists_payload

    async def get_playlist(self, playlist_id: str, *, limit: int = 100):  # type: ignore[override]
        if playlist_id not in self.playlist_payloads:
            raise RuntimeError("not found")
        return self.playlist_payloads[playlist_id]

    async def get_library_subscriptions(self, *, limit: int = 100):  # type: ignore[override]
        return self.subs_payload

    async def get_history(self):  # type: ignore[override]
        return self.history_payload


@pytest.fixture
def fake_ytm() -> _FakeYTMusic:
    return _FakeYTMusic()


@pytest.fixture
def cache() -> TtlCache:
    return TtlCache()


@pytest.fixture
def library_client(headers_store, auth_monitor, fake_ytm, cache) -> TestClient:
    return TestClient(
        create_app(
            headers_store=headers_store,
            auth_monitor=auth_monitor,
            ytmusic_client=fake_ytm,
            cache=cache,
        )
    )


def _liked_track(video_id: str, title: str = "T") -> dict[str, Any]:
    return {
        "videoId": video_id,
        "title": title,
        "artists": [{"name": "Artist", "id": "UCabc"}],
        "album": {"name": "Album", "id": "MPRabc"},
        "duration_seconds": 180,
        "thumbnails": [{"url": "https://t/x.jpg", "width": 60, "height": 60}],
    }


def test_liked_returns_normalised_items(library_client, fake_ytm):
    fake_ytm.liked_payload = {
        "tracks": [_liked_track("v1"), _liked_track("v2", "Other")],
        "trackCount": 2,
    }
    r = library_client.get("/v1/library/liked")
    assert r.status_code == 200
    body = r.json()
    assert body["continuation"] is None
    assert [it["videoId"] for it in body["items"]] == ["v1", "v2"]
    first = body["items"][0]
    assert first["title"] == "T"
    assert first["artistName"] == "Artist"
    assert first["albumName"] == "Album"
    assert first["durationMs"] == 180_000
    assert first["thumbnail"]["url"] == "https://t/x.jpg"


def test_liked_skips_items_missing_videoid(library_client, fake_ytm):
    bad = _liked_track("v1")
    bad.pop("videoId")
    fake_ytm.liked_payload = {"tracks": [bad, _liked_track("v2")]}
    r = library_client.get("/v1/library/liked")
    assert r.status_code == 200
    assert [it["videoId"] for it in r.json()["items"]] == ["v2"]


def test_liked_is_not_cached_server_side(library_client, fake_ytm):
    """Spec §2.5: /library/* is never cached server-side."""
    call_count = {"n": 0}

    async def counting():
        call_count["n"] += 1
        return {"tracks": [_liked_track("v1")]}

    fake_ytm.get_liked_songs = lambda **kw: counting()  # type: ignore[assignment]
    library_client.get("/v1/library/liked")
    library_client.get("/v1/library/liked")
    assert call_count["n"] == 2
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
```
Expected: FAIL — `library` router does not exist; 404 on every call.

- [ ] **Step 3: Implement the router**

```python
# backend/src/ytmusic_api/routers/library.py
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import Thumbnail
from ..models.library import (
    LikedSong,
    LikedSongsResponse,
)
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()


def _last_thumb(raw: dict[str, Any]) -> Thumbnail | None:
    thumbs = raw.get("thumbnails") or []
    return Thumbnail(**thumbs[-1]) if thumbs else None


def _track_artist(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    artists = raw.get("artists") or []
    name = artists[0]["name"] if artists else None
    bid = artists[0].get("id") if artists else None
    return name, bid


def _track_album(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    album = raw.get("album") or {}
    if isinstance(album, dict):
        return album.get("name"), album.get("id")
    return album, None


def _normalise_liked(raw: dict[str, Any]) -> LikedSong | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artist_name, _ = _track_artist(raw)
    album_name, album_bid = _track_album(raw)
    duration_seconds = raw.get("duration_seconds")
    return LikedSong(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=int(duration_seconds * 1000) if duration_seconds else None,
        thumbnail=_last_thumb(raw),
    )


@router.get("/library/liked", response_model=LikedSongsResponse)
async def get_liked(
    request: Request,
    limit: int = Query(100, ge=1, le=500),
) -> LikedSongsResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    try:
        raw = await ytm.get_liked_songs(limit=limit)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc
    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_liked(t) for t in tracks) if n is not None]
    return LikedSongsResponse(items=items, continuation=None)
```

- [ ] **Step 4: Mount the router**

In `backend/src/ytmusic_api/main.py`, add `library` to the import and `app.include_router(library.router, prefix="/v1")` next to the others:

```python
from .routers import admin, catalog, health, library, stream
# ...
    app.include_router(library.router, prefix="/v1")
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
```
Expected: 3 passed.

- [ ] **Step 6: Lint**

```bash
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add backend/src/ytmusic_api/routers/library.py backend/src/ytmusic_api/main.py backend/tests/test_library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): GET /v1/library/liked

Wraps ytmusicapi.get_liked_songs and exposes the normalised wire
format. No server-side cache (spec §2.5 — Drift on the phone is
the canonical cache).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Backend — `/v1/library/playlists` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/library.py`
- Modify: `backend/tests/test_library.py`

`ytmusicapi.get_library_playlists()` returns a flat list of playlist summaries: `[{playlistId, title, description?, count, thumbnails, author? }, ...]`. The `author` field, if present and matching the signed-in user, marks `isOwn=True`; ytmusicapi doesn't always populate it, so we fall back to "is it not the magic LM playlist" — anything that isn't the auto-generated "Liked Music" / "Episodes for Later" we treat as own. Per spec §2.1, this endpoint returns titles only (no track lists) — the playlist detail endpoint provides tracks.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_library.py`:

```python
def _playlist_summary(pid: str, title: str = "P", **extra) -> dict[str, Any]:
    base: dict[str, Any] = {
        "playlistId": pid,
        "title": title,
        "description": "desc",
        "count": "10",
        "thumbnails": [{"url": "https://t/p.jpg", "width": 60, "height": 60}],
    }
    base.update(extra)
    return base


def test_playlists_returns_normalised_items(library_client, fake_ytm):
    fake_ytm.playlists_payload = [
        _playlist_summary("PL1", "Mix"),
        _playlist_summary("PL2", "Other", count="N/A"),
    ]
    r = library_client.get("/v1/library/playlists")
    assert r.status_code == 200
    body = r.json()
    assert body["continuation"] is None
    assert [p["browseId"] for p in body["items"]] == ["PL1", "PL2"]
    first = body["items"][0]
    assert first["title"] == "Mix"
    assert first["description"] == "desc"
    assert first["trackCount"] == 10
    # PL2's "N/A" track count parses to None, not crash:
    assert body["items"][1]["trackCount"] is None


def test_playlists_skips_items_missing_id(library_client, fake_ytm):
    bad = _playlist_summary("PL1")
    bad.pop("playlistId")
    fake_ytm.playlists_payload = [bad, _playlist_summary("PL2")]
    r = library_client.get("/v1/library/playlists")
    assert [p["browseId"] for p in r.json()["items"]] == ["PL2"]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
```
Expected: 2 new tests fail with 404.

- [ ] **Step 3: Implement the endpoint**

Add to `backend/src/ytmusic_api/routers/library.py`:

```python
from ..models.library import (
    LikedSong,
    LikedSongsResponse,
    PlaylistSummary,
    PlaylistsResponse,
)


def _parse_count(raw: Any) -> int | None:
    if raw is None:
        return None
    try:
        return int(str(raw).replace(",", ""))
    except (TypeError, ValueError):
        return None


def _normalise_playlist_summary(raw: dict[str, Any]) -> PlaylistSummary | None:
    pid = raw.get("playlistId") or raw.get("browseId")
    if not pid:
        return None
    return PlaylistSummary(
        browseId=pid,
        title=raw.get("title", ""),
        description=raw.get("description"),
        trackCount=_parse_count(raw.get("count")),
        thumbnail=_last_thumb(raw),
        isOwn=True,  # Spec defers per-playlist ownership detection; treat all as own for now.
    )


@router.get("/library/playlists", response_model=PlaylistsResponse)
async def get_playlists(request: Request) -> PlaylistsResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    try:
        raw = await ytm.get_library_playlists(limit=200)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc
    items = [n for n in (_normalise_playlist_summary(p) for p in raw) if n is not None]
    return PlaylistsResponse(items=items, continuation=None)
```

- [ ] **Step 4: Run tests + lint**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
```
Expected: all pass, no lint errors.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/library.py backend/tests/test_library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): GET /v1/library/playlists (titles only)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Backend — `/v1/library/playlists/{id}` with continuation (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/library.py`
- Modify: `backend/tests/test_library.py`

This is the only endpoint where pagination genuinely matters in v1 — large playlists may have thousands of tracks. `ytmusicapi.get_playlist(id, limit)` reads up to `limit` tracks; passing a high enough limit (we use 500 server-side) gets us "all of them" for typical playlists. For correctness across truly huge playlists, we accept `?continuation=` (opaque token, currently always `null` because ytmusicapi internally exhausts limit) — wired now so the contract is forward-compatible with a future pagination story.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_library.py`:

```python
def _playlist_track(video_id: str, set_id: str = "set", **extra) -> dict[str, Any]:
    base: dict[str, Any] = {
        "videoId": video_id,
        "setVideoId": set_id,
        "title": "Track",
        "artists": [{"name": "Artist", "id": "UCabc"}],
        "album": {"name": "Album", "id": "MPRabc"},
        "duration_seconds": 200,
        "thumbnails": [{"url": "https://t/p.jpg", "width": 60, "height": 60}],
    }
    base.update(extra)
    return base


def test_playlist_detail_returns_normalised(library_client, fake_ytm):
    fake_ytm.playlist_payloads["PL1"] = {
        "id": "PL1",
        "title": "Mix",
        "description": "d",
        "author": {"name": "Me"},
        "trackCount": 2,
        "tracks": [_playlist_track("v1", "s1"), _playlist_track("v2", "s2")],
    }
    r = library_client.get("/v1/library/playlists/PL1")
    assert r.status_code == 200
    body = r.json()
    assert body["browseId"] == "PL1"
    assert body["title"] == "Mix"
    assert body["ownerName"] == "Me"
    assert body["trackCount"] == 2
    assert [t["setVideoId"] for t in body["items"]] == ["s1", "s2"]
    assert body["items"][0]["videoId"] == "v1"
    assert body["continuation"] is None


def test_playlist_detail_404_when_not_found(library_client, fake_ytm):
    r = library_client.get("/v1/library/playlists/NOPE")
    assert r.status_code == 404


def test_playlist_detail_skips_tracks_without_videoid(library_client, fake_ytm):
    bad = _playlist_track("v1", "s1")
    bad["videoId"] = None
    fake_ytm.playlist_payloads["PL1"] = {
        "id": "PL1",
        "title": "Mix",
        "tracks": [bad, _playlist_track("v2", "s2")],
    }
    r = library_client.get("/v1/library/playlists/PL1")
    assert [t["videoId"] for t in r.json()["items"]] == ["v2"]
```

- [ ] **Step 2: Run failing tests**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q -k playlist_detail
```
Expected: 3 failures with 404.

- [ ] **Step 3: Implement**

Add to `backend/src/ytmusic_api/routers/library.py`:

```python
from ..models.library import (
    LikedSong,
    LikedSongsResponse,
    PlaylistDetailResponse,
    PlaylistSummary,
    PlaylistTrack,
    PlaylistsResponse,
)


def _normalise_playlist_track(raw: dict[str, Any]) -> PlaylistTrack | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artist_name, _ = _track_artist(raw)
    album_name, album_bid = _track_album(raw)
    duration_seconds = raw.get("duration_seconds")
    return PlaylistTrack(
        videoId=video_id,
        setVideoId=raw.get("setVideoId"),
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=int(duration_seconds * 1000) if duration_seconds else None,
        thumbnail=_last_thumb(raw),
    )


@router.get(
    "/library/playlists/{playlist_id}", response_model=PlaylistDetailResponse
)
async def get_playlist_detail(
    request: Request,
    playlist_id: str,
    continuation: str | None = Query(None),
) -> PlaylistDetailResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    # `continuation` is reserved for future use; ytmusicapi handles paging via limit.
    try:
        raw = await ytm.get_playlist(playlist_id, limit=500)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"playlist not found: {exc}") from exc

    tracks = raw.get("tracks") or []
    items = [
        n for n in (_normalise_playlist_track(t) for t in tracks) if n is not None
    ]
    author = raw.get("author") or {}
    owner = author.get("name") if isinstance(author, dict) else author
    return PlaylistDetailResponse(
        browseId=raw.get("id", playlist_id),
        title=raw.get("title", ""),
        description=raw.get("description"),
        ownerName=owner,
        trackCount=raw.get("trackCount") or len(items),
        items=items,
        continuation=None,
    )
```

- [ ] **Step 4: Run tests + lint**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/library.py backend/tests/test_library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): GET /v1/library/playlists/{id} with continuation contract

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Backend — `/v1/library/subscriptions` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/library.py`
- Modify: `backend/tests/test_library.py`

`ytmusicapi.get_library_subscriptions(limit)` returns `[{ artist: 'Name', browseId: 'UC...', subscribers: '1.2M', thumbnails: [...] }, ...]` — note `subscribers` is a human-formatted string we pass through unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_library.py`:

```python
def test_subscriptions_returns_normalised(library_client, fake_ytm):
    fake_ytm.subs_payload = [
        {
            "artist": "Artist A",
            "browseId": "UCa",
            "subscribers": "1.2M",
            "thumbnails": [{"url": "https://t/a.jpg", "width": 60, "height": 60}],
        },
        {"artist": "Artist B", "browseId": "UCb", "subscribers": None, "thumbnails": []},
    ]
    r = library_client.get("/v1/library/subscriptions")
    assert r.status_code == 200
    body = r.json()
    assert [s["browseId"] for s in body["items"]] == ["UCa", "UCb"]
    assert body["items"][0]["name"] == "Artist A"
    assert body["items"][0]["subscriberCount"] == "1.2M"
    assert body["items"][1]["thumbnail"] is None


def test_subscriptions_skips_items_missing_browseid(library_client, fake_ytm):
    fake_ytm.subs_payload = [
        {"artist": "Artist A", "subscribers": "1M"},
        {"artist": "Artist B", "browseId": "UCb"},
    ]
    r = library_client.get("/v1/library/subscriptions")
    assert [s["browseId"] for s in r.json()["items"]] == ["UCb"]
```

- [ ] **Step 2: Verify failure, implement, verify pass**

Run failing tests, then add to `library.py`:

```python
from ..models.library import (
    ArtistSubscription,
    LikedSong,
    LikedSongsResponse,
    PlaylistDetailResponse,
    PlaylistSummary,
    PlaylistTrack,
    PlaylistsResponse,
    SubscriptionsResponse,
)


def _normalise_subscription(raw: dict[str, Any]) -> ArtistSubscription | None:
    bid = raw.get("browseId")
    if not bid:
        return None
    return ArtistSubscription(
        browseId=bid,
        name=raw.get("artist") or raw.get("name", ""),
        thumbnail=_last_thumb(raw),
        subscriberCount=raw.get("subscribers"),
    )


@router.get("/library/subscriptions", response_model=SubscriptionsResponse)
async def get_subscriptions(request: Request) -> SubscriptionsResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    try:
        raw = await ytm.get_library_subscriptions(limit=200)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc
    items = [n for n in (_normalise_subscription(s) for s in raw) if n is not None]
    return SubscriptionsResponse(items=items, continuation=None)
```

- [ ] **Step 3: Run tests + lint + commit**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
git add backend/src/ytmusic_api/routers/library.py backend/tests/test_library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): GET /v1/library/subscriptions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Backend — `/v1/library/history` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/library.py`
- Modify: `backend/tests/test_library.py`

`ytmusicapi.get_history()` returns a flat list of track-shaped dicts with an extra `played` field (e.g. "Today", "Yesterday"). Recently-played is server-driven only per spec §5.2.

- [ ] **Step 1: Write the failing tests**

```python
def _history_item(video_id: str, played: str = "Today") -> dict[str, Any]:
    return {
        "videoId": video_id,
        "title": "T",
        "artists": [{"name": "Artist"}],
        "album": {"name": "Album", "id": "MPRabc"},
        "duration_seconds": 180,
        "thumbnails": [{"url": "https://t/h.jpg", "width": 60, "height": 60}],
        "played": played,
    }


def test_history_returns_normalised(library_client, fake_ytm):
    fake_ytm.history_payload = [
        _history_item("v1", "Today"),
        _history_item("v2", "Yesterday"),
    ]
    r = library_client.get("/v1/library/history")
    assert r.status_code == 200
    body = r.json()
    assert [h["videoId"] for h in body["items"]] == ["v1", "v2"]
    assert body["items"][0]["playedSection"] == "Today"
    assert body["items"][1]["playedSection"] == "Yesterday"


def test_history_skips_items_missing_videoid(library_client, fake_ytm):
    bad = _history_item("v1")
    bad.pop("videoId")
    fake_ytm.history_payload = [bad, _history_item("v2")]
    r = library_client.get("/v1/library/history")
    assert [h["videoId"] for h in r.json()["items"]] == ["v2"]
```

- [ ] **Step 2: Implement**

```python
from ..models.library import (
    ArtistSubscription,
    HistoryItem,
    HistoryResponse,
    LikedSong,
    LikedSongsResponse,
    PlaylistDetailResponse,
    PlaylistSummary,
    PlaylistTrack,
    PlaylistsResponse,
    SubscriptionsResponse,
)


def _normalise_history_item(raw: dict[str, Any]) -> HistoryItem | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artist_name, _ = _track_artist(raw)
    album_name, album_bid = _track_album(raw)
    duration_seconds = raw.get("duration_seconds")
    return HistoryItem(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=int(duration_seconds * 1000) if duration_seconds else None,
        thumbnail=_last_thumb(raw),
        playedSection=raw.get("played"),
    )


@router.get("/library/history", response_model=HistoryResponse)
async def get_history_endpoint(request: Request) -> HistoryResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    try:
        raw = await ytm.get_history()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc
    items = [n for n in (_normalise_history_item(h) for h in raw) if n is not None]
    return HistoryResponse(items=items, continuation=None)
```

- [ ] **Step 3: Run tests + lint + commit**

```bash
PATH=$HOME/.local/bin:$PATH uv run pytest tests/test_library.py -q
PATH=$HOME/.local/bin:$PATH uv run ruff check src tests
git add backend/src/ytmusic_api/routers/library.py backend/tests/test_library.py
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): GET /v1/library/history

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Flutter — add Drift dependencies

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/.gitignore` (if needed) — generated `.g.dart` files are committed per Flutter convention; nothing to add.

`drift_dev` ~2.20 is the codegen runner; `sqlite3_flutter_libs` is required so we ship a known-good SQLite. `path_provider` gets the app docs directory for the DB file.

- [ ] **Step 1: Edit `app/pubspec.yaml`**

Under `dependencies:`:

```yaml
  drift: ^2.20.3
  path_provider: ^2.1.5
  sqlite3_flutter_libs: ^0.5.26
```

Under `dev_dependencies:`:

```yaml
  drift_dev: ^2.20.3
```

- [ ] **Step 2: Resolve**

```bash
cd app
fvm flutter pub get
```
Expected: clean exit, `pubspec.lock` updated.

- [ ] **Step 3: Analyze**

```bash
fvm flutter analyze
```
Expected: no errors (the new deps aren't imported yet).

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
chore(app): add drift, drift_dev, path_provider, sqlite3_flutter_libs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Flutter — Drift schema, connection, and database (TDD)

**Files:**
- Create: `app/lib/core/db/tables.dart`
- Create: `app/lib/core/db/connection.dart`
- Create: `app/lib/core/db/database.dart`
- Create: `app/lib/core/db/db_providers.dart`
- Create: `app/test/core/db/database_test.dart`

This task is the **load-bearing one** of the Flutter side: the entire schema in spec §5 + indexes lands in one task because the tables reference each other and splitting would mean stub-then-amend churn. Tests verify schema by opening an in-memory DB and inspecting `sqlite_master`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/db/database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schema creates all expected tables', () async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND "
          "name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
        )
        .get();
    final tableNames = names.map((r) => r.read<String>('name')).toSet();
    expect(
      tableNames,
      containsAll(<String>{
        'tracks',
        'albums',
        'album_tracks',
        'artists',
        'playlists',
        'playlist_tracks',
        'recently_played',
        'sync_state',
        'settings',
      }),
    );
  });

  test('expected indexes exist', () async {
    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final idx = names.map((r) => r.read<String>('name')).toSet();
    expect(
      idx,
      containsAll(<String>{
        'tracks_download_status',
        'tracks_is_liked',
        'tracks_last_played',
        'tracks_album',
        'album_tracks_position',
        'playlist_tracks_position',
      }),
    );
  });
}
```

- [ ] **Step 2: Run to verify fail**

```bash
cd app
fvm flutter test test/core/db/database_test.dart
```
Expected: compile error — `AppDatabase` does not exist.

- [ ] **Step 3: Write `tables.dart`**

```dart
// app/lib/core/db/tables.dart
import 'package:drift/drift.dart';

class Tracks extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get artistBrowseId => text().nullable()();
  TextColumn get albumName => text().nullable()();
  TextColumn get albumBrowseId => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get likedAt => dateTime().nullable()();
  TextColumn get downloadStatus =>
      text().withDefault(const Constant('not_downloaded'))();
  IntColumn get downloadAttempts => integer().withDefault(const Constant(0))();
  TextColumn get lastDownloadError => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
  TextColumn get downloadedCodec => text().nullable()();
  IntColumn get downloadedBitrate => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}

class Albums extends Table {
  TextColumn get browseId => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get artistBrowseId => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  IntColumn get trackCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class AlbumTracks extends Table {
  TextColumn get albumBrowseId => text()();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {albumBrowseId, videoId};
}

class Artists extends Table {
  TextColumn get browseId => text()();
  TextColumn get name => text()();
  BoolColumn get subscribed => boolean().withDefault(const Constant(false))();
  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class Playlists extends Table {
  TextColumn get browseId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get ownerName => text().nullable()();
  BoolColumn get isOwn => boolean().withDefault(const Constant(true))();
  IntColumn get trackCount => integer().withDefault(const Constant(0))();
  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class PlaylistTracks extends Table {
  TextColumn get playlistBrowseId => text()();
  TextColumn get videoId => text()();
  TextColumn get setVideoId => text()();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {playlistBrowseId, setVideoId};
}

class RecentlyPlayed extends Table {
  TextColumn get videoId => text()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId, playedAt};
}

class SyncState extends Table {
  TextColumn get key => text()();
  DateTimeColumn get lastSyncedAt => dateTime()();
  TextColumn get etag => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

- [ ] **Step 4: Write `connection.dart`**

```dart
// app/lib/core/db/connection.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 5: Write `database.dart`**

```dart
// app/lib/core/db/database.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/connection.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Tracks,
    Albums,
    AlbumTracks,
    Artists,
    Playlists,
    PlaylistTracks,
    RecentlyPlayed,
    SyncState,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX tracks_download_status ON tracks(download_status)',
          );
          await customStatement(
            'CREATE INDEX tracks_is_liked ON tracks(is_liked) '
            'WHERE is_liked = 1',
          );
          await customStatement(
            'CREATE INDEX tracks_last_played ON tracks(last_played_at)',
          );
          await customStatement(
            'CREATE INDEX tracks_album ON tracks(album_browse_id)',
          );
          await customStatement(
            'CREATE INDEX album_tracks_position '
            'ON album_tracks(album_browse_id, position)',
          );
          await customStatement(
            'CREATE INDEX playlist_tracks_position '
            'ON playlist_tracks(playlist_browse_id, position)',
          );
        },
      );
}
```

- [ ] **Step 6: Write `db_providers.dart`**

```dart
// app/lib/core/db/db_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

- [ ] **Step 7: Run codegen**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```
Expected: writes `app/lib/core/db/database.g.dart`. No errors.

- [ ] **Step 8: Run tests**

```bash
fvm flutter test test/core/db/database_test.dart
```
Expected: 2 passed.

- [ ] **Step 9: Lint**

```bash
fvm flutter analyze
```
Expected: no errors. (If `lines_longer_than_80_chars` triggers on the long index DDL strings, break them across lines as shown.)

- [ ] **Step 10: Commit**

```bash
git add app/lib/core/db/ app/test/core/db/database_test.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): drift database schema (spec §5) — tables, indexes, migration

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Flutter — `TracksDao` (TDD)

**Files:**
- Create: `app/lib/core/db/daos/tracks_dao.dart`
- Create: `app/test/core/db/daos/tracks_dao_test.dart`
- Modify: `app/lib/core/db/database.dart` — register DAO

The library views need: upsert a track (network → DB), watch liked tracks, watch a list of tracks by id (for playlist detail), set/clear `isLiked`.

- [ ] **Step 1: Write failing tests**

```dart
// app/test/core/db/daos/tracks_dao_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/tracks_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late TracksDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.tracksDao;
  });
  tearDown(() async => db.close());

  TracksCompanion sample(String id, {bool liked = false}) => TracksCompanion.insert(
        videoId: id,
        title: 'Title $id',
        artistName: const Value('Artist'),
        durationMs: const Value(180000),
        isLiked: Value(liked),
      );

  test('upsertTrack inserts new and updates existing', () async {
    await dao.upsertTrack(sample('v1'));
    await dao.upsertTrack(sample('v1', liked: true));
    final row = await dao.getById('v1');
    expect(row, isNotNull);
    expect(row!.isLiked, isTrue);
  });

  test('watchLiked returns only liked tracks', () async {
    await dao.upsertTrack(sample('v1', liked: true));
    await dao.upsertTrack(sample('v2'));
    await dao.upsertTrack(sample('v3', liked: true));
    final first = await dao.watchLiked().first;
    expect(first.map((t) => t.videoId).toSet(), {'v1', 'v3'});
  });

  test('upsertManyTracks is batched and idempotent', () async {
    await dao.upsertManyTracks([sample('v1'), sample('v2')]);
    await dao.upsertManyTracks([sample('v2'), sample('v3')]);
    final all = await dao.allTracks();
    expect(all.map((t) => t.videoId).toSet(), {'v1', 'v2', 'v3'});
  });

  test('getByIds returns rows in same order as input ids', () async {
    await dao.upsertManyTracks([sample('a'), sample('b'), sample('c')]);
    final ordered = await dao.getByIds(['c', 'a', 'b']);
    expect(ordered.map((t) => t.videoId).toList(), ['c', 'a', 'b']);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
fvm flutter test test/core/db/daos/tracks_dao_test.dart
```
Expected: compile error — `tracksDao` does not exist on `AppDatabase`.

- [ ] **Step 3: Write the DAO**

```dart
// app/lib/core/db/daos/tracks_dao.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'tracks_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class TracksDao extends DatabaseAccessor<AppDatabase> with _$TracksDaoMixin {
  TracksDao(super.db);

  Future<void> upsertTrack(TracksCompanion row) =>
      into(tracks).insertOnConflictUpdate(row);

  Future<void> upsertManyTracks(List<TracksCompanion> rows) async {
    await batch((b) {
      for (final r in rows) {
        b.insert(tracks, r, onConflict: DoUpdate((_) => r));
      }
    });
  }

  Future<Track?> getById(String id) =>
      (select(tracks)..where((t) => t.videoId.equals(id))).getSingleOrNull();

  Future<List<Track>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (select(tracks)..where((t) => t.videoId.isIn(ids))).get();
    final byId = {for (final r in rows) r.videoId: r};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<List<Track>> allTracks() => select(tracks).get();

  Stream<List<Track>> watchLiked() {
    final q = select(tracks)
      ..where((t) => t.isLiked.equals(true))
      ..orderBy([(t) => OrderingTerm(expression: t.likedAt, mode: OrderingMode.desc)]);
    return q.watch();
  }
}
```

- [ ] **Step 4: Wire DAO into `database.dart`**

Add `daos: [TracksDao]` to the `@DriftDatabase` annotation:

```dart
@DriftDatabase(
  tables: [...],
  daos: [TracksDao],
)
```

And add the import: `import 'package:ytmusic/core/db/daos/tracks_dao.dart';`.

- [ ] **Step 5: Re-run codegen**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run tests + lint**

```bash
fvm flutter test test/core/db/daos/tracks_dao_test.dart
fvm flutter analyze
```
Expected: 4 passed; no analyzer errors.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/db/ app/test/core/db/daos/tracks_dao_test.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): TracksDao with upsert, watchLiked, getByIds

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Flutter — `PlaylistsDao` and `ArtistsDao` (TDD)

**Files:**
- Create: `app/lib/core/db/daos/playlists_dao.dart`
- Create: `app/lib/core/db/daos/artists_dao.dart`
- Create: `app/test/core/db/daos/playlists_dao_test.dart`
- Modify: `app/lib/core/db/database.dart` (register DAOs)

`PlaylistsDao` covers both `playlists` and `playlist_tracks` (they're never queried independently — playlist detail joins them, list view only touches `playlists`). `ArtistsDao` covers `artists` (subscribed=true filter for the subscriptions screen).

- [ ] **Step 1: Write failing tests**

```dart
// app/test/core/db/daos/playlists_dao_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/playlists_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late PlaylistsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.playlistsDao;
  });
  tearDown(() async => db.close());

  test('watchAll emits playlist summaries', () async {
    await dao.upsertPlaylist(
      PlaylistsCompanion.insert(browseId: 'PL1', title: 'Mix'),
    );
    final first = await dao.watchAll().first;
    expect(first.map((p) => p.browseId).toList(), ['PL1']);
  });

  test('replaceTracks rewrites the entire playlist track list', () async {
    await dao.upsertPlaylist(
      PlaylistsCompanion.insert(browseId: 'PL1', title: 'Mix'),
    );
    await dao.replaceTracks('PL1', [
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v1'),
        setVideoId: Value('s1'),
        position: Value(0),
      ),
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v2'),
        setVideoId: Value('s2'),
        position: Value(1),
      ),
    ]);
    var ids = await dao.tracksFor('PL1');
    expect(ids.map((t) => t.setVideoId).toList(), ['s1', 's2']);

    // Re-running with a different set must replace, not append:
    await dao.replaceTracks('PL1', [
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v3'),
        setVideoId: Value('s3'),
        position: Value(0),
      ),
    ]);
    ids = await dao.tracksFor('PL1');
    expect(ids.map((t) => t.setVideoId).toList(), ['s3']);
  });
}
```

- [ ] **Step 2: Run, verify fail. Then implement.**

```dart
// app/lib/core/db/daos/playlists_dao.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistTracks])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  Future<void> upsertPlaylist(PlaylistsCompanion row) =>
      into(playlists).insertOnConflictUpdate(row);

  Stream<List<Playlist>> watchAll() {
    final q = select(playlists)
      ..orderBy([(p) => OrderingTerm(expression: p.title)]);
    return q.watch();
  }

  Future<Playlist?> getById(String id) =>
      (select(playlists)..where((p) => p.browseId.equals(id))).getSingleOrNull();

  Future<List<PlaylistTrack>> tracksFor(String playlistBrowseId) {
    final q = select(playlistTracks)
      ..where((t) => t.playlistBrowseId.equals(playlistBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.get();
  }

  Stream<List<PlaylistTrack>> watchTracksFor(String playlistBrowseId) {
    final q = select(playlistTracks)
      ..where((t) => t.playlistBrowseId.equals(playlistBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.watch();
  }

  Future<void> replaceTracks(
    String playlistBrowseId,
    List<PlaylistTracksCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(playlistTracks)
            ..where((t) => t.playlistBrowseId.equals(playlistBrowseId)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(playlistTracks, rows));
    });
  }
}
```

```dart
// app/lib/core/db/daos/artists_dao.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'artists_dao.g.dart';

@DriftAccessor(tables: [Artists])
class ArtistsDao extends DatabaseAccessor<AppDatabase>
    with _$ArtistsDaoMixin {
  ArtistsDao(super.db);

  Future<void> upsertArtist(ArtistsCompanion row) =>
      into(artists).insertOnConflictUpdate(row);

  Future<void> upsertManyArtists(List<ArtistsCompanion> rows) =>
      batch((b) {
        for (final r in rows) {
          b.insert(artists, r, onConflict: DoUpdate((_) => r));
        }
      });

  Stream<List<Artist>> watchSubscribed() {
    final q = select(artists)
      ..where((a) => a.subscribed.equals(true))
      ..orderBy([(a) => OrderingTerm(expression: a.name)]);
    return q.watch();
  }
}
```

- [ ] **Step 3: Register DAOs**

In `database.dart`, expand `daos:`:

```dart
daos: [TracksDao, PlaylistsDao, ArtistsDao],
```

Add the imports.

- [ ] **Step 4: Codegen + test + lint + commit**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter test test/core/db/
fvm flutter analyze
git add app/lib/core/db/ app/test/core/db/
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): PlaylistsDao + ArtistsDao with replaceTracks transaction

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Flutter — `RecentlyPlayedDao` and `SyncStateDao` (TDD)

**Files:**
- Create: `app/lib/core/db/daos/recently_played_dao.dart`
- Create: `app/lib/core/db/daos/sync_state_dao.dart`
- Create: `app/test/core/db/daos/sync_state_dao_test.dart`
- Modify: `app/lib/core/db/database.dart`

`SyncStateDao` is the gatekeeper for "is this resource stale?" decisions made by the repository. `RecentlyPlayedDao` is server-driven only (spec §5.2 — we never log plays locally).

- [ ] **Step 1: Failing test**

```dart
// app/test/core/db/daos/sync_state_dao_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/sync_state_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late SyncStateDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.syncStateDao;
  });
  tearDown(() async => db.close());

  test('lastSyncedAt returns null when never synced', () async {
    expect(await dao.lastSyncedAt('library_liked'), isNull);
  });

  test('mark sets lastSyncedAt and is readable', () async {
    final t = DateTime.utc(2026, 4, 30, 10);
    await dao.mark('library_liked', at: t);
    expect(await dao.lastSyncedAt('library_liked'), t);
  });

  test('isFresh true when within ttl, false when stale', () async {
    final now = DateTime.utc(2026, 4, 30, 10);
    await dao.mark('library_liked', at: now);
    expect(
      await dao.isFresh(
        'library_liked',
        ttl: const Duration(minutes: 5),
        now: now.add(const Duration(minutes: 1)),
      ),
      isTrue,
    );
    expect(
      await dao.isFresh(
        'library_liked',
        ttl: const Duration(minutes: 5),
        now: now.add(const Duration(minutes: 6)),
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Implement**

```dart
// app/lib/core/db/daos/sync_state_dao.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<DateTime?> lastSyncedAt(String key) async {
    final row = await (select(syncState)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> mark(String key, {required DateTime at, String? etag}) {
    return into(syncState).insertOnConflictUpdate(
      SyncStateData(key: key, lastSyncedAt: at, etag: etag),
    );
  }

  Future<bool> isFresh(
    String key, {
    required Duration ttl,
    DateTime? now,
  }) async {
    final last = await lastSyncedAt(key);
    if (last == null) return false;
    final t = now ?? DateTime.now().toUtc();
    return t.difference(last) < ttl;
  }
}
```

```dart
// app/lib/core/db/daos/recently_played_dao.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'recently_played_dao.g.dart';

@DriftAccessor(tables: [RecentlyPlayed, Tracks])
class RecentlyPlayedDao extends DatabaseAccessor<AppDatabase>
    with _$RecentlyPlayedDaoMixin {
  RecentlyPlayedDao(super.db);

  Future<void> replaceAll(List<RecentlyPlayedCompanion> rows) async {
    await transaction(() async {
      await delete(recentlyPlayed).go();
      if (rows.isNotEmpty) {
        await batch((b) => b.insertAll(recentlyPlayed, rows));
      }
    });
  }

  Stream<List<RecentlyPlayedData>> watchAll() {
    final q = select(recentlyPlayed)
      ..orderBy([
        (r) => OrderingTerm(expression: r.playedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }
}
```

- [ ] **Step 3: Wire, codegen, test, commit**

Update `database.dart` daos list, run `build_runner build`, `fvm flutter test test/core/db/`, `fvm flutter analyze`.

```bash
git add app/lib/core/db/ app/test/core/db/daos/sync_state_dao_test.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): SyncStateDao with isFresh + RecentlyPlayedDao

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Flutter — `ApiClient` library methods + dart models (TDD)

**Files:**
- Create: `app/lib/core/api/models/library_models.dart`
- Modify: `app/lib/core/api/api_client.dart`
- Create: `app/test/core/api/api_client_library_test.dart`

Test against `dio` with `MockAdapter` (already used elsewhere) or a request-recording adapter — pattern matches Phase 1 tests. Methods: `getLikedSongs({int limit})`, `getPlaylists()`, `getPlaylistDetail(String id, {String? continuation})`, `getSubscriptions()`, `getHistory()`. **Lesson 1 (extension methods unmockable)**: put these on the class body, NOT in the existing `ApiClientCatalog` extension. Also note the existing `api_client.dart` has accidentally duplicated `search`/`getTrack`/`resolveStream` between the class body and an extension; fix that drift in this task by removing the duplicate extension entirely.

- [ ] **Step 1: Write the dart models**

```dart
// app/lib/core/api/models/library_models.dart
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

class LikedSong {
  LikedSong({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory LikedSong.fromJson(Map<String, dynamic> j) => LikedSong(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
}

class PagedLikedSongs {
  PagedLikedSongs({required this.items, this.continuation});

  factory PagedLikedSongs.fromJson(Map<String, dynamic> j) => PagedLikedSongs(
        items: (j['items'] as List)
            .map((e) => LikedSong.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<LikedSong> items;
  final String? continuation;
}

class PlaylistSummary {
  PlaylistSummary({
    required this.browseId,
    required this.title,
    required this.isOwn,
    this.description,
    this.trackCount,
    this.thumbnail,
  });

  factory PlaylistSummary.fromJson(Map<String, dynamic> j) => PlaylistSummary(
        browseId: j['browseId'] as String,
        title: j['title'] as String,
        isOwn: j['isOwn'] as bool? ?? true,
        description: j['description'] as String?,
        trackCount: j['trackCount'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String browseId;
  final String title;
  final bool isOwn;
  final String? description;
  final int? trackCount;
  final Thumbnail? thumbnail;
}

class PagedPlaylists {
  PagedPlaylists({required this.items, this.continuation});

  factory PagedPlaylists.fromJson(Map<String, dynamic> j) => PagedPlaylists(
        items: (j['items'] as List)
            .map((e) => PlaylistSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<PlaylistSummary> items;
  final String? continuation;
}

class PlaylistTrackInfo {
  PlaylistTrackInfo({
    required this.videoId,
    required this.title,
    this.setVideoId,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory PlaylistTrackInfo.fromJson(Map<String, dynamic> j) =>
      PlaylistTrackInfo(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        setVideoId: j['setVideoId'] as String?,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String videoId;
  final String title;
  final String? setVideoId;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
}

class PlaylistDetail {
  PlaylistDetail({
    required this.browseId,
    required this.title,
    required this.items,
    this.description,
    this.ownerName,
    this.trackCount,
    this.continuation,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) => PlaylistDetail(
        browseId: j['browseId'] as String,
        title: j['title'] as String,
        items: (j['items'] as List)
            .map((e) => PlaylistTrackInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        description: j['description'] as String?,
        ownerName: j['ownerName'] as String?,
        trackCount: j['trackCount'] as int?,
        continuation: j['continuation'] as String?,
      );

  final String browseId;
  final String title;
  final List<PlaylistTrackInfo> items;
  final String? description;
  final String? ownerName;
  final int? trackCount;
  final String? continuation;
}

class ArtistSubscription {
  ArtistSubscription({
    required this.browseId,
    required this.name,
    this.subscriberCount,
    this.thumbnail,
  });

  factory ArtistSubscription.fromJson(Map<String, dynamic> j) =>
      ArtistSubscription(
        browseId: j['browseId'] as String,
        name: j['name'] as String,
        subscriberCount: j['subscriberCount'] as String?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String browseId;
  final String name;
  final String? subscriberCount;
  final Thumbnail? thumbnail;
}

class PagedSubscriptions {
  PagedSubscriptions({required this.items, this.continuation});

  factory PagedSubscriptions.fromJson(Map<String, dynamic> j) =>
      PagedSubscriptions(
        items: (j['items'] as List)
            .map((e) => ArtistSubscription.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<ArtistSubscription> items;
  final String? continuation;
}

class HistoryItem {
  HistoryItem({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
    this.playedSection,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
        playedSection: j['playedSection'] as String?,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
  final String? playedSection;
}

class PagedHistory {
  PagedHistory({required this.items, this.continuation});

  factory PagedHistory.fromJson(Map<String, dynamic> j) => PagedHistory(
        items: (j['items'] as List)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<HistoryItem> items;
  final String? continuation;
}
```

- [ ] **Step 2: Failing tests**

```dart
// app/test/core/api/api_client_library_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  ResponseBody? response;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    return response!;
  }
}

ApiClient _client(_RecordingAdapter adapter) {
  final c = ApiClient(
    config: ApiConfig(
      baseUrl: 'https://api.local',
      cfAccessClientId: 'id',
      cfAccessClientSecret: 'secret',
    ),
  );
  c.dio.httpClientAdapter = adapter;
  return c;
}

ResponseBody _ok(String body) => ResponseBody.fromString(
      body,
      200,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  test('getLikedSongs hits /v1/library/liked', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[{"videoId":"v1","title":"T"}],'
          '"continuation":null}');
    final c = _client(a);
    final page = await c.getLikedSongs();
    expect(a.lastPath, '/v1/library/liked');
    expect(page.items.first.videoId, 'v1');
    expect(page.continuation, isNull);
  });

  test('getPlaylistDetail forwards continuation token', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"browseId":"PL1","title":"M","items":[],'
          '"continuation":null}');
    final c = _client(a);
    await c.getPlaylistDetail('PL1', continuation: 'tok');
    expect(a.lastPath, '/v1/library/playlists/PL1');
    expect(a.lastQuery!['continuation'], 'tok');
  });

  test('getSubscriptions hits the right path', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[],"continuation":null}');
    final c = _client(a);
    await c.getSubscriptions();
    expect(a.lastPath, '/v1/library/subscriptions');
  });
}
```

- [ ] **Step 3: Implement on `ApiClient` class body (NOT extension)**

Edit `app/lib/core/api/api_client.dart`:

1. Add the import: `import 'package:ytmusic/core/api/models/library_models.dart';`
2. **Delete** the `extension ApiClientCatalog on ApiClient { ... }` block at the bottom — its three methods are duplicates of class methods (lesson 1 cleanup).
3. Add to the class body:

```dart
  Future<PagedLikedSongs> getLikedSongs({int limit = 200}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/library/liked',
      queryParameters: {'limit': limit},
    );
    return PagedLikedSongs.fromJson(res.data!);
  }

  Future<PagedPlaylists> getPlaylists() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/library/playlists');
    return PagedPlaylists.fromJson(res.data!);
  }

  Future<PlaylistDetail> getPlaylistDetail(
    String browseId, {
    String? continuation,
  }) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/library/playlists/$browseId',
      queryParameters: {
        if (continuation != null) 'continuation': continuation,
      },
    );
    return PlaylistDetail.fromJson(res.data!);
  }

  Future<PagedSubscriptions> getSubscriptions() async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/library/subscriptions',
    );
    return PagedSubscriptions.fromJson(res.data!);
  }

  Future<PagedHistory> getHistory() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/library/history');
    return PagedHistory.fromJson(res.data!);
  }
```

Wrap each in the same `try/on DioException catch (e)` shape as the existing methods.

- [ ] **Step 4: Test, lint, commit**

```bash
fvm flutter test test/core/api/api_client_library_test.dart
fvm flutter analyze
git add app/lib/core/api/ app/test/core/api/api_client_library_test.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): ApiClient library methods + remove duplicate ApiClientCatalog ext

Removed the ApiClientCatalog extension — its methods were already on
the class body, leaving them as an extension blocked mocktail (extension
methods are statically dispatched and cannot be mocked).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Flutter — `LibraryRepository` (TDD)

**Files:**
- Create: `app/lib/core/library/library_repository.dart`
- Create: `app/lib/core/library/library_providers.dart`
- Create: `app/test/core/library/library_repository_test.dart`

The repository's job: each list screen exposes a `Stream<...>` from Drift; the screen also calls `repo.refresh<X>()` on first build (when stale per `SyncStateDao.isFresh`) and on pull-to-refresh. The repo writes through API → Drift in a single transaction so the stream re-emits once.

`syncStateKey` strings (matched between repo and DAO):
- `library_liked`
- `library_playlists`
- `library_subscriptions`
- `library_history`
- `playlist:<browseId>`

Stale TTL: 1 hour for all (network-cheap; user's pull-to-refresh covers immediacy).

- [ ] **Step 1: Failing tests**

```dart
// app/test/core/library/library_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;
  late LibraryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    repo = LibraryRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  test('refreshLiked upserts tracks and marks isLiked=true', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [LikedSong(videoId: 'v1', title: 'T', artistName: 'A')],
      ),
    );
    await repo.refreshLiked();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked.map((t) => t.videoId).toList(), ['v1']);
  });

  test('refreshLiked clears isLiked for tracks no longer liked', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [LikedSong(videoId: 'v1', title: 'T')],
      ),
    );
    await repo.refreshLiked();
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
    await repo.refreshLiked();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked, isEmpty);
  });

  test('refreshLikedIfStale skips network when fresh', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
    await repo.refreshLiked();
    clearInteractions(api);
    await repo.refreshLikedIfStale();
    verifyNever(() => api.getLikedSongs(limit: any(named: 'limit')));
  });

  test('refreshPlaylistDetail replaces tracks atomically', () async {
    when(() => api.getPlaylistDetail('PL1')).thenAnswer(
      (_) async => PlaylistDetail(
        browseId: 'PL1',
        title: 'Mix',
        items: [
          PlaylistTrackInfo(videoId: 'v1', setVideoId: 's1', title: 'T1'),
          PlaylistTrackInfo(videoId: 'v2', setVideoId: 's2', title: 'T2'),
        ],
      ),
    );
    await repo.refreshPlaylistDetail('PL1');
    final tracks = await db.playlistsDao.tracksFor('PL1');
    expect(tracks.map((t) => t.setVideoId).toList(), ['s1', 's2']);
  });
}
```

- [ ] **Step 2: Implement**

```dart
// app/lib/core/library/library_repository.dart
import 'package:drift/drift.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';

class LibraryRepository {
  LibraryRepository({required this.db, required this.api});

  final AppDatabase db;
  final ApiClient api;

  static const Duration _staleTtl = Duration(hours: 1);

  Future<void> refreshLiked() async {
    final page = await api.getLikedSongs();
    final now = DateTime.now().toUtc();
    final newIds = page.items.map((s) => s.videoId).toSet();

    await db.transaction(() async {
      // Clear isLiked from anything not in the new set:
      await db.customStatement(
        'UPDATE tracks SET is_liked = 0 '
        'WHERE is_liked = 1 AND video_id NOT IN '
        '(${newIds.isEmpty ? "''" : newIds.map((_) => '?').join(',')})',
        newIds.isEmpty ? const [] : newIds.toList(),
      );
      // Upsert each liked track with isLiked=true:
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
  }

  Future<void> refreshLikedIfStale() =>
      _ifStale('library_liked', refreshLiked);

  Future<void> refreshPlaylists() async {
    final page = await api.getPlaylists();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      // Replace the playlist set (delete missing, upsert present):
      final newIds = page.items.map((p) => p.browseId).toSet();
      await db.customStatement(
        'DELETE FROM playlists '
        'WHERE browse_id NOT IN '
        '(${newIds.isEmpty ? "''" : newIds.map((_) => '?').join(',')})',
        newIds.isEmpty ? const [] : newIds.toList(),
      );
      for (final p in page.items) {
        await db.playlistsDao.upsertPlaylist(PlaylistsCompanion.insert(
          browseId: p.browseId,
          title: p.title,
          description: Value(p.description),
          isOwn: Value(p.isOwn),
          trackCount: Value(p.trackCount ?? 0),
          artworkUrl: Value(p.thumbnail?.url),
          lastSyncedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_playlists', at: now);
    });
  }

  Future<void> refreshPlaylistsIfStale() =>
      _ifStale('library_playlists', refreshPlaylists);

  Future<void> refreshPlaylistDetail(String browseId) async {
    final detail = await api.getPlaylistDetail(browseId);
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.playlistsDao.upsertPlaylist(PlaylistsCompanion.insert(
        browseId: detail.browseId,
        title: detail.title,
        description: Value(detail.description),
        ownerName: Value(detail.ownerName),
        trackCount: Value(detail.trackCount ?? detail.items.length),
        lastSyncedAt: Value(now),
      ));
      // Upsert the underlying track rows so detail page can render:
      for (final t in detail.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: t.videoId,
          title: t.title,
          artistName: Value(t.artistName),
          albumName: Value(t.albumName),
          albumBrowseId: Value(t.albumBrowseId),
          durationMs: Value(t.durationMs),
          artworkUrl: Value(t.thumbnail?.url),
        ));
      }
      await db.playlistsDao.replaceTracks(
        browseId,
        [
          for (var i = 0; i < detail.items.length; i++)
            PlaylistTracksCompanion.insert(
              playlistBrowseId: browseId,
              videoId: detail.items[i].videoId,
              setVideoId: detail.items[i].setVideoId ?? detail.items[i].videoId,
              position: i,
            ),
        ],
      );
      await db.syncStateDao.mark('playlist:$browseId', at: now);
    });
  }

  Future<void> refreshPlaylistDetailIfStale(String browseId) =>
      _ifStale('playlist:$browseId', () => refreshPlaylistDetail(browseId));

  Future<void> refreshSubscriptions() async {
    final page = await api.getSubscriptions();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      // Clear subscribed flag from artists no longer in the list:
      final newIds = page.items.map((a) => a.browseId).toSet();
      await db.customStatement(
        'UPDATE artists SET subscribed = 0 '
        'WHERE subscribed = 1 AND browse_id NOT IN '
        '(${newIds.isEmpty ? "''" : newIds.map((_) => '?').join(',')})',
        newIds.isEmpty ? const [] : newIds.toList(),
      );
      for (final a in page.items) {
        await db.artistsDao.upsertArtist(ArtistsCompanion.insert(
          browseId: a.browseId,
          name: a.name,
          subscribed: const Value(true),
          artworkUrl: Value(a.thumbnail?.url),
          lastSyncedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_subscriptions', at: now);
    });
  }

  Future<void> refreshSubscriptionsIfStale() =>
      _ifStale('library_subscriptions', refreshSubscriptions);

  Future<void> refreshHistory() async {
    final page = await api.getHistory();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      for (final h in page.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: h.videoId,
          title: h.title,
          artistName: Value(h.artistName),
          albumName: Value(h.albumName),
          albumBrowseId: Value(h.albumBrowseId),
          durationMs: Value(h.durationMs),
          artworkUrl: Value(h.thumbnail?.url),
        ));
      }
      await db.recentlyPlayedDao.replaceAll([
        for (var i = 0; i < page.items.length; i++)
          RecentlyPlayedCompanion.insert(
            videoId: page.items[i].videoId,
            // Synthetic timestamp so sort-desc preserves API order:
            playedAt: now.subtract(Duration(seconds: i)),
          ),
      ]);
      await db.syncStateDao.mark('library_history', at: now);
    });
  }

  Future<void> refreshHistoryIfStale() =>
      _ifStale('library_history', refreshHistory);

  Future<void> _ifStale(String key, Future<void> Function() refresh) async {
    if (await db.syncStateDao.isFresh(key, ttl: _staleTtl)) return;
    await refresh();
  }
}
```

```dart
// app/lib/core/library/library_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(apiClientProvider),
  );
});
```

- [ ] **Step 3: Test, lint, commit**

```bash
fvm flutter test test/core/library/
fvm flutter analyze
git add app/lib/core/library/ app/test/core/library/
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): LibraryRepository — sync API → Drift with TTL gating

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Flutter — shared `TrackListTile` widget

**Files:**
- Create: `app/lib/features/library/widgets/track_list_tile.dart`

A small, dumb widget used by liked / playlist-detail / history screens. Displays artwork + title + artist; on tap calls a `VoidCallback`. No tests beyond a smoke widget test.

- [ ] **Step 1: Implement**

```dart
// app/lib/features/library/widgets/track_list_tile.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TrackListTile extends StatelessWidget {
  const TrackListTile({
    required this.title,
    this.artist,
    this.artworkUrl,
    this.onTap,
    super.key,
  });

  final String title;
  final String? artist;
  final String? artworkUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: artworkUrl == null
            ? const ColoredBox(color: Colors.black26)
            : CachedNetworkImage(imageUrl: artworkUrl!, fit: BoxFit.cover),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: artist == null
          ? null
          : Text(artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 2: Lint + commit**

```bash
fvm flutter analyze
git add app/lib/features/library/widgets/
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): shared TrackListTile widget for library lists

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Flutter — `LikedSongsScreen` (TDD)

**Files:**
- Create: `app/lib/features/library/liked_songs_screen.dart`
- Create: `app/test/features/library/liked_songs_screen_test.dart`

Streams `db.tracksDao.watchLiked()` directly. Triggers `refreshLikedIfStale()` on first build via `ref.read(...)`. Pull-to-refresh calls `refreshLiked()`. Tap calls the existing audio handler — same pattern as `SearchScreen`.

- [ ] **Step 1: Failing widget test**

```dart
// app/test/features/library/liked_songs_screen_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/library/liked_songs_screen.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  testWidgets('renders liked tracks streamed from Drift', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = _MockApi();
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(items: [
        LikedSong(videoId: 'v1', title: 'Hello', artistName: 'World'),
      ]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: LikedSongsScreen()),
      ),
    );
    // First frame: empty state. Pump until refresh + stream emits.
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    addTearDown(db.close);
  });
}
```

- [ ] **Step 2: Implement**

```dart
// app/lib/features/library/liked_songs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final _likedStreamProvider = StreamProvider.autoDispose<List<Track>>((ref) {
  return ref.watch(appDatabaseProvider).tracksDao.watchLiked();
});

class LikedSongsScreen extends ConsumerStatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  ConsumerState<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends ConsumerState<LikedSongsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(libraryRepositoryProvider).refreshLikedIfStale(),
    );
  }

  Future<void> _refresh() =>
      ref.read(libraryRepositoryProvider).refreshLiked();

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(_likedStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Liked songs')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: tracks.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(16), child: Text('$e'))],
          ),
          data: (rows) => rows.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No liked songs yet.')),
                ])
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final t = rows[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () =>
                          ref.read(audioHandlerProvider).playVideoId(t.videoId),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
```

> Note: `playVideoId` should already exist on `AudioPlaybackHandler` (used by `SearchScreen`). If the method has a different name in the current code, use the same call-site shape that `search_screen.dart` uses.

- [ ] **Step 3: Test, lint, commit**

```bash
fvm flutter test test/features/library/liked_songs_screen_test.dart
fvm flutter analyze
git add app/lib/features/library/ app/test/features/library/
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): LikedSongsScreen — Drift stream + pull-to-refresh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Flutter — `PlaylistsScreen` (titles list)

**Files:**
- Create: `app/lib/features/library/playlists_screen.dart`

Same shape as Liked screen but using `playlistsDao.watchAll()` and `refreshPlaylistsIfStale()` / `refreshPlaylists()`. Tap navigates to `/library/playlists/<browseId>`.

- [ ] **Step 1: Implement**

```dart
// app/lib/features/library/playlists_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final _playlistsStreamProvider =
    StreamProvider.autoDispose<List<Playlist>>((ref) {
  return ref.watch(appDatabaseProvider).playlistsDao.watchAll();
});

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(libraryRepositoryProvider).refreshPlaylistsIfStale(),
    );
  }

  Future<void> _refresh() =>
      ref.read(libraryRepositoryProvider).refreshPlaylists();

  @override
  Widget build(BuildContext context) {
    final pls = ref.watch(_playlistsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: pls.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Text('$e')]),
          data: (rows) => ListView.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) {
              final p = rows[i];
              return TrackListTile(
                title: p.title,
                artist: p.trackCount > 0 ? '${p.trackCount} tracks' : null,
                artworkUrl: p.artworkUrl,
                onTap: () => context.go('/library/playlists/${p.browseId}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Lint + commit**

```bash
fvm flutter analyze
git add app/lib/features/library/playlists_screen.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): PlaylistsScreen with tap-through to detail

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: Flutter — `PlaylistDetailScreen`

**Files:**
- Create: `app/lib/features/library/playlist_detail_screen.dart`

Streams `playlistsDao.watchTracksFor(browseId)`, hydrates each `PlaylistTrack` row's metadata via `tracksDao.getByIds(...)`. On first build, `refreshPlaylistDetailIfStale(browseId)`. Tap a row → playback handler.

- [ ] **Step 1: Implement**

```dart
// app/lib/features/library/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.browseId, super.key});

  final String browseId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends ConsumerState<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(libraryRepositoryProvider)
          .refreshPlaylistDetailIfStale(widget.browseId),
    );
  }

  Future<void> _refresh() => ref
      .read(libraryRepositoryProvider)
      .refreshPlaylistDetail(widget.browseId);

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final stream = db.playlistsDao.watchTracksFor(widget.browseId);
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<PlaylistTrackData>>(
          stream: stream,
          builder: (ctx, snap) {
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No tracks.')),
              ]);
            }
            return FutureBuilder<List<Track>>(
              future:
                  db.tracksDao.getByIds(rows.map((r) => r.videoId).toList()),
              builder: (ctx, ts) {
                final tracks = ts.data ?? const [];
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (ctx, i) {
                    final t = tracks[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => ref
                          .read(audioHandlerProvider)
                          .playVideoId(t.videoId),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

> Drift's generated row class for `PlaylistTracks` is `PlaylistTrack`; the table data class is `PlaylistTrackData` if there's a name collision with the dart model — confirm in `database.g.dart` after codegen and adjust the import. If Drift names the class `PlaylistTrack` and the dart wire model is also `PlaylistTrack`, alias one of the imports.

- [ ] **Step 2: Lint + commit**

```bash
fvm flutter analyze
git add app/lib/features/library/playlist_detail_screen.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): PlaylistDetailScreen — Drift stream of playlist rows

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: Flutter — `SubscriptionsScreen`

**Files:**
- Create: `app/lib/features/library/subscriptions_screen.dart`

Same pattern: stream `artistsDao.watchSubscribed()`, refresh on init + pull. Tap is a no-op for now (artist detail is Phase 3) — log only.

- [ ] **Step 1: Implement**

```dart
// app/lib/features/library/subscriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final _subsStreamProvider = StreamProvider.autoDispose<List<Artist>>((ref) {
  return ref.watch(appDatabaseProvider).artistsDao.watchSubscribed();
});

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(libraryRepositoryProvider).refreshSubscriptionsIfStale(),
    );
  }

  Future<void> _refresh() =>
      ref.read(libraryRepositoryProvider).refreshSubscriptions();

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(_subsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: subs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Text('$e')]),
          data: (rows) => ListView.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) {
              final a = rows[i];
              return TrackListTile(
                title: a.name,
                artworkUrl: a.artworkUrl,
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Lint + commit**

```bash
fvm flutter analyze
git add app/lib/features/library/subscriptions_screen.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): SubscriptionsScreen reading from Drift

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: Flutter — `HistoryScreen`

**Files:**
- Create: `app/lib/features/library/history_screen.dart`

Joins `recently_played` × `tracks` via `tracksDao.getByIds(...)` keyed off the played-at-desc list. Tap → playback.

- [ ] **Step 1: Implement**

```dart
// app/lib/features/library/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(libraryRepositoryProvider).refreshHistoryIfStale(),
    );
  }

  Future<void> _refresh() =>
      ref.read(libraryRepositoryProvider).refreshHistory();

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<RecentlyPlayedData>>(
          stream: db.recentlyPlayedDao.watchAll(),
          builder: (ctx, snap) {
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No history yet.')),
              ]);
            }
            return FutureBuilder<List<Track>>(
              future:
                  db.tracksDao.getByIds(rows.map((r) => r.videoId).toList()),
              builder: (ctx, ts) {
                final tracks = ts.data ?? const [];
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (ctx, i) {
                    final t = tracks[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => ref
                          .read(audioHandlerProvider)
                          .playVideoId(t.videoId),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Lint + commit**

```bash
fvm flutter analyze
git add app/lib/features/library/history_screen.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): HistoryScreen reading from Drift

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 21: Flutter — `LibraryHubScreen` + routing wireup

**Files:**
- Create: `app/lib/features/library/library_hub_screen.dart`
- Modify: `app/lib/routing/app_router.dart` — add 6 routes
- Modify: `app/lib/features/search/search_screen.dart` — add an AppBar action `IconButton(icon: Icons.library_music)` that calls `context.go('/library')`

The hub is a 4-tile menu: Liked songs / Playlists / Subscriptions / History.

- [ ] **Step 1: Implement hub**

```dart
// app/lib/features/library/library_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Liked songs'),
            onTap: () => context.go('/library/liked'),
          ),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Playlists'),
            onTap: () => context.go('/library/playlists'),
          ),
          ListTile(
            leading: const Icon(Icons.subscriptions),
            title: const Text('Subscriptions'),
            onTap: () => context.go('/library/subscriptions'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            onTap: () => context.go('/library/history'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add routes**

In `app/lib/routing/app_router.dart`, append to the `routes:` list:

```dart
GoRoute(
  path: '/library',
  builder: (context, state) => const LibraryHubScreen(),
),
GoRoute(
  path: '/library/liked',
  builder: (context, state) => const LikedSongsScreen(),
),
GoRoute(
  path: '/library/playlists',
  builder: (context, state) => const PlaylistsScreen(),
),
GoRoute(
  path: '/library/playlists/:id',
  builder: (context, state) =>
      PlaylistDetailScreen(browseId: state.pathParameters['id']!),
),
GoRoute(
  path: '/library/subscriptions',
  builder: (context, state) => const SubscriptionsScreen(),
),
GoRoute(
  path: '/library/history',
  builder: (context, state) => const HistoryScreen(),
),
```

Add the imports for the six screen classes at the top of the file.

- [ ] **Step 3: Add Library button to SearchScreen AppBar**

Inside `search_screen.dart`'s `AppBar(...)`, append `actions:`:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.library_music),
    onPressed: () => context.go('/library'),
  ),
],
```

Add `import 'package:go_router/go_router.dart';` if not already present.

- [ ] **Step 4: Smoke test, lint, commit**

```bash
fvm flutter test
fvm flutter analyze
git add app/lib/features/library/library_hub_screen.dart \
  app/lib/routing/app_router.dart \
  app/lib/features/search/search_screen.dart
git -c gpg.gpgsign=false commit -m "$(cat <<'EOF'
feat(app): library hub + routes; Library button on search AppBar

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist (pre-execution)

- [x] **Spec coverage:**
  - `/v1/library/liked` → Task 3
  - `/v1/library/playlists` → Task 4
  - `/v1/library/playlists/{id}` (continuation) → Task 5
  - `/v1/library/subscriptions` → Task 6
  - `/v1/library/history` → Task 7
  - Drift schema (spec §5: 9 tables + 6 indexes) → Task 9
  - DAOs that repositories consume → Tasks 10–12
  - Library screens (liked / playlists list / playlist detail / history / subscribed artists) → Tasks 16–20
  - `sync_state` per-resource last-synced-at + opaque etag → Task 9 (table) + Task 12 (DAO) + Task 14 (repo TTL gating)
  - Pull-to-refresh on each list invalidates and re-syncs → Tasks 16–20 (`onRefresh` calls direct refresh, not `*IfStale`)
  - **Server-side caching: never** for `/library/*` — confirmed in Task 3's `test_liked_is_not_cached_server_side`; library router shares `TtlCache` only because it's bound to `app.state` but never reads/writes it. ✓

- [x] **Out-of-scope respect:**
  - No `pending_mutations` table (option B deferred). ✓
  - No `/library/snapshot`. ✓
  - No write endpoints. ✓
  - No album/artist detail screens — subscriptions is title-only, no tap-through. ✓
  - No track detail screen — list rows tap to play. ✓

- [x] **Hard-won lessons applied:**
  - Lesson 1 (extension methods unmockable): library API methods land on the class body in Task 13; the duplicate `ApiClientCatalog` extension is removed in the same task.
  - Lesson 5 (Riverpod scoping): no new `ProviderScope` overrides — providers live in the existing single `ProviderContainer`. ✓

- [x] **Type consistency:** `videoId` is `String` everywhere; `setVideoId` is nullable on the API model (ytmusicapi may omit it for the liked-songs auto-playlist) but defaulted to `videoId` when persisted into `playlist_tracks`. `browseId` is `String` for albums/artists/playlists. `Thumbnail` lives in `library_models.dart` for the app side and is reused from `models/catalog.py` on the backend. ✓

- [x] **No placeholders:** every step contains either explicit code, a verbatim shell command, or a precise edit instruction. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-30-phase-2-library-and-drift.md`. Two execution options:**

1. **Subagent-Driven (recommended for this project)** — fresh general-purpose subagent per task with the embedded code, two-stage review (spec compliance + code quality) on load-bearing tasks (3, 5, 9, 13, 14), single commit per task amended on review feedback, stacked PRs onto `main`.
2. **Inline Execution** — run all tasks in this session with checkpoints after Tasks 7 (backend complete), 12 (Drift+DAOs complete), and 14 (repository complete).

The user's per-task workflow (worktree → general-purpose subagent → review → push → `gh pr checks --watch`) matches option 1, so default to that on approval.
