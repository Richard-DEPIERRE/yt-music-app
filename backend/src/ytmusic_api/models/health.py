from datetime import datetime
from typing import Literal

from pydantic import BaseModel

OverallStatus = Literal["ok", "degraded"]
AuthStatusLabel = Literal["ok", "expired", "unknown"]


class HealthResponse(BaseModel):
    status: OverallStatus
    auth_status: AuthStatusLabel
    last_ok_at: datetime | None = None
    pot_provider_ok: bool | None = None
    version: str
