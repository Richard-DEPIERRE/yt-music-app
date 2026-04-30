"""Real ytmusicapi-backed auth check used in production."""
from __future__ import annotations

import logging

from ..services.ytmusic_client import YTMusicClient

logger = logging.getLogger(__name__)


def make_real_check(client: YTMusicClient):
    """Returns an async callable that pings ytmusicapi.

    Raises if cookies invalid or unloaded.
    """

    async def check() -> None:
        await client.get_library_songs(limit=1)

    return check
