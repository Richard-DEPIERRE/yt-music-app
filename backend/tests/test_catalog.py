from typing import Any

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.ytmusic_client import YTMusicClient


class _FakeYTMusic(YTMusicClient):  # type: ignore[misc]
    def __init__(self) -> None:
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


@pytest.fixture
def fake_ytm() -> _FakeYTMusic:
    return _FakeYTMusic()


@pytest.fixture
def cache() -> TtlCache:
    return TtlCache()


@pytest.fixture
def catalog_client(headers_store, auth_monitor, fake_ytm, cache) -> TestClient:
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
    assert fake_ytm.search_calls == 1


def test_search_does_not_share_cache_across_queries(catalog_client, fake_ytm):
    fake_ytm.search_results = [_song_payload()]
    catalog_client.get("/v1/search?q=hello")
    catalog_client.get("/v1/search?q=world")
    assert fake_ytm.search_calls == 2
