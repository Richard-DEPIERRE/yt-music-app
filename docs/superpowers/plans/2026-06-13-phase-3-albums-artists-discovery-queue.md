# Phase 3: Albums, Artists, Discovery & Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add album/artist detail screens, a home discovery feed, a multi-track playback queue, and radio autoplay — completing the read-only browsing experience on top of the Phase 0–2 foundation.

**Architecture:** Five new backend endpoints (`/album/{browseId}`, `/artist/{browseId}`, `/home`, `/radio`, `/up-next`) follow the existing FastAPI router → `YTMusicClient` (async `to_thread`) → pydantic-model pattern, with TTL caching (24h metadata, 5min home/radio). The app adds a `CatalogRepository` that syncs album/artist metadata into the existing Drift `albums`/`album_tracks`/`artists` tables, new detail/home screens (Riverpod `ConsumerStatefulWidget` + Drift streams), and a queue-capable `AudioPlaybackHandler` driving `audio_service`'s queue. Radio autoplay loads an `/up-next` queue when a single track starts.

**Tech Stack:** Python 3.12 + FastAPI + ytmusicapi + pydantic (backend); Flutter 3.41 (fvm) + Riverpod + Drift + go_router + just_audio + audio_service (app). TDD throughout; `uv run pytest` (backend) and `fvm flutter test` (app).

**This plan has three independently-shippable parts:**
- **Part A — Album & Artist detail** (Tasks A1–A12): catalog read endpoints + detail screens + search tap-through.
- **Part B — Discovery: Queue & Radio** (Tasks B1–B9): `/radio`, `/up-next`, multi-track queue in the audio handler, radio autoplay, queue UI.
- **Part C — Home feed** (Tasks C1–C7): `/home` endpoint + home screen.

Each part ends with working, tested software. Ship after any part.

---

## Reference: ytmusicapi return shapes (verified against ytmusicapi 1.11.5)

These are the upstream dict shapes the normalizers below target. Quoted from the installed `ytmusicapi/mixins` docstrings.

**`get_album(browseId)`** → dict:
```
{ "title", "type", "thumbnails": [...], "description", "year": "2017" (str),
  "trackCount": 19, "duration": "1 hour…", "audioPlaylistId": "OLAK5uy_…",
  "artists": [{"name","id"}],
  "tracks": [{"videoId","title","artists":[{"name","id"}],"album": "Revival" (str),
              "duration_seconds": 303, "trackNumber": 0, "thumbnails": null}] }
```

**`get_artist(channelId)`** → dict:
```
{ "name", "channelId", "description", "subscribers": "3.86M", "radioId": "RDEM…",
  "thumbnails": [...], "subscribed": false,
  "songs": {"browseId": "VL…", "results": [{"videoId","title","thumbnails","artist","album"}]},
  "albums": {"results": [{"title","thumbnails","year","browseId"}], "browseId", "params"},
  "singles": {"results": [{"title","thumbnails","year","browseId"}], ...} }
```

**`get_watch_playlist(videoId=, radio=, limit=)`** → dict (used for `/radio` and `/up-next`):
```
{ "tracks": [{"videoId","title","length": "3:07" (str, NO duration_seconds),
              "thumbnail": [...] (NOTE: singular key, list value),
              "artists": [{"name","id"}], "album": {"name","id"}, "year", "videoType"}] }
```
⚠️ Watch tracks use `length` (string) not `duration_seconds`, and `thumbnail` (singular) not `thumbnails`. The normalizer handles both.

**`get_home(limit=3)`** → list of rows:
```
[ {"title": "Your morning music",
   "contents": [ {"title","browseId","thumbnails"}            // album
                 {"title","playlistId","thumbnails","count"}  // playlist
                 {"title","browseId","subscribers","thumbnails"} // artist
                 {"title","videoId","artists":[{"name","id"}],"thumbnails"} ]} ]  // song
```

---

## File Structure

**Backend (create / modify):**
- Modify `backend/src/ytmusic_api/models/catalog.py` — add `AlbumTrack`, `AlbumDetailResponse`, `ArtistTopSong`, `ArtistAlbum`, `ArtistDetailResponse`.
- Create `backend/src/ytmusic_api/models/discovery.py` — `QueueItem`, `QueueResponse`, `HomeItem`, `HomeSection`, `HomeResponse`.
- Modify `backend/src/ytmusic_api/services/ytmusic_client.py` — add `get_album`, `get_artist`, `get_watch_playlist`, `get_home`.
- Modify `backend/src/ytmusic_api/routers/catalog.py` — add `/album/{browse_id}`, `/artist/{browse_id}`.
- Create `backend/src/ytmusic_api/routers/discovery.py` — `/home`, `/radio`, `/up-next`.
- Modify `backend/src/ytmusic_api/main.py` — register `discovery.router`.
- Create `backend/tests/test_album_artist.py`, `backend/tests/test_discovery.py`.

**App (create / modify):**
- Create `app/lib/core/api/models/album_detail.dart`, `artist_detail.dart`, `queue_item.dart`, `home_feed.dart`.
- Modify `app/lib/core/api/api_client.dart` — `getAlbum`, `getArtist`, `getRadio`, `getUpNext`, `getHome`.
- Create `app/lib/core/db/daos/albums_dao.dart`; modify `app/lib/core/db/database.dart` (register DAO).
- Create `app/lib/core/catalog/catalog_repository.dart`, `app/lib/core/catalog/catalog_providers.dart`.
- Modify `app/lib/core/audio/audio_handler.dart` + `app/lib/core/audio/audio_providers.dart` — queue support.
- Create `app/lib/features/album/album_detail_screen.dart`, `app/lib/features/artist/artist_detail_screen.dart`, `app/lib/features/home/home_screen.dart`, `app/lib/features/home/home_controller.dart`, `app/lib/features/now_playing/queue_sheet.dart`.
- Modify `app/lib/features/search/search_controller.dart` + `search_screen.dart` — show albums/artists, tap-through.
- Modify `app/lib/routing/app_router.dart` — add `/albums/:browseId`, `/artists/:browseId`, `/home`.

---

# PART A — Album & Artist Detail

## Task A1: Backend — catalog models for album & artist detail

**Files:**
- Modify: `backend/src/ytmusic_api/models/catalog.py`
- Test: `backend/tests/test_album_artist.py` (created in A3)

- [ ] **Step 1: Add models** (append to `catalog.py`, after `TrackResponse`):

```python
class AlbumTrack(BaseModel):
    videoId: str
    title: str
    artistName: str | None = None
    durationMs: int | None = None
    trackNumber: int | None = None
    thumbnail: Thumbnail | None = None


class AlbumDetailResponse(BaseModel):
    browseId: str
    title: str
    artistName: str | None = None
    artistBrowseId: str | None = None
    year: int | None = None
    trackCount: int | None = None
    thumbnail: Thumbnail | None = None
    audioPlaylistId: str | None = None
    items: list[AlbumTrack]


class ArtistTopSong(BaseModel):
    videoId: str
    title: str
    albumName: str | None = None
    thumbnail: Thumbnail | None = None


class ArtistAlbum(BaseModel):
    browseId: str
    title: str
    year: int | None = None
    thumbnail: Thumbnail | None = None


class ArtistDetailResponse(BaseModel):
    browseId: str
    name: str
    description: str | None = None
    subscriberCount: str | None = None
    thumbnail: Thumbnail | None = None
    radioId: str | None = None
    topSongs: list[ArtistTopSong]
    albums: list[ArtistAlbum]
    singles: list[ArtistAlbum]
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/models/catalog.py
git commit -m "feat(backend): album & artist detail response models"
```

---

## Task A2: Backend — `YTMusicClient.get_album` / `get_artist`

**Files:**
- Modify: `backend/src/ytmusic_api/services/ytmusic_client.py`
- Test: covered via router tests (A3, A4) using the fake client; no direct unit test needed (these are thin `to_thread` wrappers identical in shape to existing ones).

- [ ] **Step 1: Add methods** (after `get_song`):

```python
    async def get_album(self, browse_id: str) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_album(browse_id)

        return await asyncio.to_thread(_call)

    async def get_artist(self, channel_id: str) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_artist(channel_id)

        return await asyncio.to_thread(_call)
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/services/ytmusic_client.py
git commit -m "feat(backend): YTMusicClient get_album / get_artist wrappers"
```

---

## Task A3: Backend — `GET /v1/album/{browse_id}` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/catalog.py`
- Test: `backend/tests/test_album_artist.py`

- [ ] **Step 1: Write the failing test** (create `backend/tests/test_album_artist.py`):

