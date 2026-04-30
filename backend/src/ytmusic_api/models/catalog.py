from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

ResultType = Literal["song", "video", "album", "artist", "playlist"]


class Thumbnail(BaseModel):
    url: str
    width: int | None = None
    height: int | None = None


class SearchResult(BaseModel):
    type: ResultType
    videoId: str | None = None
    browseId: str | None = None
    title: str
    artistName: str | None = None
    albumName: str | None = None
    durationMs: int | None = None
    thumbnail: Thumbnail | None = None


class SearchResponse(BaseModel):
    items: list[SearchResult]
    continuation: str | None = None


class TrackResponse(BaseModel):
    videoId: str
    title: str
    artistName: str
    albumName: str | None = None
    albumBrowseId: str | None = None
    artistBrowseId: str | None = None
    durationMs: int
    thumbnail: Thumbnail | None = None
