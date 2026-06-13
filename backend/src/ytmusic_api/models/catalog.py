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


class AlbumTrack(BaseModel):
    videoId: str
    title: str
    artistName: str | None = None
    durationMs: int | None = None
    trackNumber: int | None = None
    thumbnail: Thumbnail | None = None


class AlbumDetailResponse(BaseModel):
    browseId: str
    title: str
    artistName: str | None = None
    artistBrowseId: str | None = None
    year: int | None = None
    trackCount: int | None = None
    thumbnail: Thumbnail | None = None
    audioPlaylistId: str | None = None
    items: list[AlbumTrack]


class ArtistTopSong(BaseModel):
    videoId: str
    title: str
    albumName: str | None = None
    thumbnail: Thumbnail | None = None


class ArtistAlbum(BaseModel):
    browseId: str
    title: str
    year: int | None = None
    thumbnail: Thumbnail | None = None


class ArtistDetailResponse(BaseModel):
    browseId: str
    name: str
    description: str | None = None
    subscriberCount: str | None = None
    thumbnail: Thumbnail | None = None
    radioId: str | None = None
    topSongs: list[ArtistTopSong]
    albums: list[ArtistAlbum]
    singles: list[ArtistAlbum]
