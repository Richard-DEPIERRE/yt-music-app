# backend/src/ytmusic_api/routers/library.py
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.catalog import Thumbnail
from ..models.library import (
    LikedSong,
    LikedSongsResponse,
)
from ..services.ytmusic_client import YTMusicClient

router = APIRouter()


def _last_thumb(raw: dict[str, Any]) -> Thumbnail | None:
    thumbs = raw.get("thumbnails") or []
    return Thumbnail(**thumbs[-1]) if thumbs else None


def _track_artist_name(raw: dict[str, Any]) -> str | None:
    artists = raw.get("artists") or []
    return artists[0]["name"] if artists else None


def _track_album(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    album = raw.get("album") or {}
    if isinstance(album, dict):
        return album.get("name"), album.get("id")
    return album, None


def _normalise_liked(raw: dict[str, Any]) -> LikedSong | None:
    video_id = raw.get("videoId")
    if not video_id:
        return None
    artist_name = _track_artist_name(raw)
    album_name, album_bid = _track_album(raw)
    duration_seconds = raw.get("duration_seconds")
    return LikedSong(
        videoId=video_id,
        title=raw.get("title", ""),
        artistName=artist_name,
        albumName=album_name,
        albumBrowseId=album_bid,
        durationMs=None if duration_seconds is None else int(duration_seconds * 1000),
        thumbnail=_last_thumb(raw),
    )


@router.get("/library/liked", response_model=LikedSongsResponse)
async def get_liked(
    request: Request,
    limit: int = Query(100, ge=1, le=500),
) -> LikedSongsResponse:
    ytm: YTMusicClient = request.app.state.ytmusic_client
    try:
        raw = await ytm.get_liked_songs(limit=limit)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"upstream: {exc}") from exc
    tracks = raw.get("tracks") or []
    items = [n for n in (_normalise_liked(t) for t in tracks) if n is not None]
    return LikedSongsResponse(items=items, continuation=None)
