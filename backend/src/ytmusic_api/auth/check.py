"""Real ytmusicapi-backed auth check used in production."""
from __future__ import annotations

import asyncio
import logging

from .headers import HeadersStore

logger = logging.getLogger(__name__)


def make_real_check(store: HeadersStore):
    """Returns an async callable that pings ytmusicapi.

    Raises if cookies invalid or unloaded.
    """

    async def check() -> None:
        headers = store.current()
        if headers is None:
            raise RuntimeError("headers not loaded")

        # ytmusicapi is sync; offload to thread.
        def _probe() -> None:
            from ytmusicapi import YTMusic

            client = YTMusic(auth=headers)
            # Cheapest authenticated call: get_library_songs(limit=1).
            client.get_library_songs(limit=1)

        await asyncio.to_thread(_probe)

    return check
