from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ManifestRequest(BaseModel):
    videoIds: list[str] = Field(..., min_length=1, max_length=50)
    codec: Literal["any", "aac", "opus"] = "aac"
    quality: Literal["high", "medium", "low"] = "high"


class ManifestItem(BaseModel):
    videoId: str
    url: str
    expiresAt: datetime
    codec: str
    container: str
    bitrate: int
    contentLength: int | None = None
    artworkUrl: str | None = None


class ManifestError(BaseModel):
    videoId: str
    error: str


class ManifestResponse(BaseModel):
    items: list[ManifestItem]
    errors: list[ManifestError]