```python
from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


class _FakeYTMusic(YTMusicClient):  # type: ignore[misc]
    def __init__(self) -> None:
        self.album_payloads: dict[str, dict[str, Any]] = {}
        self.artist_payloads: dict[str, dict[str, Any]] = {}
        self.album_calls = 0

    async def get_album(self, browse_id):  # type: ignore[override]
        self.album_calls += 1
        if browse_id not in self.album_payloads:
            raise RuntimeError("not found")
        return self.album_payloads[browse_id]

    async def get_artist(self, channel_id):  # type: ignore[override]
        if channel_id not in self.artist_payloads:
            raise RuntimeError("not found")
        return self.artist_payloads[channel_id]


@pytest.fixture
def fake_ytm() -> _FakeYTMusic:
    return _FakeYTMusic()


@pytest.fixture
def cache() -> TtlCache:
    return TtlCache()


@pytest.fixture
def catalog_client(headers_store, auth_monitor, fake_ytm, cache) -> TestClient:
    return TestClient(
        create_app(
            headers_store=headers_store,
            auth_monitor=auth_monitor,
            ytmusic_client=fake_ytm,
            cache=cache,
        )
    )


def _album_payload() -> dict[str, Any]:
    return {
        "title": "Revival",
        "type": "Album",
        "year": "2017",
        "trackCount": 2,
        "audioPlaylistId": "OLAK5uy_abc",
        "thumbnails": [{"url": "https://t/a.jpg", "width": 600, "height": 600}],
        "artists": [{"name": "Eminem", "id": "UCedvOgsKFzcK3hA5taf3KoQ"}],
        "tracks": [
            {
                "videoId": "v1",
                "title": "Walk On Water",
                "artists": [{"name": "Eminem", "id": "UCedv"}],
                "album": "Revival",
                "duration_seconds": 303,
                "trackNumber": 1,
                "thumbnails": None,
            },
            {
                "videoId": "v2",
                "title": "Believe",
                "artists": [{"name": "Eminem", "id": "UCedv"}],
                "album": "Revival",
                "duration_seconds": 200,
                "trackNumber": 2,
                "thumbnails": None,
            },
        ],
    }


def test_album_returns_normalised_detail(catalog_client, fake_ytm):
    fake_ytm.album_payloads["MPREb_x"] = _album_payload()
    r = catalog_client.get("/v1/album/MPREb_x")
    assert r.status_code == 200
    body = r.json()
    assert body["browseId"] == "MPREb_x"
    assert body["title"] == "Revival"
    assert body["artistName"] == "Eminem"
    assert body["artistBrowseId"] == "UCedvOgsKFzcK3hA5taf3KoQ"
    assert body["year"] == 2017
    assert body["trackCount"] == 2
    assert body["audioPlaylistId"] == "OLAK5uy_abc"
    assert body["thumbnail"]["url"] == "https://t/a.jpg"
    assert [t["videoId"] for t in body["items"]] == ["v1", "v2"]
    assert body["items"][0]["title"] == "Walk On Water"
    assert body["items"][0]["artistName"] == "Eminem"
    assert body["items"][0]["durationMs"] == 303_000
    assert body["items"][0]["trackNumber"] == 1


def test_album_404_when_not_found(catalog_client, fake_ytm):
    r = catalog_client.get("/v1/album/missing")
    assert r.status_code == 404


def test_album_caches_per_browseid(catalog_client, fake_ytm):
    fake_ytm.album_payloads["MPREb_x"] = _album_payload()
    catalog_client.get("/v1/album/MPREb_x")
    catalog_client.get("/v1/album/MPREb_x")
    assert fake_ytm.album_calls == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_album_artist.py -q`
Expected: FAIL (404 for every request — route not defined yet).

- [ ] **Step 3: Implement the route** (add to `catalog.py`; add `_ALBUM_TTL` next to the other TTL constants and the imports):

In the imports at the top of `catalog.py`, extend the model import:
```python
from ..models.catalog import (
    AlbumDetailResponse,
    AlbumTrack,
    ArtistAlbum,
    ArtistDetailResponse,
    ArtistTopSong,
    SearchResponse,
    SearchResult,
    Thumbnail,
    TrackResponse,
)
```

Add TTL constant near the top:
```python
_ALBUM_TTL = 24 * 60 * 60  # 24 hours
_ARTIST_TTL = 24 * 60 * 60  # 24 hours
```

Add helpers + route (after `get_track`):
```python
def _parse_year(raw: Any) -> int | None:
    try:
        return int(str(raw)[:4])
    except (TypeError, ValueError):
        return None


def _first_artist(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    artists = raw.get("artists") or []
    if not artists:
        return None, None
    return artists[0].get("name"), artists[0].get("id")


def _normalise_album_track(raw: dict[str, Any]) -> AlbumTrack | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    name, _ = _first_artist(raw)
    secs = raw.get("duration_seconds")
    thumbs = raw.get("thumbnails") or []
    return AlbumTrack(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=name,
        durationMs=None if secs is None else int(secs * 1000),
        trackNumber=raw.get("trackNumber"),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


@router.get("/album/{browse_id}", response_model=AlbumDetailResponse)
async def get_album(request: Request, browse_id: str) -> AlbumDetailResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"album:{browse_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return AlbumDetailResponse.model_validate(cached)

    try:
        raw = await ytm.get_album(browse_id)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"album not found: {exc}") from exc

    artist_name, artist_bid = _first_artist(raw)
    thumbs = raw.get("thumbnails") or []
    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_album_track(t) for t in tracks) if n is not None]
    response = AlbumDetailResponse(
        browseId=browse_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        artistBrowseId=artist_bid,
        year=_parse_year(raw.get("year")),
        trackCount=raw.get("trackCount") or len(items),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
        audioPlaylistId=raw.get("audioPlaylistId"),
        items=items,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_ALBUM_TTL)
    return response
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_album_artist.py -q`
Expected: the three `test_album_*` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/catalog.py backend/tests/test_album_artist.py
git commit -m "feat(backend): GET /v1/album/{browseId} with 24h cache"
```

---

## Task A4: Backend — `GET /v1/artist/{browse_id}` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/catalog.py`
- Test: `backend/tests/test_album_artist.py`

- [ ] **Step 1: Add the failing tests** (append to `test_album_artist.py`):

```python
def _artist_payload() -> dict[str, Any]:
    return {
        "name": "Oasis",
        "channelId": "UCreturned",
        "description": "Oasis were…",
        "subscribers": "3.86M",
        "radioId": "RDEMabc",
        "thumbnails": [{"url": "https://t/ar.jpg", "width": 540, "height": 540}],
        "songs": {
            "browseId": "VLPL123",
            "results": [
                {
                    "videoId": "s1",
                    "title": "Wonderwall",
                    "album": "Morning Glory",
                    "thumbnails": [{"url": "https://t/s.jpg", "width": 60, "height": 60}],
                }
            ],
        },
        "albums": {
            "results": [
                {
                    "title": "Familiar To Millions",
                    "year": "2018",
                    "browseId": "MPREb_AY",
                    "thumbnails": [{"url": "https://t/al.jpg", "width": 226, "height": 226}],
                }
            ],
        },
        "singles": {
            "results": [
                {
                    "title": "Stand By Me",
                    "year": "2016",
                    "browseId": "MPREb_7M",
                    "thumbnails": [],
                }
            ],
        },
    }


def test_artist_returns_normalised_detail(catalog_client, fake_ytm):
    fake_ytm.artist_payloads["UCabc"] = _artist_payload()
    r = catalog_client.get("/v1/artist/UCabc")
    assert r.status_code == 200
    body = r.json()
    assert body["browseId"] == "UCabc"
    assert body["name"] == "Oasis"
    assert body["subscriberCount"] == "3.86M"
    assert body["radioId"] == "RDEMabc"
    assert body["thumbnail"]["url"] == "https://t/ar.jpg"
    assert [s["videoId"] for s in body["topSongs"]] == ["s1"]
    assert body["topSongs"][0]["albumName"] == "Morning Glory"
    assert [a["browseId"] for a in body["albums"]] == ["MPREb_AY"]
    assert body["albums"][0]["year"] == 2018
    assert [a["browseId"] for a in body["singles"]] == ["MPREb_7M"]


def test_artist_404_when_not_found(catalog_client, fake_ytm):
    r = catalog_client.get("/v1/artist/missing")
    assert r.status_code == 404
```

- [ ] **Step 2: Run to verify fail**

Run: `cd backend && uv run pytest tests/test_album_artist.py -k artist -q`
Expected: FAIL (404 — route not defined).

- [ ] **Step 3: Implement** (add helpers + route to `catalog.py`):

```python
def _normalise_artist_song(raw: dict[str, Any]) -> ArtistTopSong | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    album = raw.get("album")
    album_name = album.get("name") if isinstance(album, dict) else album
    thumbs = raw.get("thumbnails") or []
    return ArtistTopSong(
        videoId=video_id,
        title=raw.get("title", ""),
        albumName=album_name,
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


def _normalise_artist_album(raw: dict[str, Any]) -> ArtistAlbum | None:
    bid = raw.get("browseId")
    if not bid:
        return None
    thumbs = raw.get("thumbnails") or []
    return ArtistAlbum(
        browseId=bid,
        title=raw.get("title", ""),
        year=_parse_year(raw.get("year")),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


@router.get("/artist/{browse_id}", response_model=ArtistDetailResponse)
async def get_artist(request: Request, browse_id: str) -> ArtistDetailResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"artist:{browse_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return ArtistDetailResponse.model_validate(cached)

    try:
        raw = await ytm.get_artist(browse_id)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"artist not found: {exc}") from exc

    songs = (raw.get("songs") or {}).get("results") or []
    albums = (raw.get("albums") or {}).get("results") or []
    singles = (raw.get("singles") or {}).get("results") or []
    thumbs = raw.get("thumbnails") or []
    response = ArtistDetailResponse(
        browseId=browse_id,
        name=raw.get("name", ""),
        description=raw.get("description"),
        subscriberCount=raw.get("subscribers"),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
        radioId=raw.get("radioId"),
        topSongs=[n for n in (_normalise_artist_song(s) for s in songs) if n is not None],
        albums=[n for n in (_normalise_artist_album(a) for a in albums) if n is not None],
        singles=[n for n in (_normalise_artist_album(a) for a in singles) if n is not None],
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_ARTIST_TTL)
    return response
```

- [ ] **Step 4: Run full backend suite**

Run: `cd backend && uv run pytest -q && uv run ruff check src tests`
Expected: all PASS, ruff clean.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/catalog.py backend/tests/test_album_artist.py
git commit -m "feat(backend): GET /v1/artist/{browseId} with 24h cache"
```

---

## Task A5: App — `AlbumDetail` & `ArtistDetail` models (TDD)

**Files:**
- Create: `app/lib/core/api/models/album_detail.dart`, `app/lib/core/api/models/artist_detail.dart`
- Test: `app/test/core/api/catalog_models_test.dart`

> All app commands run from `app/` with `fvm`. The shared `Thumbnail` model lives in `lib/core/api/models/track.dart` — import it.

- [ ] **Step 1: Write the failing test** (`app/test/core/api/catalog_models_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/album_detail.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';

