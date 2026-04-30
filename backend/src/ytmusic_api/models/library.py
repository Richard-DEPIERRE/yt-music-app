# backend/src/ytmusic_api/models/library.py
from __future__ import annotations

from pydantic import BaseModel

from .catalog import Thumbnail


class LikedSong(BaseModel):
    videoId: str
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None


class LikedSongsResponse(BaseModel):
    items: list[LikedSong]
    continuation: str | None = None


class PlaylistSummary(BaseModel):
    browseId: str
    title: str
    description: str | None
    trackCount: int | None
    thumbnail: Thumbnail | None
    isOwn: bool


class PlaylistsResponse(BaseModel):
    items: list[PlaylistSummary]
    continuation: str | None = None


class PlaylistTrack(BaseModel):
    videoId: str
    setVideoId: str | None
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None


class PlaylistDetailResponse(BaseModel):
    browseId: str
    title: str
    description: str | None
    ownerName: str | None
    trackCount: int | None
    items: list[PlaylistTrack]
    continuation: str | None = None


class ArtistSubscription(BaseModel):
    browseId: str
    name: str
    thumbnail: Thumbnail | None
    subscriberCount: str | None


class SubscriptionsResponse(BaseModel):
    items: list[ArtistSubscription]
    continuation: str | None = None


class HistoryItem(BaseModel):
    videoId: str
    title: str
    artistName: str | None
    albumName: str | None
    albumBrowseId: str | None
    durationMs: int | None
    thumbnail: Thumbnail | None
    playedSection: str | None


class HistoryResponse(BaseModel):
    items: list[HistoryItem]
    continuation: str | None = None
