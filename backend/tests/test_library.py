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


def test_liked_is_not_cached_server_side(library_client, fake_ytm, cache):
    """Spec §2.5: /library/* is never cached server-side.

    Even if the cache contains a stale value under any plausible key, the
    router must ignore it and re-hit the upstream every time.
    """
    fake_ytm.liked_payload = {"tracks": [_liked_track("v1")]}
    # Pre-poison every plausible cache key the router might use:
    poison = {"items": [{"videoId": "STALE", "title": "stale"}], "continuation": None}
    for key in ("library:liked", "library:liked:100", "/v1/library/liked"):
        cache.set(key, poison, ttl_seconds=600)

    r1 = library_client.get("/v1/library/liked")
    r2 = library_client.get("/v1/library/liked")

    # Both responses reflect the live fake payload, never the poisoned cache:
    assert [it["videoId"] for it in r1.json()["items"]] == ["v1"]
    assert [it["videoId"] for it in r2.json()["items"]] == ["v1"]


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
    assert body["items"][1]["trackCount"] is None


def test_playlists_skips_items_missing_id(library_client, fake_ytm):
    bad = _playlist_summary("PL1")
    bad.pop("playlistId")
    fake_ytm.playlists_payload = [bad, _playlist_summary("PL2")]
    r = library_client.get("/v1/library/playlists")
    assert [p["browseId"] for p in r.json()["items"]] == ["PL2"]


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
