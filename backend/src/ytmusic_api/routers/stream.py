from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query, Request

from ..models.stream import StreamResponse
from ..services.cache import TtlCache
from ..services.concurrency import BoundedRunner
from ..services.stream_resolver import StreamResolver

logger = logging.getLogger(__name__)
router = APIRouter()

_STREAM_TTL = 25 * 60  # 25 minutes


@router.get("/track/{video_id}/stream", response_model=StreamResponse)
async def stream(
    request: Request,
    video_id: str,
    codec: str = Query("any", pattern=r"^(any|aac|opus)$"),
    quality: str = Query("high", pattern=r"^(high|medium|low)$"),
) -> StreamResponse:
    cache: TtlCache = request.app.state.cache
    resolver: StreamResolver = request.app.state.stream_resolver
    runner: BoundedRunner = request.app.state.stream_runner

    cache_key = f"stream:{video_id}:{codec}:{quality}"
    cached = cache.get(cache_key)
    if cached is not None:
        return StreamResponse.model_validate(cached)

    try:
        resolved = await runner.run(
            resolver.resolve, video_id, codec=codec, quality=quality
        )
    except Exception as exc:
        logger.warning("Stream resolution failed for %s: %s", video_id, exc)
        raise HTTPException(
            status_code=502,
            detail={
                "error": "upstream_breakage",
                "message": str(exc),
                "retryable": True,
            },
        ) from exc

    response = StreamResponse(
        videoId=resolved.video_id,
        url=resolved.url,
        expiresAt=resolved.expires_at,
        codec=resolved.codec,
        container=resolved.container,
        bitrate=resolved.bitrate,
        approxDurationMs=resolved.approx_duration_ms,
        contentLength=resolved.content_length,
    )
    cache.set(cache_key, response.model_dump(mode="json"), ttl_seconds=_STREAM_TTL)
    return response
