from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class StreamResponse(BaseModel):
    videoId: str
    url: str
    expiresAt: datetime
    codec: str
    container: str
    bitrate: int
    approxDurationMs: int
    contentLength: int | None = None
