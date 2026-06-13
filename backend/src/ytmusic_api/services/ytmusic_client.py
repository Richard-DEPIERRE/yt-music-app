from __future__ import annotations

import asyncio
import logging
from typing import Any

from ..auth.headers import HeadersStore

logger = logging.getLogger(__name__)

# Our API contract uses singular `type` values (see design spec §2.1); ytmusicapi's
# `search(filter=...)` requires the plural form. Translate at this boundary.
_SEARCH_FILTER_MAP = {
    "song": "songs",
    "album": "albums",
    "artist": "artists",
    "playlist": "playlists",
    "video": "videos",
}


class YTMusicClient:
    """Async wrapper around ytmusicapi.YTMusic.

    Delegates blocking calls to a thread. The caller-visible API is async.
    Constructs a fresh underlying YTMusic per call so it always picks up the
    latest headers from HeadersStore (which hot-reloads on file change).
    """

    def __init__(self, store: HeadersStore) -> None:
        self._store = store

    def _build(self):
        from ytmusicapi import YTMusic

        headers = self._store.current()
        if headers is None:
            raise RuntimeError("ytmusicapi headers not loaded")
        return YTMusic(auth=headers)

    async def search(
        self,
        query: str,
        *,
        filter_type: str | None,
        limit: int,
    ) -> list[dict[str, Any]]:
        ytm_filter = (
            _SEARCH_FILTER_MAP.get(filter_type, filter_type)
            if filter_type is not None
            else None
        )

        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.search(query, filter=ytm_filter, limit=limit)

        return await asyncio.to_thread(_call)

    async def get_song(self, video_id: str) -> dict[str, Any]:
        def _call() -> dict[str, Any]:
            client = self._build()
            return client.get_song(video_id)

        return await asyncio.to_thread(_call)

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

    async def get_home(self, *, limit: int = 5) -> list[dict[str, Any]]:
        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_home(limit=limit)

        return await asyncio.to_thread(_call)

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

    async def get_library_songs(self, limit: int = 1) -> list[dict[str, Any]]:
        """Cheap authenticated probe used by AuthHealthMonitor."""

        def _call() -> list[dict[str, Any]]:
            client = self._build()
            return client.get_library_songs(limit=limit)

        return await asyncio.to_thread(_call)

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
