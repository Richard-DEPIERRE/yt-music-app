from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import (
    AlbumDetailResponse,
    AlbumTrack,
    ArtistAlbum,
    ArtistDetailResponse,
    ArtistTopSong,
    SearchResponse,
    SearchResult,
    Thumbnail,
    TrackResponse,
)
from ..services.cache import TtlCache
from ..services.ytmusic_client import YTMusicClient

logger = logging.getLogger(__name__)

router = APIRouter()

_SEARCH_TTL = 5 * 60  # 5 minutes
_TRACK_TTL = 24 * 60 * 60  # 24 hours
_ALBUM_TTL = 24 * 60 * 60  # 24 hours
_ARTIST_TTL = 24 * 60 * 60  # 24 hours


def _normalise_search_item(raw: dict[str, Any]) -> SearchResult | None:
    """Map ytmusicapi search shape to our wire format. Returns None for unknown types."""
    rt = raw.get("resultType") or raw.get("type")
    if rt not in {"song", "video", "album", "artist", "playlist"}:
        return None

    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None
    album = raw.get("album") or {}
    album_name = album.get("name") if isinstance(album, dict) else album
    thumbs = raw.get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    duration_seconds = raw.get("duration_seconds")
    return SearchResult(
        type=rt,
        videoId=raw.get("videoId"),
        browseId=raw.get("browseId"),
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        durationMs=int(duration_seconds * 1000) if duration_seconds else None,
        thumbnail=thumb,
    )


@router.get("/search", response_model=SearchResponse)
async def search(
    request: Request,
    q: str = Query(..., min_length=1),
    type: str | None = Query(None, pattern=r"^(song|album|artist|playlist|video)$"),
    limit: int = Query(20, ge=1, le=50),
) -> SearchResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"search:{type or 'any'}:{limit}:{q}"
    cached = cache.get(cache_key)
    if cached is not None:
        return SearchResponse.model_validate(cached)

    raw = await ytm.search(q, filter_type=type, limit=limit)
    items = [n for n in (_normalise_search_item(r) for r in raw) if n is not None]
    response = SearchResponse(items=items, continuation=None)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_SEARCH_TTL)
    return response


@router.get("/track/{video_id}", response_model=TrackResponse)
async def get_track(request: Request, video_id: str) -> TrackResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"track:{video_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return TrackResponse.model_validate(cached)

    try:
        raw = await ytm.get_song(video_id)
    except Exception as exc:  # ytmusicapi raises bare Exceptions on 404
        raise HTTPException(status_code=404, detail=f"track not found: {exc}") from exc

    details = raw.get("videoDetails") or {}
    thumbs = (details.get("thumbnail") or {}).get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    response = TrackResponse(
        videoId=video_id,
        title=details.get("title", ""),
        artistName=details.get("author", ""),
        albumName=None,
        albumBrowseId=None,
        artistBrowseId=None,
        durationMs=int(details.get("lengthSeconds", 0)) * 1000,
        thumbnail=thumb,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_TRACK_TTL)
    return response


def _parse_year(raw: Any) -> int | None:
    try:
        return int(str(raw)[:4])
    except (TypeError, ValueError):
        return None


def _first_artist(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    artists = raw.get("artists") or []
    if not artists:
        return None, None
    return artists[0].get("name"), artists[0].get("id")


def _normalise_album_track(raw: dict[str, Any]) -> AlbumTrack | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    name, _ = _first_artist(raw)
    secs = raw.get("duration_seconds")
    thumbs = raw.get("thumbnails") or []
    return AlbumTrack(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=name,
        durationMs=None if secs is None else int(secs * 1000),
        trackNumber=raw.get("trackNumber"),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


@router.get("/album/{browse_id}", response_model=AlbumDetailResponse)
async def get_album(request: Request, browse_id: str) -> AlbumDetailResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"album:{browse_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return AlbumDetailResponse.model_validate(cached)

    try:
        raw = await ytm.get_album(browse_id)
    except Exception as exc:
        logger.exception("get_album upstream error (browse_id=%s)", browse_id)
        raise HTTPException(status_code=404, detail=f"album not found: {exc}") from exc

    artist_name, artist_bid = _first_artist(raw)
    thumbs = raw.get("thumbnails") or []
    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_album_track(t) for t in tracks) if n is not None]
    response = AlbumDetailResponse(
        browseId=browse_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        artistBrowseId=artist_bid,
        year=_parse_year(raw.get("year")),
        trackCount=raw.get("trackCount") if raw.get("trackCount") is not None else len(items),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
        audioPlaylistId=raw.get("audioPlaylistId"),
        items=items,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_ALBUM_TTL)
    return response


def _normalise_artist_song(raw: dict[str, Any]) -> ArtistTopSong | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    album = raw.get("album")
    album_name = album.get("name") if isinstance(album, dict) else album
    thumbs = raw.get("thumbnails") or []
    return ArtistTopSong(
        videoId=video_id,
        title=raw.get("title", ""),
        albumName=album_name,
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


def _normalise_artist_album(raw: dict[str, Any]) -> ArtistAlbum | None:
    bid = raw.get("browseId")
    if not bid:
        return None
    thumbs = raw.get("thumbnails") or []
    return ArtistAlbum(
        browseId=bid,
        title=raw.get("title", ""),
        year=_parse_year(raw.get("year")),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
    )


@router.get("/artist/{browse_id}", response_model=ArtistDetailResponse)
async def get_artist(request: Request, browse_id: str) -> ArtistDetailResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"artist:{browse_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return ArtistDetailResponse.model_validate(cached)

    try:
        raw = await ytm.get_artist(browse_id)
    except Exception as exc:
        logger.exception("get_artist upstream error (browse_id=%s)", browse_id)
        raise HTTPException(status_code=404, detail=f"artist not found: {exc}") from exc

    songs = (raw.get("songs") or {}).get("results") or []
    albums = (raw.get("albums") or {}).get("results") or []
    singles = (raw.get("singles") or {}).get("results") or []
    thumbs = raw.get("thumbnails") or []
    response = ArtistDetailResponse(
        browseId=browse_id,
        name=raw.get("name", ""),
        description=raw.get("description"),
        subscriberCount=raw.get("subscribers"),
        thumbnail=Thumbnail(**thumbs[-1]) if thumbs else None,
        radioId=raw.get("radioId"),
        topSongs=[n for n in (_normalise_artist_song(s) for s in songs) if n is not None],
        albums=[n for n in (_normalise_artist_album(a) for a in albums) if n is not None],
        singles=[n for n in (_normalise_artist_album(a) for a in singles) if n is not None],
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_ARTIST_TTL)
    return response