void main() {
  test('AlbumDetail.fromJson parses items', () {
    final json = {
      'browseId': 'MPREb_x',
      'title': 'Revival',
      'artistName': 'Eminem',
      'artistBrowseId': 'UCedv',
      'year': 2017,
      'trackCount': 1,
      'thumbnail': {'url': 'https://t/a.jpg', 'width': 600, 'height': 600},
      'audioPlaylistId': 'OLAK5uy_abc',
      'items': [
        {
          'videoId': 'v1',
          'title': 'Walk On Water',
          'artistName': 'Eminem',
          'durationMs': 303000,
          'trackNumber': 1,
          'thumbnail': null,
        },
      ],
    };
    final a = AlbumDetail.fromJson(json);
    expect(a.browseId, 'MPREb_x');
    expect(a.artistName, 'Eminem');
    expect(a.year, 2017);
    expect(a.items.single.videoId, 'v1');
    expect(a.items.single.durationMs, 303000);
  });

  test('ArtistDetail.fromJson parses sections', () {
    final json = {
      'browseId': 'UCabc',
      'name': 'Oasis',
      'description': 'desc',
      'subscriberCount': '3.86M',
      'thumbnail': {'url': 'https://t/ar.jpg', 'width': 540, 'height': 540},
      'radioId': 'RDEMabc',
      'topSongs': [
        {'videoId': 's1', 'title': 'Wonderwall', 'albumName': 'MG', 'thumbnail': null},
      ],
      'albums': [
        {'browseId': 'MPREb_AY', 'title': 'Familiar', 'year': 2018, 'thumbnail': null},
      ],
      'singles': <Map<String, dynamic>>[],
    };
    final ar = ArtistDetail.fromJson(json);
    expect(ar.name, 'Oasis');
    expect(ar.radioId, 'RDEMabc');
    expect(ar.topSongs.single.videoId, 's1');
    expect(ar.albums.single.browseId, 'MPREb_AY');
    expect(ar.singles, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/api/catalog_models_test.dart`
Expected: FAIL (files/classes don't exist — compile error).

- [ ] **Step 3: Implement `album_detail.dart`:**

```dart
import 'package:ytmusic/core/api/models/track.dart';

class AlbumTrack {
  AlbumTrack({
    required this.videoId,
    required this.title,
    this.artistName,
    this.durationMs,
    this.trackNumber,
    this.thumbnail,
  });

  factory AlbumTrack.fromJson(Map<String, dynamic> json) => AlbumTrack(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        durationMs: json['durationMs'] as int?,
        trackNumber: json['trackNumber'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final int? durationMs;
  final int? trackNumber;
  final Thumbnail? thumbnail;
}

class AlbumDetail {
  AlbumDetail({
    required this.browseId,
    required this.title,
    required this.items,
    this.artistName,
    this.artistBrowseId,
    this.year,
    this.trackCount,
    this.thumbnail,
    this.audioPlaylistId,
  });

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
        browseId: json['browseId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        artistBrowseId: json['artistBrowseId'] as String?,
        year: json['year'] as int?,
        trackCount: json['trackCount'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
        audioPlaylistId: json['audioPlaylistId'] as String?,
        items: (json['items'] as List)
            .map((e) => AlbumTrack.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String browseId;
  final String title;
  final String? artistName;
  final String? artistBrowseId;
  final int? year;
  final int? trackCount;
  final Thumbnail? thumbnail;
  final String? audioPlaylistId;
  final List<AlbumTrack> items;
}
```

- [ ] **Step 4: Implement `artist_detail.dart`:**

```dart
import 'package:ytmusic/core/api/models/track.dart';

class ArtistTopSong {
  ArtistTopSong({
    required this.videoId,
    required this.title,
    this.albumName,
    this.thumbnail,
  });

  factory ArtistTopSong.fromJson(Map<String, dynamic> json) => ArtistTopSong(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        albumName: json['albumName'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String? albumName;
  final Thumbnail? thumbnail;
}

class ArtistAlbum {
  ArtistAlbum({
    required this.browseId,
    required this.title,
    this.year,
    this.thumbnail,
  });

  factory ArtistAlbum.fromJson(Map<String, dynamic> json) => ArtistAlbum(
        browseId: json['browseId'] as String,
        title: json['title'] as String,
        year: json['year'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String browseId;
  final String title;
  final int? year;
  final Thumbnail? thumbnail;
}

class ArtistDetail {
  ArtistDetail({
    required this.browseId,
    required this.name,
    required this.topSongs,
    required this.albums,
    required this.singles,
    this.description,
    this.subscriberCount,
    this.thumbnail,
    this.radioId,
  });

  factory ArtistDetail.fromJson(Map<String, dynamic> json) => ArtistDetail(
        browseId: json['browseId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        subscriberCount: json['subscriberCount'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
        radioId: json['radioId'] as String?,
        topSongs: (json['topSongs'] as List)
            .map((e) => ArtistTopSong.fromJson(e as Map<String, dynamic>))
            .toList(),
        albums: (json['albums'] as List)
            .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
            .toList(),
        singles: (json['singles'] as List)
            .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String browseId;
  final String name;
  final String? description;
  final String? subscriberCount;
  final Thumbnail? thumbnail;
  final String? radioId;
  final List<ArtistTopSong> topSongs;
  final List<ArtistAlbum> albums;
  final List<ArtistAlbum> singles;
}
```

- [ ] **Step 5: Run to verify pass**

Run: `fvm flutter test test/core/api/catalog_models_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/api/models/album_detail.dart app/lib/core/api/models/artist_detail.dart app/test/core/api/catalog_models_test.dart
git commit -m "feat(app): AlbumDetail & ArtistDetail models"
```

---

## Task A6: App — `ApiClient.getAlbum` / `getArtist` (TDD)

**Files:**
- Modify: `app/lib/core/api/api_client.dart`
- Test: `app/test/core/api/api_client_catalog_test.dart`

- [ ] **Step 1: Write the failing test** (use Dio with a mock adapter as elsewhere; here use `dio` + `http_mock_adapter` is not a dep — instead inject a base URL and assert via `DioException` path is not viable. Follow the existing `api_client_library_test.dart` approach which uses a real `Dio` with a `MockAdapter`). Inspect `app/test/core/api/api_client_library_test.dart` for the exact mock setup and copy it. The test asserts the request path:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

// Reuse the same fake interceptor pattern as api_client_library_test.dart.
class _CaptureInterceptor extends Interceptor {
  String? path;
  Map<String, dynamic>? query;
  final Map<String, dynamic> response;
  _CaptureInterceptor(this.response);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    path = options.path;
    query = options.queryParameters;
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: response),
    );
  }
}

ApiClient _clientWith(_CaptureInterceptor cap) {
  final c = ApiClient(
    config: const ApiConfig(
      baseUrl: 'https://x',
      cfAccessClientId: 'id',
      cfAccessClientSecret: 'sec',
    ),
  );
  c.dio.interceptors.add(cap);
  return c;
}

void main() {
  test('getAlbum hits /v1/album/{browseId}', () async {
    final cap = _CaptureInterceptor({
      'browseId': 'MPREb_x',
      'title': 'Revival',
      'items': <Map<String, dynamic>>[],
    });
    final album = await _clientWith(cap).getAlbum('MPREb_x');
    expect(cap.path, '/v1/album/MPREb_x');
    expect(album.title, 'Revival');
  });

  test('getArtist hits /v1/artist/{browseId}', () async {
    final cap = _CaptureInterceptor({
      'browseId': 'UCabc',
      'name': 'Oasis',
      'topSongs': <Map<String, dynamic>>[],
      'albums': <Map<String, dynamic>>[],
      'singles': <Map<String, dynamic>>[],
    });
    final artist = await _clientWith(cap).getArtist('UCabc');
    expect(cap.path, '/v1/artist/UCabc');
    expect(artist.name, 'Oasis');
  });
}
```

> Before writing, open `app/test/core/api/api_client_library_test.dart` and match its exact `ApiConfig` constructor and mock-adapter style — adapt the snippet above to it if it differs (e.g. it may use `DioAdapter` from `http_mock_adapter`). Use whatever that file uses.

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/api/api_client_catalog_test.dart`
Expected: FAIL (`getAlbum`/`getArtist` undefined).

- [ ] **Step 3: Implement** (add to `ApiClient`, importing the two new models at top of `api_client.dart`):

```dart
  Future<AlbumDetail> getAlbum(String browseId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/album/$browseId');
      return AlbumDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? 0, e.message ?? 'Network error');
    }
  }

  Future<ArtistDetail> getArtist(String browseId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/artist/$browseId');
      return ArtistDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? 0, e.message ?? 'Network error');
    }
  }
```

- [ ] **Step 4: Run to verify pass**

Run: `fvm flutter test test/core/api/api_client_catalog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/api/api_client.dart app/test/core/api/api_client_catalog_test.dart
git commit -m "feat(app): ApiClient getAlbum / getArtist"
```

---

## Task A7: App — `AlbumsDao` (TDD)

**Files:**
- Create: `app/lib/core/db/daos/albums_dao.dart`
- Modify: `app/lib/core/db/database.dart` (register the DAO)
- Test: `app/test/core/db/daos/albums_dao_test.dart`

> Pattern mirrors `PlaylistsDao` (upsert + `replaceTracks` transaction + `watchTracksFor`). The `Albums` and `AlbumTracks` tables already exist in `tables.dart`.

- [ ] **Step 1: Write the failing test** (`app/test/core/db/daos/albums_dao_test.dart`):

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('upsertAlbum + replaceTracks then watchTracksFor returns ordered rows',
      () async {
    await db.albumsDao.upsertAlbum(AlbumsCompanion.insert(
      browseId: 'AL1',
      title: 'Revival',
      artistName: const Value('Eminem'),
      trackCount: const Value(2),
    ));
    await db.albumsDao.replaceTracks('AL1', [
      AlbumTracksCompanion.insert(albumBrowseId: 'AL1', videoId: 'v1', position: 0),
      AlbumTracksCompanion.insert(albumBrowseId: 'AL1', videoId: 'v2', position: 1),
    ]);

    final rows = await db.albumsDao.watchTracksFor('AL1').first;
    expect(rows.map((r) => r.videoId).toList(), ['v1', 'v2']);

    // replaceTracks is atomic + idempotent
    await db.albumsDao.replaceTracks('AL1', [
      AlbumTracksCompanion.insert(albumBrowseId: 'AL1', videoId: 'v9', position: 0),
    ]);
    final rows2 = await db.albumsDao.watchTracksFor('AL1').first;
    expect(rows2.map((r) => r.videoId).toList(), ['v9']);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/db/daos/albums_dao_test.dart`
Expected: FAIL (`db.albumsDao` undefined).

- [ ] **Step 3: Implement `albums_dao.dart`:**

```dart
import 'package:drift/drift.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'albums_dao.g.dart';

@DriftAccessor(tables: [Albums, AlbumTracks])
class AlbumsDao extends DatabaseAccessor<AppDatabase> with _$AlbumsDaoMixin {
  AlbumsDao(super.db);

  Future<void> upsertAlbum(AlbumsCompanion row) =>
      into(albums).insertOnConflictUpdate(row);

  Future<Album?> getById(String browseId) =>
      (select(albums)..where((a) => a.browseId.equals(browseId)))
          .getSingleOrNull();

  Stream<List<AlbumTrack>> watchTracksFor(String albumBrowseId) {
    final q = select(albumTracks)
      ..where((t) => t.albumBrowseId.equals(albumBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.watch();
  }

  Future<void> replaceTracks(
    String albumBrowseId,
    List<AlbumTracksCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(albumTracks)
            ..where((t) => t.albumBrowseId.equals(albumBrowseId)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(albumTracks, rows));
    });
  }
}
```

- [ ] **Step 4: Register the DAO** in `app/lib/core/db/database.dart`:

Add the import:
```dart
import 'package:ytmusic/core/db/daos/albums_dao.dart';
```
Add `AlbumsDao` to the `daos:` list in the `@DriftDatabase(...)` annotation (alphabetical: `AlbumsDao, ArtistsDao, PlaylistsDao, RecentlyPlayedDao, SyncStateDao, TracksDao`).

- [ ] **Step 5: Regenerate Drift code**

Run: `fvm dart run build_runner build --delete-conflicting-outputs`
Expected: writes `albums_dao.g.dart` + updates `database.g.dart`, no errors.

- [ ] **Step 6: Run to verify pass**

Run: `fvm flutter test test/core/db/daos/albums_dao_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/db/daos/albums_dao.dart app/lib/core/db/database.dart app/lib/core/db/database.g.dart app/test/core/db/daos/albums_dao_test.dart
git commit -m "feat(app): AlbumsDao with replaceTracks transaction"
```

---

## Task A8: App — `CatalogRepository` (album/artist → Drift) (TDD)

**Files:**
- Create: `app/lib/core/catalog/catalog_repository.dart`, `app/lib/core/catalog/catalog_providers.dart`
- Test: `app/test/core/catalog/catalog_repository_test.dart`

> Mirrors `LibraryRepository`: fetch from API, upsert into Drift in a transaction, mark sync state. Albums are cached locally so the detail screen streams from Drift. Artist detail is lightweight (top songs + album lists) — store the artist row + return the `ArtistDetail` directly for the screen to render (no dedicated artist-content table in the v1 schema).

- [ ] **Step 1: Write the failing test** (`app/test/core/catalog/catalog_repository_test.dart`):

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/album_detail.dart';
import 'package:ytmusic/core/catalog/catalog_repository.dart';
import 'package:ytmusic/core/db/database.dart';

class _FakeApi implements CatalogApi {
  @override
  Future<AlbumDetail> getAlbum(String browseId) async => AlbumDetail(
        browseId: browseId,
        title: 'Revival',
        artistName: 'Eminem',
        artistBrowseId: 'UCedv',
        trackCount: 2,
        items: [
          AlbumTrack(videoId: 'v1', title: 'A', durationMs: 1000, trackNumber: 1),
          AlbumTrack(videoId: 'v2', title: 'B', durationMs: 2000, trackNumber: 2),
        ],
      );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('refreshAlbum upserts album + tracks + album_tracks ordering', () async {
    final repo = CatalogRepository(db: db, api: _FakeApi());
    await repo.refreshAlbum('AL1');

    final album = await db.albumsDao.getById('AL1');
    expect(album!.title, 'Revival');

    final at = await db.albumsDao.watchTracksFor('AL1').first;
    expect(at.map((r) => r.videoId).toList(), ['v1', 'v2']);

    final tracks = await db.tracksDao.getByIds(['v1', 'v2']);
    expect(tracks.length, 2);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/catalog/catalog_repository_test.dart`
Expected: FAIL (classes undefined).

- [ ] **Step 3: Implement `catalog_repository.dart`:**

```dart
import 'package:drift/drift.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/album_detail.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/core/db/database.dart';

/// Narrow interface so tests can fake just the catalog calls.
abstract class CatalogApi {
  Future<AlbumDetail> getAlbum(String browseId);
}

/// ApiClient already satisfies getAlbum; this lets the repo accept it.
class CatalogRepository {
  CatalogRepository({required this.db, required this.api});

  final AppDatabase db;
  final CatalogApi api;

  static const Duration _staleTtl = Duration(hours: 24);

  Future<void> refreshAlbum(String browseId) async {
    final detail = await api.getAlbum(browseId);
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.albumsDao.upsertAlbum(AlbumsCompanion.insert(
        browseId: detail.browseId,
        title: detail.title,
        artistName: Value(detail.artistName),
        artistBrowseId: Value(detail.artistBrowseId),
        year: Value(detail.year),
        artworkUrl: Value(detail.thumbnail?.url),
        trackCount: Value(detail.trackCount ?? detail.items.length),
        lastSyncedAt: Value(now),
      ));
      for (final t in detail.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: t.videoId,
          title: t.title,
          artistName: Value(t.artistName ?? detail.artistName),
          albumName: Value(detail.title),
          albumBrowseId: Value(detail.browseId),
          artistBrowseId: Value(detail.artistBrowseId),
          durationMs: Value(t.durationMs),
          artworkUrl: Value(t.thumbnail?.url ?? detail.thumbnail?.url),
        ));
      }
      await db.albumsDao.replaceTracks(browseId, [
        for (var i = 0; i < detail.items.length; i++)
          AlbumTracksCompanion.insert(
            albumBrowseId: browseId,
            videoId: detail.items[i].videoId,
            position: i,
          ),
      ]);
      await db.syncStateDao.mark('album:$browseId', at: now);
    });
  }

  Future<void> refreshAlbumIfStale(String browseId) async {
    if (await db.syncStateDao.isFresh('album:$browseId', ttl: _staleTtl)) return;
    await refreshAlbum(browseId);
  }
}
```

> Note: `ApiClient` must implement `CatalogApi`. Add `implements CatalogApi` to the `ApiClient` class declaration in `api_client.dart` (it already has a matching `getAlbum`). Artist detail is NOT persisted (no v1 table); the artist screen calls `api.getArtist` directly via a FutureProvider (Task A10).

- [ ] **Step 4: Implement `catalog_providers.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/catalog/catalog_repository.dart';
import 'package:ytmusic/core/db/db_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return CatalogRepository(db: ref.watch(appDatabaseProvider), api: api);
});
```

- [ ] **Step 5: Make `ApiClient implements CatalogApi`** in `api_client.dart` — change the class line to `class ApiClient implements CatalogApi {` and add `import 'package:ytmusic/core/catalog/catalog_repository.dart';`.

- [ ] **Step 6: Run to verify pass**

Run: `fvm flutter test test/core/catalog/catalog_repository_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/catalog/ app/lib/core/api/api_client.dart app/test/core/catalog/catalog_repository_test.dart
git commit -m "feat(app): CatalogRepository — album sync to Drift"
```

---

## Task A9: App — `AlbumDetailScreen` (widget test)

**Files:**
- Create: `app/lib/features/album/album_detail_screen.dart`
- Test: `app/test/features/album/album_detail_screen_test.dart`

> Pattern copied from `playlist_detail_screen.dart`: `ConsumerStatefulWidget`, refresh-if-stale in `initState`, `StreamBuilder` over `albumsDao.watchTracksFor`, `FutureBuilder` over `tracksDao.getByIds`, tap → `audioHandler.playTrack`. Use the shared `TrackListTile`.

- [ ] **Step 1: Write the failing widget test** — render with a pre-seeded in-memory DB and a stubbed repo/handler; assert track titles appear. Model it on `app/test/features/library/liked_songs_screen_test.dart` (open it first to copy the `ProviderScope` override style for `appDatabaseProvider`, `catalogRepositoryProvider`, and `audioHandlerProvider`).

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/catalog/catalog_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/album/album_detail_screen.dart';

void main() {
  testWidgets('renders album tracks from Drift', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(videoId: 'v1', title: 'Walk On Water'),
    );
    await db.albumsDao.replaceTracks('AL1', [
      AlbumTracksCompanion.insert(albumBrowseId: 'AL1', videoId: 'v1', position: 0),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        catalogRepositoryProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        home: AlbumDetailScreen(browseId: 'AL1'),
      ),
    ));
    await tester.pump();
    expect(find.text('Walk On Water'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/features/album/album_detail_screen_test.dart`
Expected: FAIL (screen undefined).

- [ ] **Step 3: Implement `album_detail_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/catalog/catalog_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({required this.browseId, super.key});
  final String browseId;

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(catalogRepositoryProvider);
      if (repo == null) return;
      await repo.refreshAlbumIfStale(widget.browseId);
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(catalogRepositoryProvider);
    if (repo == null) return;
    await repo.refreshAlbum(widget.browseId);
  }

  Future<void> _play(Track t) async {
    await ref.read(audioHandlerProvider).playTrack(
          wire.Track(
            videoId: t.videoId,
            title: t.title,
            artistName: t.artistName ?? 'Unknown',
            albumName: t.albumName,
            durationMs: t.durationMs ?? 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<AlbumTrack>>(
          stream: db.albumsDao.watchTracksFor(widget.browseId),
          builder: (ctx, snap) {
            final rows = snap.data ?? const <AlbumTrack>[];
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No tracks.')),
              ]);
            }
            return FutureBuilder<List<Track>>(
              future: db.tracksDao.getByIds(rows.map((r) => r.videoId).toList()),
              builder: (ctx, ts) {
                final tracks = ts.data ?? const <Track>[];
                if (tracks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Preserve album_tracks ordering.
                final byId = {for (final t in tracks) t.videoId: t};
                final ordered = [
                  for (final r in rows)
                    if (byId[r.videoId] != null) byId[r.videoId]!,
                ];
                return ListView.builder(
                  itemCount: ordered.length,
                  itemBuilder: (ctx, i) {
                    final t = ordered[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => _play(t),
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

- [ ] **Step 4: Run to verify pass**

Run: `fvm flutter test test/features/album/album_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/album/album_detail_screen.dart app/test/features/album/album_detail_screen_test.dart
git commit -m "feat(app): AlbumDetailScreen streaming from Drift"
```

---

## Task A10: App — `ArtistDetailScreen` (widget test)

**Files:**
- Create: `app/lib/features/artist/artist_detail_screen.dart`
- Test: `app/test/features/artist/artist_detail_screen_test.dart`

> Artist detail is not persisted; it reads live via a `FutureProvider.family` over `ApiClient.getArtist`. Shows: header (name + subscriberCount), top songs (tap → play), albums + singles (tap → push `/albums/:browseId`).

- [ ] **Step 1: Write the failing widget test** — override `apiClientProvider`'s downstream by injecting an artist future via a family provider override. Simplest: define the provider in the screen file and override it in the test. Test asserts the artist name + a top-song title render.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/features/artist/artist_detail_screen.dart';

void main() {
  testWidgets('renders artist name and top song', (tester) async {
    final artist = ArtistDetail(
      browseId: 'UCabc',
      name: 'Oasis',
      subscriberCount: '3.86M',
      topSongs: [ArtistTopSong(videoId: 's1', title: 'Wonderwall')],
      albums: const [],
      singles: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        artistDetailProvider('UCabc').overrideWith((ref) async => artist),
      ],
      child: const MaterialApp(home: ArtistDetailScreen(browseId: 'UCabc')),
    ));
    await tester.pump();
    expect(find.text('Oasis'), findsOneWidget);
    expect(find.text('Wonderwall'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/features/artist/artist_detail_screen_test.dart`
Expected: FAIL (undefined).

- [ ] **Step 3: Implement `artist_detail_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';

final artistDetailProvider =
    FutureProvider.autoDispose.family<ArtistDetail, String>((ref, browseId) {
  final api = ref.watch(apiClientProvider);
  if (api == null) {
    throw StateError('Client not configured');
  }
  return api.getArtist(browseId);
});

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({required this.browseId, super.key});
  final String browseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistDetailProvider(browseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (a) => ListView(
          children: [
            ListTile(
              title: Text(a.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              subtitle: a.subscriberCount == null
                  ? null
                  : Text('${a.subscriberCount} subscribers'),
            ),
            if (a.topSongs.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Top songs'),
              ),
            for (final s in a.topSongs)
              ListTile(
                title: Text(s.title),
                subtitle: s.albumName == null ? null : Text(s.albumName!),
                onTap: () => ref.read(audioHandlerProvider).playTrack(
                      wire.Track(
                        videoId: s.videoId,
                        title: s.title,
                        artistName: a.name,
                        durationMs: 0,
                      ),
                    ),
              ),
            if (a.albums.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Albums'),
              ),
            for (final al in a.albums)
              ListTile(
                title: Text(al.title),
                subtitle: al.year == null ? null : Text('${al.year}'),
                onTap: () => context.push('/albums/${al.browseId}'),
              ),
            if (a.singles.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Singles'),
              ),
            for (final s in a.singles)
              ListTile(
                title: Text(s.title),
                subtitle: s.year == null ? null : Text('${s.year}'),
                onTap: () => context.push('/albums/${s.browseId}'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `fvm flutter test test/features/artist/artist_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/artist/artist_detail_screen.dart app/test/features/artist/artist_detail_screen_test.dart
git commit -m "feat(app): ArtistDetailScreen (live FutureProvider)"
```

---

## Task A11: App — routes for album/artist + search tap-through

**Files:**
- Modify: `app/lib/routing/app_router.dart`
- Modify: `app/lib/features/search/search_controller.dart`, `app/lib/features/search/search_screen.dart`

- [ ] **Step 1: Add routes** in `app_router.dart` (inside `routes: [...]`):

```dart
      GoRoute(
        path: '/albums/:browseId',
        builder: (context, state) =>
            AlbumDetailScreen(browseId: state.pathParameters['browseId']!),
      ),
      GoRoute(
        path: '/artists/:browseId',
        builder: (context, state) =>
            ArtistDetailScreen(browseId: state.pathParameters['browseId']!),
      ),
```
Add imports for `AlbumDetailScreen` and `ArtistDetailScreen` at the top.

- [ ] **Step 2: Broaden search** — in `search_controller.dart` change the search type from song-only to all types:

```dart
  // Phase 3: show songs, albums, and artists.
  return client.search(query, type: null);
```
(Passing `type: null` returns mixed results; the backend already supports it.)

- [ ] **Step 3: Route taps by result type** — in `search_screen.dart`, replace `_onTap`:

```dart
  Future<void> _onTap(SearchResult r) async {
    switch (r.type) {
      case 'song':
      case 'video':
        if (r.videoId == null) return;
        await ref.read(audioHandlerProvider).playTrack(
              Track(
                videoId: r.videoId!,
                title: r.title,
                artistName: r.artistName ?? 'Unknown',
                albumName: r.albumName,
                durationMs: r.durationMs ?? 0,
              ),
            );
        if (mounted) unawaited(context.push<void>('/now-playing'));
      case 'album':
        if (r.browseId != null) unawaited(context.push('/albums/${r.browseId}'));
      case 'artist':
        if (r.browseId != null) unawaited(context.push('/artists/${r.browseId}'));
    }
  }
```

- [ ] **Step 4: Verify the whole app**

Run: `fvm flutter analyze && fvm flutter test`
Expected: no analyzer issues; all tests PASS.

- [ ] **Step 5: Manual smoke (simulator)** — `fvm flutter run -d "iPhone 17 Pro"`, search an artist name, confirm artist + album results appear and tapping navigates into detail screens; play an album track.

- [ ] **Step 6: Commit**

```bash
git add app/lib/routing/app_router.dart app/lib/features/search/
git commit -m "feat(app): album/artist routes + typed search tap-through"
```

---

## Task A12: Part A integration check + deploy backend

- [ ] **Step 1:** Run full backend + app suites: `cd backend && uv run pytest -q` and `cd app && fvm flutter test`. All green.
- [ ] **Step 2:** Open a PR for the backend endpoints (so they deploy to VM 101). After merge: `ssh ssh.richarddepierre.com "cd ~/docker/yt-music-app && git pull && docker compose up -d --build yt-music-api"`, then `curl` `/v1/album/<id>` and `/v1/artist/<id>` through CF Access to confirm 200.
- [ ] **Step 3:** Append a change-log entry to `~/Documents/development-second-brain/Dev-second-brain/Projects/yt-music-logs/` and update roadmap status in `Projects/yt-music.md` (Part A done).

---

# PART B — Discovery: Queue & Radio

## Task B1: Backend — discovery models for queue

**Files:**
- Create: `backend/src/ytmusic_api/models/discovery.py`

- [ ] **Step 1: Create the file:**

```python
from __future__ import annotations

from pydantic import BaseModel

from .catalog import Thumbnail


class QueueItem(BaseModel):
    videoId: str
    title: str
    artistName: str | None = None
    albumName: str | None = None
    albumBrowseId: str | None = None
    durationMs: int | None = None
    thumbnail: Thumbnail | None = None


class QueueResponse(BaseModel):
    items: list[QueueItem]
    continuation: str | None = None
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/models/discovery.py
git commit -m "feat(backend): discovery queue models"
```

---

## Task B2: Backend — `YTMusicClient.get_watch_playlist`

**Files:**
- Modify: `backend/src/ytmusic_api/services/ytmusic_client.py`

- [ ] **Step 1: Add method:**

```python
    async def get_watch_playlist(
        self,
        *,
        video_id: str | None = None,
        playlist_id: str | None = None,
        radio: bool = False,
        limit: int = 25,
    ) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_watch_playlist(
                videoId=video_id,
                playlistId=playlist_id,
                radio=radio,
                limit=limit,
            )

        return await asyncio.to_thread(_call)
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/services/ytmusic_client.py
git commit -m "feat(backend): YTMusicClient get_watch_playlist wrapper"
```

---

## Task B3: Backend — `GET /v1/radio` (TDD)

**Files:**
- Create: `backend/src/ytmusic_api/routers/discovery.py`
- Modify: `backend/src/ytmusic_api/main.py`
- Test: `backend/tests/test_discovery.py`

- [ ] **Step 1: Write the failing test** (`backend/tests/test_discovery.py`):

```python
from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


class _FakeYTMusic(YTMusicClient):  # type: ignore[misc]
    def __init__(self) -> None:
        self.watch_payload: dict[str, Any] = {"tracks": []}
        self.last_call: dict[str, Any] = {}
        self.home_payload: list[dict[str, Any]] = []

    async def get_watch_playlist(  # type: ignore[override]
        self, *, video_id=None, playlist_id=None, radio=False, limit=25
    ):
        self.last_call = {
            "video_id": video_id,
            "playlist_id": playlist_id,
            "radio": radio,
            "limit": limit,
        }
        return self.watch_payload

    async def get_home(self, *, limit=3):  # type: ignore[override]
        return self.home_payload


@pytest.fixture
def fake_ytm() -> _FakeYTMusic:
    return _FakeYTMusic()


@pytest.fixture
def cache() -> TtlCache:
    return TtlCache()


@pytest.fixture
def disco_client(headers_store, auth_monitor, fake_ytm, cache) -> TestClient:
    return TestClient(
        create_app(
            headers_store=headers_store,
            auth_monitor=auth_monitor,
            ytmusic_client=fake_ytm,
            cache=cache,
        )
    )


def _watch_track(video_id: str) -> dict[str, Any]:
    # Watch tracks use `length` (string) + singular `thumbnail` (list).
    return {
        "videoId": video_id,
        "title": "Song",
        "length": "3:07",
        "thumbnail": [{"url": "https://t/w.jpg", "width": 60, "height": 60}],
        "artists": [{"name": "Artist", "id": "UCx"}],
        "album": {"name": "Album", "id": "MPREb_x"},
    }


def test_radio_passes_seed_and_radio_flag(disco_client, fake_ytm):
    fake_ytm.watch_payload = {"tracks": [_watch_track("v1"), _watch_track("v2")]}
    r = disco_client.get("/v1/radio?seedVideoId=v0")
    assert r.status_code == 200
    assert fake_ytm.last_call["video_id"] == "v0"
    assert fake_ytm.last_call["radio"] is True
    body = r.json()
    assert [it["videoId"] for it in body["items"]] == ["v1", "v2"]
    first = body["items"][0]
    assert first["artistName"] == "Artist"
    assert first["albumName"] == "Album"
    assert first["albumBrowseId"] == "MPREb_x"
    assert first["thumbnail"]["url"] == "https://t/w.jpg"


def test_radio_requires_seed(disco_client):
    r = disco_client.get("/v1/radio")
    assert r.status_code == 422
```

- [ ] **Step 2: Run to verify fail**

Run: `cd backend && uv run pytest tests/test_discovery.py -k radio -q`
Expected: FAIL (route not defined → 404, not 200/422).

- [ ] **Step 3: Implement `discovery.py`** (radio first; up-next + home added in later tasks):

```python
from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import Thumbnail
from ..models.discovery import QueueItem, QueueResponse
from ..services.cache import TtlCache
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()
logger = logging.getLogger(__name__)

_RADIO_TTL = 5 * 60  # 5 minutes


def _watch_thumb(raw: dict[str, Any]) -> Thumbnail | None:
    # Watch tracks use singular `thumbnail` (a list); fall back to `thumbnails`.
    thumbs = raw.get("thumbnail") or raw.get("thumbnails") or []
    return Thumbnail(**thumbs[-1]) if thumbs else None


def _normalise_queue_item(raw: dict[str, Any]) -> QueueItem | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None
    album = raw.get("album") or {}
    album_name = album.get("name") if isinstance(album, dict) else album
    album_bid = album.get("id") if isinstance(album, dict) else None
    return QueueItem(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=None,  # watch tracks expose `length` (mm:ss); the player measures real duration
        thumbnail=_watch_thumb(raw),
    )


@router.get("/radio", response_model=QueueResponse)
async def get_radio(
    request: Request,
    seedVideoId: str = Query(..., min_length=1),  # noqa: N803 — wire contract
) -> QueueResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"radio:{seedVideoId}"
    cached = cache.get(cache_key)
    if cached is not None:
        return QueueResponse.model_validate(cached)

    try:
        raw = await ytm.get_watch_playlist(video_id=seedVideoId, radio=True)
    except Exception as exc:
        logger.exception("get_watch_playlist (radio) failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_queue_item(t) for t in tracks) if n is not None]
    response = QueueResponse(items=items, continuation=None)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_RADIO_TTL)
    return response
```

- [ ] **Step 4: Register the router** in `main.py`: add `discovery` to the routers import and add `app.include_router(discovery.router, prefix="/v1")` in `create_app` (next to the others).

```python
from .routers import admin, catalog, discovery, health, library, stream
# ...
    app.include_router(discovery.router, prefix="/v1")
```

- [ ] **Step 5: Run to verify pass**

Run: `cd backend && uv run pytest tests/test_discovery.py -k radio -q`
Expected: PASS (both radio tests).

- [ ] **Step 6: Commit**

```bash
git add backend/src/ytmusic_api/routers/discovery.py backend/src/ytmusic_api/main.py backend/tests/test_discovery.py
git commit -m "feat(backend): GET /v1/radio (watch playlist, 5min cache)"
```

---

## Task B4: Backend — `GET /v1/up-next` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/discovery.py`
- Test: `backend/tests/test_discovery.py`

- [ ] **Step 1: Add failing tests:**

```python
def test_up_next_passes_video_id_and_radio_flag(disco_client, fake_ytm):
    fake_ytm.watch_payload = {"tracks": [_watch_track("v1")]}
    r = disco_client.get("/v1/up-next?videoId=v0&radio=true")
    assert r.status_code == 200
    assert fake_ytm.last_call["video_id"] == "v0"
    assert fake_ytm.last_call["radio"] is True
    assert [it["videoId"] for it in r.json()["items"]] == ["v1"]


def test_up_next_defaults_radio_false(disco_client, fake_ytm):
    fake_ytm.watch_payload = {"tracks": []}
    disco_client.get("/v1/up-next?videoId=v0")
    assert fake_ytm.last_call["radio"] is False


def test_up_next_requires_video_id(disco_client):
    assert disco_client.get("/v1/up-next").status_code == 422
```

- [ ] **Step 2: Run to verify fail**

Run: `cd backend && uv run pytest tests/test_discovery.py -k up_next -q`
Expected: FAIL.

- [ ] **Step 3: Implement** (add to `discovery.py`):

```python
@router.get("/up-next", response_model=QueueResponse)
async def get_up_next(
    request: Request,
    videoId: str = Query(..., min_length=1),  # noqa: N803 — wire contract
    radio: bool = Query(False),
) -> QueueResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"upnext:{videoId}:{radio}"
    cached = cache.get(cache_key)
    if cached is not None:
        return QueueResponse.model_validate(cached)

    try:
        raw = await ytm.get_watch_playlist(video_id=videoId, radio=radio)
    except Exception as exc:
        logger.exception("get_watch_playlist (up-next) failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_queue_item(t) for t in tracks) if n is not None]
    response = QueueResponse(items=items, continuation=None)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_RADIO_TTL)
    return response
```

- [ ] **Step 4: Run full backend suite + lint**

Run: `cd backend && uv run pytest -q && uv run ruff check src tests`
Expected: all PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/discovery.py backend/tests/test_discovery.py
git commit -m "feat(backend): GET /v1/up-next (watch continuation)"
```

---

## Task B5: App — queue model + `ApiClient.getRadio` / `getUpNext` (TDD)

**Files:**
- Create: `app/lib/core/api/models/queue_item.dart`
- Modify: `app/lib/core/api/api_client.dart`
- Test: `app/test/core/api/api_client_discovery_test.dart`

- [ ] **Step 1: Write the failing test** (mirror the `_CaptureInterceptor` style from A6):

```dart
// imports as in A6's capture-interceptor test
void main() {
  test('getRadio hits /v1/radio?seedVideoId=', () async {
    final cap = _CaptureInterceptor({'items': <Map<String, dynamic>>[], 'continuation': null});
    await _clientWith(cap).getRadio('v0');
    expect(cap.path, '/v1/radio');
    expect(cap.query!['seedVideoId'], 'v0');
  });

  test('getUpNext hits /v1/up-next?videoId=', () async {
    final cap = _CaptureInterceptor({
      'items': [
        {'videoId': 'v1', 'title': 'Song', 'artistName': 'A'},
      ],
      'continuation': null,
    });
    final q = await _clientWith(cap).getUpNext('v0');
    expect(cap.path, '/v1/up-next');
    expect(cap.query!['videoId'], 'v0');
    expect(q.single.videoId, 'v1');
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/api/api_client_discovery_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `queue_item.dart`:**

```dart
import 'package:ytmusic/core/api/models/track.dart';

class QueueItem {
  QueueItem({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        albumName: json['albumName'] as String?,
        albumBrowseId: json['albumBrowseId'] as String?,
        durationMs: json['durationMs'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;

  Track toTrack() => Track(
        videoId: videoId,
        title: title,
        artistName: artistName ?? 'Unknown',
        albumName: albumName,
        albumBrowseId: albumBrowseId,
        durationMs: durationMs ?? 0,
        thumbnail: thumbnail,
      );
}
```

- [ ] **Step 4: Implement client methods** (add to `ApiClient`, import `queue_item.dart`):

```dart
  Future<List<QueueItem>> getRadio(String seedVideoId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/radio',
        queryParameters: {'seedVideoId': seedVideoId},
      );
      return (res.data!['items'] as List)
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? 0, e.message ?? 'Network error');
    }
  }

  Future<List<QueueItem>> getUpNext(String videoId, {bool radio = false}) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/up-next',
        queryParameters: {'videoId': videoId, 'radio': radio},
      );
      return (res.data!['items'] as List)
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? 0, e.message ?? 'Network error');
    }
  }
```

> The `Track` model must accept `albumBrowseId` and `thumbnail` named params — it already does (Task A5 reference). If `toTrack()` fails to compile, confirm `Track`'s constructor signature in `track.dart`.

- [ ] **Step 5: Run to verify pass**

Run: `fvm flutter test test/core/api/api_client_discovery_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/api/models/queue_item.dart app/lib/core/api/api_client.dart app/test/core/api/api_client_discovery_test.dart
git commit -m "feat(app): QueueItem model + getRadio / getUpNext"
```

---

## Task B6: App — multi-track queue in `AudioPlaybackHandler` (TDD)

**Files:**
- Modify: `app/lib/core/audio/audio_handler.dart`
- Test: `app/test/audio_handler_test.dart` (extend the existing file)

> Current handler plays a single track via `playTrack` and tracks `_currentTrack`. Add a queue: `_queue` (`List<Track>`), `_index`, `setQueue(tracks, startIndex)`, override `skipToNext`/`skipToPrevious`, auto-advance when a track completes, and publish `queue` + `queueIndex`. Keep `playTrack` working (it becomes a single-item queue).

- [ ] **Step 1: Write the failing test** — extend `audio_handler_test.dart`. Open it first to copy the existing fake `AudioPlayer`/`ApiClientFactory` setup. New tests:

```dart
  test('setQueue then skipToNext advances current track', () async {
    final handler = makeHandler(); // existing helper in the test file
    await handler.setQueue([
      Track(videoId: 'a', title: 'A', artistName: 'x', durationMs: 0),
      Track(videoId: 'b', title: 'B', artistName: 'x', durationMs: 0),
    ], startIndex: 0);
    expect(handler.currentVideoId, 'a');

    await handler.skipToNext();
    expect(handler.currentVideoId, 'b');
  });

  test('skipToPrevious at index 0 stays at 0', () async {
    final handler = makeHandler();
    await handler.setQueue([
      Track(videoId: 'a', title: 'A', artistName: 'x', durationMs: 0),
    ], startIndex: 0);
    await handler.skipToPrevious();
    expect(handler.currentVideoId, 'a');
  });
```

> Expose `String? get currentVideoId => _currentTrack?.videoId;` on the handler for the test (a thin read-only getter, acceptable).

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/audio_handler_test.dart`
Expected: FAIL (`setQueue`/`skipToNext`/`currentVideoId` undefined).

- [ ] **Step 3: Implement** — add to `AudioPlaybackHandler`:

```dart
  final List<Track> _queue = [];
  int _index = 0;

  String? get currentVideoId => _currentTrack?.videoId;

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue
      ..clear()
      ..addAll(tracks);
    _index = startIndex.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1);
    queue.add(_queue.map(_toMediaItem).toList());
    if (_queue.isNotEmpty) {
      await playTrack(_queue[_index]);
    }
  }

  MediaItem _toMediaItem(Track track) => MediaItem(
        id: track.videoId,
        title: track.title,
        artist: track.artistName,
        album: track.albumName,
        duration: track.durationMs > 0
            ? Duration(milliseconds: track.durationMs)
            : null,
        artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!.url) : null,
      );

  @override
  Future<void> skipToNext() async {
    if (_index + 1 >= _queue.length) return;
    _index += 1;
    await playTrack(_queue[_index]);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_index <= 0) return;
    _index -= 1;
    await playTrack(_queue[_index]);
  }
```

In `_wirePlayerEvents()`, add auto-advance on completion:
```dart
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
```

Update `_toState` to publish the real queue index: change `queueIndex: 0` to `queueIndex: _index`.

> Refactor `playTrack` to build its `MediaItem` via `_toMediaItem(track)` (DRY with `setQueue`). It should keep setting `_currentTrack`, resolving the stream (`codec: 'aac'`), and calling `mediaItem.add(...)`.

- [ ] **Step 4: Run to verify pass**

Run: `fvm flutter test test/audio_handler_test.dart`
Expected: PASS (existing + new tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/audio/audio_handler.dart app/test/audio_handler_test.dart
git commit -m "feat(app): multi-track queue + skip controls in audio handler"
```

---

## Task B7: App — radio autoplay wiring

**Files:**
- Modify: `app/lib/core/audio/audio_handler.dart` + `audio_providers.dart`
- Modify tap handlers to start a radio queue (search/album/now-playing)

> When the user plays a single song, fetch its `/up-next` queue and load it so playback continues automatically. Implement `playTrackWithAutoplay(track)` on the handler.

- [ ] **Step 1: Write the failing test** (extend `audio_handler_test.dart`) — inject a fake API whose `getUpNext` returns two follow-on tracks; assert the queue length grows:

```dart
  test('playTrackWithAutoplay loads up-next into the queue', () async {
    final handler = makeHandler(upNext: [
      QueueItem(videoId: 'n1', title: 'N1'),
      QueueItem(videoId: 'n2', title: 'N2'),
    ]);
    await handler.playTrackWithAutoplay(
      Track(videoId: 'seed', title: 'Seed', artistName: 'x', durationMs: 0),
    );
    expect(handler.currentVideoId, 'seed');
    // queue = [seed, n1, n2]
    await handler.skipToNext();
    expect(handler.currentVideoId, 'n1');
  });
```
> Extend the test's `makeHandler` helper to accept an `upNext` list and wire the fake `ApiClient.getUpNext`.

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/audio_handler_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** — add to the handler:

```dart
  Future<void> playTrackWithAutoplay(Track track) async {
    // Start playing immediately, then extend the queue with up-next.
    await setQueue([track], startIndex: 0);
    try {
      final api = _requireApi();
      final next = await api.getUpNext(track.videoId);
      final followOn = next
          .where((q) => q.videoId != track.videoId)
          .map((q) => q.toTrack())
          .toList();
      if (followOn.isNotEmpty) {
        _queue.addAll(followOn);
        queue.add(_queue.map(_toMediaItem).toList());
      }
    } catch (_) {
      // Autoplay is best-effort; a failure just means no follow-on tracks.
    }
  }
```

- [ ] **Step 4: Switch song taps to autoplay** — in `search_screen.dart` (`_onTap` song case), `album_detail_screen.dart` (`_play`), and `liked_songs_screen.dart`/`playlist_detail_screen.dart` (`_play`), call `playTrackWithAutoplay(...)` instead of `playTrack(...)`. (Album/playlist taps could instead `setQueue` the whole list — see Step 5.)

- [ ] **Step 5: Play album/playlist as a queue** — in `album_detail_screen.dart`, change `_play(Track t)` to enqueue the full ordered album and start at the tapped index:

```dart
  Future<void> _playFrom(List<Track> ordered, int index) async {
    await ref.read(audioHandlerProvider).setQueue(
          [
            for (final t in ordered)
              wire.Track(
                videoId: t.videoId,
                title: t.title,
                artistName: t.artistName ?? 'Unknown',
                albumName: t.albumName,
                durationMs: t.durationMs ?? 0,
              ),
          ],
          startIndex: index,
        );
  }
```
Wire `onTap: () => _playFrom(ordered, i)` in the `ListView.builder`.

- [ ] **Step 6: Run app suite**

Run: `fvm flutter test && fvm flutter analyze`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/audio/ app/lib/features/
git commit -m "feat(app): radio autoplay + album/playlist queue playback"
```

---

## Task B8: App — Queue UI in NowPlayingScreen

**Files:**
- Create: `app/lib/features/now_playing/queue_sheet.dart`
- Modify: `app/lib/features/now_playing/now_playing_screen.dart`

> Show the current `queue` (from `audio_service`'s `queue` stream) in a bottom sheet; tapping an item jumps to it; add skip-next/prev buttons to the now-playing transport.

- [ ] **Step 1: Write the failing widget test** (`app/test/features/now_playing/queue_sheet_test.dart`) — pump `QueueSheet` with an overridden `queueStreamProvider` returning two `MediaItem`s; assert both titles render and tapping calls `skipToQueueItem`.

```dart
// Pump QueueSheet inside ProviderScope overriding queueStreamProvider with
// AsyncValue.data([MediaItem(id:'a',title:'A'), MediaItem(id:'b',title:'B')]).
// expect(find.text('A'), findsOneWidget); expect(find.text('B'), findsOneWidget);
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/features/now_playing/queue_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add a queue stream provider** in `audio_providers.dart`:

```dart
final queueStreamProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(audioHandlerProvider).queue;
});
```
And add `skipToQueueItem` override to the handler:
```dart
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    await playTrack(_queue[_index]);
  }
```

- [ ] **Step 4: Implement `queue_sheet.dart`:**

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueStreamProvider);
    final handler = ref.watch(audioHandlerProvider);
    return queue.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 120, child: Center(child: Text('$e'))),
      data: (items) => ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final it = items[i];
          return ListTile(
            title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: it.artist == null ? null : Text(it.artist!),
            onTap: () => handler.skipToQueueItem(i),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Wire into NowPlayingScreen** — add a "queue" icon button that opens `showModalBottomSheet(context: ..., builder: (_) => const QueueSheet())`, and add `IconButton`s for `skipToPrevious`/`skipToNext` around the play/pause control.

- [ ] **Step 6: Run + analyze**

Run: `fvm flutter test && fvm flutter analyze`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/now_playing/ app/lib/core/audio/audio_providers.dart app/test/features/now_playing/
git commit -m "feat(app): queue sheet + skip controls in now-playing"
```

---

## Task B9: Part B integration + deploy + manual QA

- [ ] **Step 1:** Full suites green (`uv run pytest -q`, `fvm flutter test`, `fvm flutter analyze`).
- [ ] **Step 2:** PR + deploy backend to VM 101; `curl` `/v1/radio?seedVideoId=<id>` and `/v1/up-next?videoId=<id>` through CF Access → 200 with items.
- [ ] **Step 3:** Simulator QA: play a song → confirm it continues to the next track automatically (radio autoplay); open the queue sheet; skip next/prev; play an album from a mid-track and confirm the queue order.
- [ ] **Step 4:** Log + update `Projects/yt-music.md` roadmap (Part B done).

---

# PART C — Home Feed

## Task C1: Backend — home models

**Files:**
- Modify: `backend/src/ytmusic_api/models/discovery.py`

- [ ] **Step 1: Add models:**

```python
class HomeItem(BaseModel):
    # Discriminated loosely by which id is set.
    kind: str  # 'song' | 'album' | 'artist' | 'playlist'
    title: str
    videoId: str | None = None
    browseId: str | None = None
    playlistId: str | None = None
    artistName: str | None = None
    thumbnail: Thumbnail | None = None


class HomeSection(BaseModel):
    title: str
    items: list[HomeItem]


class HomeResponse(BaseModel):
    sections: list[HomeSection]
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/models/discovery.py
git commit -m "feat(backend): home feed models"
```

---

## Task C2: Backend — `YTMusicClient.get_home`

**Files:**
- Modify: `backend/src/ytmusic_api/services/ytmusic_client.py`

- [ ] **Step 1: Add method:**

```python
    async def get_home(self, *, limit: int = 5) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_home(limit=limit)

        return await asyncio.to_thread(_call)
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/ytmusic_api/services/ytmusic_client.py
git commit -m "feat(backend): YTMusicClient get_home wrapper"
```

---

## Task C3: Backend — `GET /v1/home` (TDD)

**Files:**
- Modify: `backend/src/ytmusic_api/routers/discovery.py`
- Test: `backend/tests/test_discovery.py`

- [ ] **Step 1: Add failing tests** (the fake `_FakeYTMusic` already has `home_payload` + `get_home`):

```python
def test_home_returns_sections_with_typed_items(disco_client, fake_ytm):
    fake_ytm.home_payload = [
        {
            "title": "Quick picks",
            "contents": [
                {
                    "title": "Gravity",
                    "videoId": "EludZd6lfts",
                    "artists": [{"name": "yetep", "id": "UCx"}],
                    "thumbnails": [{"url": "https://t/s.jpg", "width": 60, "height": 60}],
                },
                {
                    "title": "Sentiment",
                    "browseId": "MPREb_QtqXtd2xZMR",
                    "thumbnails": [{"url": "https://t/al.jpg", "width": 226, "height": 226}],
                },
                {
                    "title": "r/EDM top",
                    "playlistId": "PLz7",
                    "thumbnails": [],
                },
                {
                    "title": "Chill Satellite",
                    "browseId": "UCrPLFBWdOroD57bkqPbZJog",
                    "subscribers": "374",
                    "thumbnails": [],
                },
            ],
        }
    ]
    r = disco_client.get("/v1/home")
    assert r.status_code == 200
    sections = r.json()["sections"]
    assert sections[0]["title"] == "Quick picks"
    items = sections[0]["items"]
    kinds = [it["kind"] for it in items]
    assert kinds == ["song", "album", "playlist", "artist"]
    assert items[0]["videoId"] == "EludZd6lfts"
    assert items[0]["artistName"] == "yetep"
    assert items[1]["browseId"] == "MPREb_QtqXtd2xZMR"
    assert items[2]["playlistId"] == "PLz7"
    assert items[3]["kind"] == "artist"


def test_home_is_cached(disco_client, fake_ytm):
    fake_ytm.home_payload = [{"title": "X", "contents": []}]
    disco_client.get("/v1/home")
    fake_ytm.home_payload = [{"title": "CHANGED", "contents": []}]
    r = disco_client.get("/v1/home")
    assert r.json()["sections"][0]["title"] == "X"  # served from cache
```

- [ ] **Step 2: Run to verify fail**

Run: `cd backend && uv run pytest tests/test_discovery.py -k home -q`
Expected: FAIL.

- [ ] **Step 3: Implement** (add to `discovery.py`; import the new models):

```python
from ..models.discovery import (
    HomeItem,
    HomeResponse,
    HomeSection,
    QueueItem,
    QueueResponse,
)

_HOME_TTL = 5 * 60  # 5 minutes


def _classify_home_item(raw: dict[str, Any]) -> HomeItem | None:
    title = raw.get("title")
    if not title:
        return None
    thumbs = raw.get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None

    if raw.get("videoId"):
        kind = "song"
    elif raw.get("playlistId"):
        kind = "playlist"
    elif raw.get("subscribers") is not None:
        kind = "artist"
    elif raw.get("browseId"):
        kind = "album"
    else:
        return None

    return HomeItem(
        kind=kind,
        title=title,
        videoId=raw.get("videoId"),
        browseId=raw.get("browseId"),
        playlistId=raw.get("playlistId"),
        artistName=artist_name,
        thumbnail=thumb,
    )


@router.get("/home", response_model=HomeResponse)
async def get_home(request: Request) -> HomeResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = "home"
    cached = cache.get(cache_key)
    if cached is not None:
        return HomeResponse.model_validate(cached)

    try:
        raw_rows = await ytm.get_home(limit=5)
    except Exception as exc:
        logger.exception("get_home failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    sections: list[HomeSection] = []
    for row in raw_rows:
        contents = row.get("contents") or []
        items = [n for n in (_classify_home_item(c) for c in contents) if n is not None]
        if items:
            sections.append(HomeSection(title=row.get("title", ""), items=items))
    response = HomeResponse(sections=sections)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_HOME_TTL)
    return response
```

> `_classify_home_item` checks `videoId` before `browseId` because some song rows also carry other ids; artists are detected by the presence of `subscribers`.

- [ ] **Step 4: Run full suite + lint**

Run: `cd backend && uv run pytest -q && uv run ruff check src tests`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add backend/src/ytmusic_api/routers/discovery.py backend/tests/test_discovery.py
git commit -m "feat(backend): GET /v1/home feed (5min cache)"
```

---

## Task C4: App — home model + `ApiClient.getHome` (TDD)

**Files:**
- Create: `app/lib/core/api/models/home_feed.dart`
- Modify: `app/lib/core/api/api_client.dart`
- Test: `app/test/core/api/api_client_home_test.dart`

- [ ] **Step 1: Write the failing test** (capture-interceptor style):

```dart
  test('getHome hits /v1/home and parses sections', () async {
    final cap = _CaptureInterceptor({
      'sections': [
        {
          'title': 'Quick picks',
          'items': [
            {'kind': 'song', 'title': 'Gravity', 'videoId': 'v1', 'artistName': 'yetep'},
          ],
        },
      ],
    });
    final home = await _clientWith(cap).getHome();
    expect(cap.path, '/v1/home');
    expect(home.single.title, 'Quick picks');
    expect(home.single.items.single.videoId, 'v1');
  });
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/core/api/api_client_home_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `home_feed.dart`:**

```dart
import 'package:ytmusic/core/api/models/track.dart';

class HomeItem {
  HomeItem({
    required this.kind,
    required this.title,
    this.videoId,
    this.browseId,
    this.playlistId,
    this.artistName,
    this.thumbnail,
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) => HomeItem(
        kind: json['kind'] as String,
        title: json['title'] as String,
        videoId: json['videoId'] as String?,
        browseId: json['browseId'] as String?,
        playlistId: json['playlistId'] as String?,
        artistName: json['artistName'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String kind; // song | album | artist | playlist
  final String title;
  final String? videoId;
  final String? browseId;
  final String? playlistId;
  final String? artistName;
  final Thumbnail? thumbnail;
}

class HomeSection {
  HomeSection({required this.title, required this.items});

  factory HomeSection.fromJson(Map<String, dynamic> json) => HomeSection(
        title: json['title'] as String,
        items: (json['items'] as List)
            .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String title;
  final List<HomeItem> items;
}
```

- [ ] **Step 4: Implement client method:**

```dart
  Future<List<HomeSection>> getHome() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/home');
      return (res.data!['sections'] as List)
          .map((e) => HomeSection.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? 0, e.message ?? 'Network error');
    }
  }
```

- [ ] **Step 5: Run to verify pass**

Run: `fvm flutter test test/core/api/api_client_home_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/api/models/home_feed.dart app/lib/core/api/api_client.dart app/test/core/api/api_client_home_test.dart
git commit -m "feat(app): HomeSection model + getHome"
```

---

## Task C5: App — `HomeScreen` + controller (widget test)

**Files:**
- Create: `app/lib/features/home/home_controller.dart`, `app/lib/features/home/home_screen.dart`
- Test: `app/test/features/home/home_screen_test.dart`

- [ ] **Step 1: Write the failing widget test** — override `homeFeedProvider` with two sections; assert section titles + an item title render.

```dart
// override homeFeedProvider.overrideWith((ref) async => [
//   HomeSection(title: 'Quick picks', items: [HomeItem(kind: 'song', title: 'Gravity', videoId: 'v1')]),
// ]);
// expect(find.text('Quick picks'), findsOneWidget);
// expect(find.text('Gravity'), findsOneWidget);
```

- [ ] **Step 2: Run to verify fail**

Run: `fvm flutter test test/features/home/home_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `home_controller.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';

final homeFeedProvider =
    FutureProvider.autoDispose<List<HomeSection>>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) {
    throw StateError('Client not configured');
  }
  return api.getHome();
});
```

- [ ] **Step 4: Implement `home_screen.dart`** — vertical list of sections, each a horizontal row of tiles; tap routes by `kind` (song → `playTrackWithAutoplay` + `/now-playing`; album → `/albums/:browseId`; artist → `/artists/:browseId`; playlist → `/library/playlists/:playlistId`):

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/features/home/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _onTap(BuildContext context, WidgetRef ref, HomeItem it) {
    switch (it.kind) {
      case 'song':
        if (it.videoId == null) return;
        ref.read(audioHandlerProvider).playTrackWithAutoplay(
              Track(
                videoId: it.videoId!,
                title: it.title,
                artistName: it.artistName ?? 'Unknown',
                durationMs: 0,
                thumbnail: it.thumbnail,
              ),
            );
        context.push('/now-playing');
      case 'album':
        if (it.browseId != null) context.push('/albums/${it.browseId}');
      case 'artist':
        if (it.browseId != null) context.push('/artists/${it.browseId}');
      case 'playlist':
        if (it.playlistId != null) {
          context.push('/library/playlists/${it.playlistId}');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            onPressed: () => context.push('/library'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sections) => RefreshIndicator(
          onRefresh: () async => ref.refresh(homeFeedProvider.future),
          child: ListView.builder(
            itemCount: sections.length,
            itemBuilder: (ctx, i) {
              final s = sections[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(s.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: s.items.length,
                      itemBuilder: (ctx, j) {
                        final it = s.items[j];
                        return GestureDetector(
                          onTap: () => _onTap(context, ref, it),
                          child: SizedBox(
                            width: 130,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 122,
                                    height: 122,
                                    child: it.thumbnail == null
                                        ? const ColoredBox(color: Colors.black26)
                                        : CachedNetworkImage(
                                            imageUrl: it.thumbnail!.url,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(it.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `fvm flutter test test/features/home/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/home/ app/test/features/home/
git commit -m "feat(app): HomeScreen discovery feed"
```

---

## Task C6: App — route `/home` + make it the landing screen

**Files:**
- Modify: `app/lib/routing/app_router.dart`

- [ ] **Step 1: Add the route + change initial location:**

```dart
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
```
Change `initialLocation: '/search'` → `initialLocation: '/home'`, and update the post-onboarding redirect target from `'/search'` to `'/home'`. Add the `HomeScreen` import.

- [ ] **Step 2: Verify**

Run: `fvm flutter analyze && fvm flutter test`
Expected: clean + PASS. (Check that the onboarding-redirect test, if any, still passes; update its expected target to `/home`.)

- [ ] **Step 3: Commit**

```bash
git add app/lib/routing/app_router.dart
git commit -m "feat(app): route /home and make it the landing screen"
```

---

## Task C7: Part C integration + deploy + manual QA + docs

- [ ] **Step 1:** Full suites green; `fvm flutter analyze` clean.
- [ ] **Step 2:** PR + deploy backend to VM 101; `curl /v1/home` through CF Access → 200 with sections.
- [ ] **Step 3:** Simulator QA: launch → home feed renders sections; tap a song (autoplays), an album (detail), an artist (detail), a playlist (detail).
- [ ] **Step 4:** Update `Projects/yt-music.md` — mark Phase 3 ✅ done, add the five new endpoints to the API surface, and append a final `yt-music-logs/` entry.

---

## Self-Review notes (for the implementer)

- **Spec coverage:** §2.1 endpoints `/album`, `/artist`, `/home`, `/radio`, `/up-next` → Tasks A3, A4, C3, B3, B4. §8 Phase-3 deliverables "detail screens, home feed, queue UI, radio autoplay" → A9, A10, C5, B8, B7. ✅
- **Caching (§2.5):** album/artist 24h (A3/A4), home/radio 5min (B3/C3). ✅
- **Type consistency:** `Track` is used across screens — it must expose `videoId,title,artistName,albumName,albumBrowseId,durationMs,thumbnail`. Confirm the existing `track.dart` constructor matches before B5/B7 (the `toTrack()` and `_toMediaItem` helpers depend on it). If `albumBrowseId`/`thumbnail` are missing from `Track`, add them in a small preparatory step.
- **Watch-track shape gotcha:** `/radio` + `/up-next` items have `length` (string) and singular `thumbnail` (list), not `duration_seconds`/`thumbnails` — handled in `_normalise_queue_item` / `_watch_thumb`. `durationMs` is intentionally null for queue items; the player measures real duration at playback.
- **Concurrency/account safety (§2.6):** these are metadata reads (single upstream call each), so no extra concurrency cap needed beyond the existing stream-resolution `BoundedRunner`.
