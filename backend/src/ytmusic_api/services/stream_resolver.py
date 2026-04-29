from __future__ import annotations

import asyncio
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Literal
from urllib.parse import parse_qs, urlparse

from yt_dlp import YoutubeDL

logger = logging.getLogger(__name__)

Codec = Literal["aac", "opus", "any"]
Quality = Literal["high", "medium", "low"]


@dataclass(frozen=True)
class ResolvedStream:
    video_id: str
    url: str
    expires_at: datetime
    codec: str
    container: str
    bitrate: int  # bps
    approx_duration_ms: int
    content_length: int | None


_QUALITY_RANGES = {
    "high": (160, 320),
    "medium": (96, 160),
    "low": (32, 96),
}


def _classify_codec(acodec: str | None) -> str | None:
    if not acodec:
        return None
    a = acodec.lower()
    if a == "opus":
        return "opus"
    if a.startswith("mp4a") or "aac" in a:
        return "aac"
    return None


def _pick_format(
    formats: list[dict[str, Any]],
    *,
    codec: str,
    quality: str,
) -> dict[str, Any]:
    """Best-effort: prefer requested codec at requested quality; fall back gracefully."""
    audio_only = [f for f in formats if f.get("acodec") and f.get("acodec") != "none"]
    if not audio_only:
        raise ValueError("no audio formats available")

    quality_min, quality_max = _QUALITY_RANGES[quality]

    def score(f: dict[str, Any]) -> tuple[int, int, int]:
        f_codec = _classify_codec(f.get("acodec")) or ""
        codec_match = (
            2 if (codec == "any" or f_codec == codec) else (1 if f_codec else 0)
        )
        abr = int(f.get("abr") or 0)
        in_range = (
            2 if quality_min <= abr <= quality_max else (1 if abr <= quality_max else 0)
        )
        # Prefer higher bitrate for high/medium; lower for low
        return (codec_match, in_range, abr if quality != "low" else -abr)

    audio_only.sort(key=score, reverse=True)
    return audio_only[0]


def _expires_at_from_url(url: str) -> datetime:
    """googlevideo URLs carry an `expire=<unixts>` query param. Fall back to +6h."""
    qs = parse_qs(urlparse(url).query)
    expire = qs.get("expire") or qs.get("expires")
    if expire:
        try:
            return datetime.utcfromtimestamp(int(expire[0]))
        except (TypeError, ValueError):
            pass
    m = re.search(r"/expire/(\d+)/", url)
    if m:
        try:
            return datetime.utcfromtimestamp(int(m.group(1)))
        except (TypeError, ValueError):
            pass
    return datetime.utcnow() + timedelta(hours=6)


class StreamResolver:
    def __init__(self, *, pot_provider_url: str) -> None:
        self._pot_provider_url = pot_provider_url

    async def resolve(
        self,
        video_id: str,
        *,
        codec: Codec,
        quality: Quality,
    ) -> ResolvedStream:
        return await asyncio.to_thread(self._resolve_sync, video_id, codec, quality)

    def _resolve_sync(self, video_id: str, codec: str, quality: str) -> ResolvedStream:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "format": "bestaudio/best",
            "extractor_args": {
                "youtube": {
                    "po_token_provider_url": [self._pot_provider_url],
                },
            },
        }
        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_id, download=False)

        formats = info.get("formats") or []
        chosen = _pick_format(formats, codec=codec, quality=quality)
        url = chosen["url"]
        expires = _expires_at_from_url(url)

        return ResolvedStream(
            video_id=info.get("id", video_id),
            url=url,
            expires_at=expires,
            codec=_classify_codec(chosen.get("acodec")) or "opus",
            container=chosen.get("ext", "webm"),
            bitrate=int(chosen.get("abr", 0)) * 1000,
            approx_duration_ms=int((info.get("duration") or 0) * 1000),
            content_length=chosen.get("filesize"),
        )
