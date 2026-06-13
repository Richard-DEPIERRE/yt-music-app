from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Request

from ..models.downloads import (
    ManifestError,
    ManifestItem,
    ManifestRequest,
    ManifestResponse,
)
from ..services.cache import TtlCache
from ..services.concurrency import BoundedRunner
from ..services.stream_resolver import StreamResolver

logger = logging.getLogger(__name__)
router = APIRouter()

_STREAM_TTL = 25 * 60  # match the single-track stream cache


@router.post("/downloads/manifest", response_model=ManifestResponse)
async def manifest(request: Request, body: ManifestRequest) -> ManifestResponse:
    cache: TtlCache = request.app.state.cache
    resolver: StreamResolver = request.app.state.stream_resolver
    runner: BoundedRunner = request.app.state.stream_runner

    async def resolve_one(video_id: str) -> ManifestItem | ManifestError:
        cache_key = f"stream:{video_id}:{body.codec}:{body.quality}"
        cached = cache.get(cache_key)
        if cached is not None:
            return ManifestItem(
                videoId=cached["videoId"],
                url=cached["url"],
                expiresAt=cached["expiresAt"],
                codec=cached["codec"],
                container=cached["container"],
                bitrate=cached["bitrate"],
                contentLength=cached.get("contentLength"),
                artworkUrl=cached.get("artworkUrl"),
            )
        try:
            resolved = await runner.run(
                resolver.resolve, video_id, codec=body.codec, quality=body.quality
            )
        except Exception as exc:  # noqa: BLE001 - per-item isolation
            logger.warning("Manifest resolution failed for %s: %s", video_id, exc)
            return ManifestError(videoId=video_id, error="upstream_breakage")

        item = ManifestItem(
            videoId=resolved.video_id,
            url=resolved.url,
            expiresAt=resolved.expires_at,
            codec=resolved.codec,
            container=resolved.container,
            bitrate=resolved.bitrate,
            contentLength=resolved.content_length,
            artworkUrl=resolved.artwork_url,
        )
        cache.set(cache_key, item.model_dump(mode="json"), ttl_seconds=_STREAM_TTL)
        return item

    results = await asyncio.gather(*(resolve_one(v) for v in body.videoIds))
    items = [r for r in results if isinstance(r, ManifestItem)]
    errors = [r for r in results if isinstance(r, ManifestError)]
    return ManifestResponse(items=items, errors=errors)
