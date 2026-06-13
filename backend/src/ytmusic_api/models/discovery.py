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


class HomeItem(BaseModel):
    # Discriminated loosely by which id is set.
    kind: str  # 'song' | 'album' | 'artist' | 'playlist'
    title: str
    videoId: str | None = None
    browseId: str | None = None
    playlistId: str | None = None
    artistName: str | None = None
    thumbnail: Thumbnail | None = None


class HomeSection(BaseModel):
    title: str
    items: list[HomeItem]


class HomeResponse(BaseModel):
    sections: list[HomeSection]
