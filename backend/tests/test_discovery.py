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
        self.watch_calls: int = 0
        # Forward-prep for Part C's /home endpoint — not used by radio/up-next tests.
        self.home_payload: list[dict[str, Any]] = []

    async def get_watch_playlist(  # type: ignore[override]
        self, *, video_id=None, playlist_id=None, radio=False, limit=25
    ):
        self.watch_calls += 1
        self.last_call = {
            "video_id": video_id,
            "playlist_id": playlist_id,
            "radio": radio,
            "limit": limit,
        }
        return self.watch_payload

    # Forward-prep for Part C's /home endpoint — not used by radio/up-next tests.
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


def test_radio_caches_per_seed(disco_client, fake_ytm):
    fake_ytm.watch_payload = {"tracks": [_watch_track("v1")]}
    disco_client.get("/v1/radio?seedVideoId=v0")
    disco_client.get("/v1/radio?seedVideoId=v0")
    assert fake_ytm.watch_calls == 1


def test_up_next_caches_per_video_and_radio_flag(disco_client, fake_ytm):
    fake_ytm.watch_payload = {"tracks": [_watch_track("v1")]}
    disco_client.get("/v1/up-next?videoId=v0&radio=true")
    disco_client.get("/v1/up-next?videoId=v0&radio=true")
    assert fake_ytm.watch_calls == 1
    # different radio flag is a distinct cache entry → second upstream call
    disco_client.get("/v1/up-next?videoId=v0&radio=false")
    assert fake_ytm.watch_calls == 2


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
    assert r.json()["sections"] == []  # served from cache (empty — no classifiable items)
