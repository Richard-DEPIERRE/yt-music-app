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
