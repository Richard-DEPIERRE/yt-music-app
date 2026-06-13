"""Tests for YTMusicClient's translation of our API contract to ytmusicapi.

These tests exercise the real YTMusicClient.search against a recording stand-in
for the underlying ytmusicapi.YTMusic, so they catch contract mismatches that
the route-level tests (which mock YTMusicClient entirely) cannot — notably the
singular-vs-plural `filter` bug.
"""

from __future__ import annotations

from typing import Any

import pytest

from ytmusic_api.services.ytmusic_client import YTMusicClient


class _RecordingYTMusic:
    """Stands in for ytmusicapi.YTMusic; records the kwargs it was called with."""

    def __init__(self) -> None:
        self.captured: dict[str, Any] = {}

    def search(self, query: str, *, filter: str | None, limit: int):  # noqa: A002
        self.captured = {"query": query, "filter": filter, "limit": limit}
        return []


class _ClientWithFakeBuild(YTMusicClient):
    """YTMusicClient whose _build() returns our recording fake."""

    def __init__(self, fake: _RecordingYTMusic) -> None:
        self._fake = fake

    def _build(self):  # type: ignore[override]
        return self._fake


@pytest.mark.parametrize(
    ("api_type", "expected_filter"),
    [
        ("song", "songs"),
        ("album", "albums"),
        ("artist", "artists"),
        ("playlist", "playlists"),
        ("video", "videos"),
    ],
)
async def test_search_maps_singular_type_to_plural_filter(api_type, expected_filter):
    fake = _RecordingYTMusic()
    client = _ClientWithFakeBuild(fake)

    await client.search("hello", filter_type=api_type, limit=5)

    assert fake.captured["filter"] == expected_filter


async def test_search_passes_none_filter_through():
    fake = _RecordingYTMusic()
    client = _ClientWithFakeBuild(fake)

    await client.search("hello", filter_type=None, limit=5)

    assert fake.captured["filter"] is None
