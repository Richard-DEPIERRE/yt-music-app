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
