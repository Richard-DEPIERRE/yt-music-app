from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import SearchResponse, SearchResult, Thumbnail, TrackResponse
from ..services.cache import TtlCache
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()

_SEARCH_TTL = 5 * 60  # 5 minutes
_TRACK_TTL = 24 * 60 * 60  # 24 hours


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
