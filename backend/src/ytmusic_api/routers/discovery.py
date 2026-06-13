from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import Thumbnail
from ..models.discovery import (
    HomeItem,
    HomeResponse,
    HomeSection,
    QueueItem,
    QueueResponse,
)
from ..services.cache import TtlCache
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()
logger = logging.getLogger(__name__)

_QUEUE_TTL = 5 * 60  # 5 minutes — shared by radio and up-next


def _watch_thumb(raw: dict[str, Any]) -> Thumbnail | None:
    # Watch tracks use singular `thumbnail` (a list); fall back to `thumbnails`.
    thumbs = raw.get("thumbnail") or raw.get("thumbnails") or []
    return Thumbnail(**thumbs[-1]) if thumbs else None


def _build_queue_response(
    raw: dict[str, Any], *, cache: TtlCache, cache_key: str
) -> QueueResponse:
    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_queue_item(t) for t in tracks) if n is not None]
    response = QueueResponse(items=items, continuation=None)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_QUEUE_TTL)
    return response


def _normalise_queue_item(raw: dict[str, Any]) -> QueueItem | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None
    album = raw.get("album") or {}
    album_name = album.get("name") if isinstance(album, dict) else album
    album_bid = album.get("id") if isinstance(album, dict) else None
    return QueueItem(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=None,  # watch tracks expose `length` (mm:ss); the player measures real duration
        thumbnail=_watch_thumb(raw),
    )


@router.get("/radio", response_model=QueueResponse)
async def get_radio(
    request: Request,
    seedVideoId: str = Query(..., min_length=1),  # noqa: N803 — wire contract
) -> QueueResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"radio:{seedVideoId}"
    cached = cache.get(cache_key)
    if cached is not None:
        return QueueResponse.model_validate(cached)

    try:
        raw = await ytm.get_watch_playlist(video_id=seedVideoId, radio=True)
    except Exception as exc:
        logger.exception("get_watch_playlist (radio) failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    return _build_queue_response(raw, cache=cache, cache_key=cache_key)


@router.get("/up-next", response_model=QueueResponse)
async def get_up_next(
    request: Request,
    videoId: str = Query(..., min_length=1),  # noqa: N803 — wire contract
    radio: bool = Query(False),
) -> QueueResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = f"upnext:{videoId}:{radio}"
    cached = cache.get(cache_key)
    if cached is not None:
        return QueueResponse.model_validate(cached)

    try:
        raw = await ytm.get_watch_playlist(video_id=videoId, radio=radio)
    except Exception as exc:
        logger.exception("get_watch_playlist (up-next) failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    return _build_queue_response(raw, cache=cache, cache_key=cache_key)


_HOME_TTL = 5 * 60  # 5 minutes


def _classify_home_item(raw: dict[str, Any]) -> HomeItem | None:
    title = raw.get("title")
    if not title:
        return None
    thumbs = raw.get("thumbnails") or []
    thumb = Thumbnail(**thumbs[-1]) if thumbs else None
    artists = raw.get("artists") or []
    artist_name = artists[0]["name"] if artists else None

    if raw.get("videoId"):
        kind = "song"
    elif raw.get("playlistId"):
        kind = "playlist"
    elif raw.get("subscribers") is not None:
        kind = "artist"
    elif raw.get("browseId"):
        kind = "album"
    else:
        return None

    return HomeItem(
        kind=kind,
        title=title,
        videoId=raw.get("videoId"),
        browseId=raw.get("browseId"),
        playlistId=raw.get("playlistId"),
        artistName=artist_name,
        thumbnail=thumb,
    )


@router.get("/home", response_model=HomeResponse)
async def get_home(request: Request) -> HomeResponse:
    cache: TtlCache = request.app.state.cache
    ytm: YTMusicClient = request.app.state.ytmusic_client

    cache_key = "home"
    cached = cache.get(cache_key)
    if cached is not None:
        return HomeResponse.model_validate(cached)

    try:
        raw_rows = await ytm.get_home(limit=5)
    except Exception as exc:
        logger.exception("get_home failure")
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc

    sections: list[HomeSection] = []
    for row in raw_rows:
        contents = row.get("contents") or []
        items = [n for n in (_classify_home_item(c) for c in contents) if n is not None]
        if items:
            sections.append(HomeSection(title=row.get("title", ""), items=items))
    response = HomeResponse(sections=sections)
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_HOME_TTL)
    return response
