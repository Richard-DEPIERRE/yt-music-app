from __future__ import annotations

import asyncio
import logging
from typing import Any

from ..auth.headers import HeadersStore

logger = logging.getLogger(__name__)


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
